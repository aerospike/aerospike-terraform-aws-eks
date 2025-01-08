#---------------------------------------------------------------
# Aerospike Kubernetes Operator
#---------------------------------------------------------------

locals {
  aerospike_operator_helm_config = {
    values = [templatefile("${path.module}/helm-values/aerospike-operator-values.yaml", {
      node_group_type = "apps"
    })]
  }
}

resource "helm_release" "aerospike_operator" {
  name                       = try(local.aerospike_operator_helm_config["name"], "aerospike-kubernetes-operator")
  repository                 = try(local.aerospike_operator_helm_config["repository"], "https://aerospike.github.io/aerospike-kubernetes-operator")
  chart                      = try(local.aerospike_operator_helm_config["chart"], "aerospike-kubernetes-operator")
  version                    = try(local.aerospike_operator_helm_config["version"], var.aerospike_operator_version)
  timeout                    = try(local.aerospike_operator_helm_config["timeout"], 300)
  values                     = try(local.aerospike_operator_helm_config["values"], null)
  create_namespace           = try(local.aerospike_operator_helm_config["create_namespace"], true)
  namespace                  = try(local.aerospike_operator_helm_config["namespace"], "aerospike-operator")
  lint                       = try(local.aerospike_operator_helm_config["lint"], false)
  description                = try(local.aerospike_operator_helm_config["description"], "")
  repository_key_file        = try(local.aerospike_operator_helm_config["repository_key_file"], "")
  repository_cert_file       = try(local.aerospike_operator_helm_config["repository_cert_file"], "")
  repository_username        = try(local.aerospike_operator_helm_config["repository_username"], "")
  repository_password        = try(local.aerospike_operator_helm_config["repository_password"], "")
  verify                     = try(local.aerospike_operator_helm_config["verify"], false)
  keyring                    = try(local.aerospike_operator_helm_config["keyring"], "")
  disable_webhooks           = try(local.aerospike_operator_helm_config["disable_webhooks"], false)
  reuse_values               = try(local.aerospike_operator_helm_config["reuse_values"], false)
  reset_values               = try(local.aerospike_operator_helm_config["reset_values"], false)
  force_update               = try(local.aerospike_operator_helm_config["force_update"], false)
  recreate_pods              = try(local.aerospike_operator_helm_config["recreate_pods"], false)
  cleanup_on_fail            = try(local.aerospike_operator_helm_config["cleanup_on_fail"], false)
  max_history                = try(local.aerospike_operator_helm_config["max_history"], 0)
  atomic                     = try(local.aerospike_operator_helm_config["atomic"], false)
  skip_crds                  = try(local.aerospike_operator_helm_config["skip_crds"], false)
  render_subchart_notes      = try(local.aerospike_operator_helm_config["render_subchart_notes"], true)
  disable_openapi_validation = try(local.aerospike_operator_helm_config["disable_openapi_validation"], false)
  wait                       = try(local.aerospike_operator_helm_config["wait"], true)
  wait_for_jobs              = try(local.aerospike_operator_helm_config["wait_for_jobs"], false)
  dependency_update          = try(local.aerospike_operator_helm_config["dependency_update"], false)
  replace                    = try(local.aerospike_operator_helm_config["replace"], false)

  postrender {
    binary_path = try(local.aerospike_operator_helm_config["postrender"], "")
  }

  dynamic "set" {
    iterator = each_item
    for_each = try(local.aerospike_operator_helm_config["set"], [])

    content {
      name  = each_item.value.name
      value = each_item.value.value
      type  = try(each_item.value.type, null)
    }
  }

  dynamic "set_sensitive" {
    iterator = each_item
    for_each = try(local.aerospike_operator_helm_config["set_sensitive"], [])

    content {
      name  = each_item.value.name
      value = each_item.value.value
      type  = try(each_item.value.type, null)
    }
  }
}

#---------------------------------------------------------------
# Install Aerospike cluster
#---------------------------------------------------------------

locals {
  aerospike_cluster_helm_config = {
    values = [templatefile("${path.module}/examples/aerospike-cluster-values.yaml", {
      node_group_type = "aerospike"
    })]
  }
}

resource "kubernetes_namespace" "aerospike" {
  metadata {
    name = local.aerospike_namespace
  }

  depends_on = [module.eks.cluster_name]
}

resource "kubernetes_secret" "auth_secret" {
  metadata {
    name      = "auth-secret"
    namespace = local.aerospike_namespace
  }

  data = {
    password = "admin123"
  }

  type = "Opaque"

  depends_on = [helm_release.aerospike_operator]
}

resource "helm_release" "aerospike_cluster" {
  name                       = try(local.aerospike_cluster_helm_config["name"], "aerospike-cluster")
  repository                 = try(local.aerospike_cluster_helm_config["repository"], "https://aerospike.github.io/aerospike-kubernetes-operator")
  chart                      = try(local.aerospike_cluster_helm_config["chart"], "aerospike-cluster")
  version                    = try(local.aerospike_cluster_helm_config["version"], var.aerospike_operator_version)
  timeout                    = try(local.aerospike_cluster_helm_config["timeout"], 300)
  values                     = try(local.aerospike_cluster_helm_config["values"], null)
  create_namespace           = try(local.aerospike_cluster_helm_config["create_namespace"], false)
  namespace                  = try(local.aerospike_cluster_helm_config["namespace"], local.aerospike_namespace)
  lint                       = try(local.aerospike_cluster_helm_config["lint"], false)
  description                = try(local.aerospike_cluster_helm_config["description"], "")
  repository_key_file        = try(local.aerospike_cluster_helm_config["repository_key_file"], "")
  repository_cert_file       = try(local.aerospike_cluster_helm_config["repository_cert_file"], "")
  repository_username        = try(local.aerospike_cluster_helm_config["repository_username"], "")
  repository_password        = try(local.aerospike_cluster_helm_config["repository_password"], "")
  verify                     = try(local.aerospike_cluster_helm_config["verify"], false)
  keyring                    = try(local.aerospike_cluster_helm_config["keyring"], "")
  disable_webhooks           = try(local.aerospike_cluster_helm_config["disable_webhooks"], false)
  reuse_values               = try(local.aerospike_cluster_helm_config["reuse_values"], false)
  reset_values               = try(local.aerospike_cluster_helm_config["reset_values"], false)
  force_update               = try(local.aerospike_cluster_helm_config["force_update"], false)
  recreate_pods              = try(local.aerospike_cluster_helm_config["recreate_pods"], false)
  cleanup_on_fail            = try(local.aerospike_cluster_helm_config["cleanup_on_fail"], false)
  max_history                = try(local.aerospike_cluster_helm_config["max_history"], 0)
  atomic                     = try(local.aerospike_cluster_helm_config["atomic"], false)
  skip_crds                  = try(local.aerospike_cluster_helm_config["skip_crds"], false)
  render_subchart_notes      = try(local.aerospike_cluster_helm_config["render_subchart_notes"], true)
  disable_openapi_validation = try(local.aerospike_cluster_helm_config["disable_openapi_validation"], false)
  wait                       = try(local.aerospike_cluster_helm_config["wait"], true)
  wait_for_jobs              = try(local.aerospike_cluster_helm_config["wait_for_jobs"], false)
  dependency_update          = try(local.aerospike_cluster_helm_config["dependency_update"], false)
  replace                    = try(local.aerospike_cluster_helm_config["replace"], false)

  postrender {
    binary_path = try(local.aerospike_cluster_helm_config["postrender"], "")
  }

  dynamic "set" {
    iterator = each_item
    for_each = try(local.aerospike_cluster_helm_config["set"], [])

    content {
      name  = each_item.value.name
      value = each_item.value.value
      type  = try(each_item.value.type, null)
    }
  }

  dynamic "set_sensitive" {
    iterator = each_item
    for_each = try(local.aerospike_cluster_helm_config["set_sensitive"], [])

    content {
      name  = each_item.value.name
      value = each_item.value.value
      type  = try(each_item.value.type, null)
    }
  }

  depends_on = [
    kubernetes_secret.auth_secret
  ]
}

# Create the ServiceAccount
resource "kubernetes_service_account" "aerospike_operator_controller_manager" {
  metadata {
    name      = "aerospike-operator-controller-manager"
    namespace = local.aerospike_namespace
  }
}

# Create the RoleBinding
resource "kubernetes_role_binding" "aerospike_cluster" {
  metadata {
    name      = "aerospike-cluster"
    namespace = local.aerospike_namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "aerospike-cluster"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.aerospike_operator_controller_manager.metadata[0].name
    namespace = local.aerospike_namespace
  }
}

# Create the ClusterRoleBinding
resource "kubernetes_cluster_role_binding" "aerospike_cluster" {
  metadata {
    name = "aerospike-cluster"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "aerospike-cluster"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.aerospike_operator_controller_manager.metadata[0].name
    namespace = local.aerospike_namespace
  }
}
