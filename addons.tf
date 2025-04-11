#---------------------------------------------------------------
# GP3 Encrypted Storage Class
#---------------------------------------------------------------

# This disables the default setting on the "gp2" StorageClass,
# so that it won't be automatically used for PVCs without an explicit class.
resource "kubernetes_annotations" "gp2_default" {
  annotations = {
    "storageclass.kubernetes.io/is-default-class" : "false"
  }
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  metadata {
    name = "gp2"
  }
  force = true

  depends_on = [module.eks]
}

# This creates a new "gp3" StorageClass.
# It is also marked as the default StorageClass in the cluster.
resource "kubernetes_storage_class" "ebs_csi_encrypted_gp3_storage_class" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" : "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"
  parameters = {
    fsType    = "xfs"
    encrypted = true
    type      = "gp3"
  }

  depends_on = [kubernetes_annotations.gp2_default]
}

#---------------------------------------------------------------
# IRSA for EBS CSI Driver
#---------------------------------------------------------------

# This module creates an IAM Role for Service Accounts (IRSA)
# to allow the EBS CSI driver to interact with AWS EBS volumes securely.
module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.44.0"

  role_name_prefix        = "${module.eks.cluster_name}-ebs-csi-driver-"
  attach_ebs_csi_policy   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = local.tags
}

#---------------------------------------------------------------
# EKS Blueprints Add-ons (EBS CSI Driver, CoreDNS, etc.)
#---------------------------------------------------------------

# This module deploys managed EKS add-ons and optional community addons like Karpenter.
module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.16.3"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # Install EKS-managed add-ons with optional custom settings
  eks_addons = {
    aws-ebs-csi-driver = {
      service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
    }
    coredns = {
      preserve = true
    }
    vpc-cni = {
      preserve = true
    }
    kube-proxy = {
      preserve = true
    }
  }

  # Enable cert-manager
  enable_cert_manager = true

  # Enable Karpenter (node provisioning engine)
  enable_karpenter = true
  karpenter = {
    chart_version       = var.karpenter_version
    repository_username = data.aws_ecrpublic_authorization_token.token.user_name
    repository_password = data.aws_ecrpublic_authorization_token.token.password
    values = [
      # Optional: additional Helm values can be injected here
    ]
  }
  karpenter_enable_spot_termination          = true
  karpenter_enable_instance_profile_creation = true
  karpenter_node = {
    iam_role_use_name_prefix = false
  }
}

#---------------------------------------------------------------
# Karpenter Manifests via kubectl (e.g., EC2NodeClass, NodePool)
#---------------------------------------------------------------

# Loads Karpenter manifest YAML files from the karpenter-manifests/ folder.
data "kubectl_path_documents" "karpenter" {
  pattern = "${path.module}/karpenter-manifests/*.yaml"
}

# Applies the Karpenter manifests to the cluster after substituting cluster name
resource "kubectl_manifest" "karpenter" {
  for_each  = toset(data.kubectl_path_documents.karpenter.documents)
  yaml_body = replace(each.value, "--CLUSTER_NAME--", local.name)
}