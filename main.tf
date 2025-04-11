# --------------------------------------------------------------------
# Data Sources - Fetch AWS-specific dynamic values
# --------------------------------------------------------------------

# Get an authentication token for the EKS cluster (used by Kubernetes provider)
data "aws_eks_cluster_auth" "this" {
  name = local.name
}

# Get available availability zones in the region
data "aws_availability_zones" "available" {}

# Get AWS account ID
data "aws_caller_identity" "current" {}

# Get the current AWS partition
data "aws_partition" "current" {}

# Get ECR public authorization token using a different provider config (e.g., us-east-1)
data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

# --------------------------------------------------------------------
# Local Values - Reusable constants and computed values
# --------------------------------------------------------------------

locals {
  name   = var.name
  region = var.region

  cluster_version = var.eks_cluster_version
  aerospike_namespace = "aerospike"

  # Use the first 2 available AZs for subnet distribution
  vpc_cidr = var.vpc_cidr
  azs      = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/awslabs/data-on-eks"
  }
}

# --------------------------------------------------------------------
# EKS Cluster Setup
# --------------------------------------------------------------------

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.28.0"

  cluster_name    = local.name
  cluster_version = local.cluster_version

  # WARNING: Don't use public endpoint in production unless absolutely necessary
  cluster_endpoint_public_access = var.enable_public_endpoint

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  authentication_mode                      = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions = true

  # Additional security group rules for node-to-node communication and general egress
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  # Attach IAM policy for SSM so we can SSH/debug EC2 nodes (optional)
  eks_managed_node_group_defaults = {
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
  }

  # Node group configuration
  eks_managed_node_groups = {
    core_node_group = {
      name = "core-node-group"

      min_size     = var.min_size
      max_size     = var.max_size
      desired_size = var.desired_size

      instance_types = var.instance_types
      ami_type       = "BOTTLEROCKET_ARM_64"

      ebs_optimized = true

      # Root volume configuration
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = var.ebs_volume_size
            volume_type = var.ebs_volume_type
          }
        }
      }

      labels = {
        WorkerType    = "ON_DEMAND"
        NodeGroupType = "core"
      }

      tags = {
        Name = "core-node-grp"
      }
    }
  }

  # Merge user-defined tags with tags required by Karpenter
  tags = merge(local.tags, {
    "karpenter.sh/discovery" = local.name
  })
}

# --------------------------------------------------------------------
# EKS AWS Auth ConfigMap (IAM Role to Kubernetes Group Mapping)
# --------------------------------------------------------------------

module "aws-auth" {
  source  = "terraform-aws-modules/eks/aws//modules/aws-auth"
  version = "20.17.2"

  manage_aws_auth_configmap = true

  # Map the Karpenter node IAM role into system:node group
  aws_auth_roles = [
    {
      rolearn  = module.eks_blueprints_addons.karpenter.node_iam_role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups = [
        "system:bootstrappers",
        "system:nodes",
      ]
    }
  ]
}