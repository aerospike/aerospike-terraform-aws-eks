
# --------------------------
# AWS VARIABLES
# --------------------------

variable "region" {
  description = "Region"
  type        = string
  default     = "us-west-2"
}

# --------------------------
# EKS VARIABLES
# --------------------------

variable "name" {
  description = "Name of the VPC and EKS Cluster"
  type        = string
  default     = "aerospike-on-eks"
}

variable "eks_cluster_version" {
  description = "EKS Cluster version"
  type        = string
  default     = "1.31"
}

# WARNING: Don't use public endpoint in production unless absolutely necessary
variable "enable_public_endpoint" {
  description = "Enable public endpoint for EKS cluster"
  type        = bool
  default     = false
}

# --------------------------
# VPC VARIABLES
# --------------------------

variable "vpc_cidr" {
  description = "Vpc cidr"
  type        = string
  default     = "10.1.0.0/16"
}

variable "az_count" {
  description = "Number of Azs for deploying nodes"
  type        = number
  default     = 2
}

# WARNING: This VPC includes internet and NAT gateways, which are ideal for sandbox/test environments.
# For production use, consider a fully private architecture, and consult your cloud security team.
variable "enable_nat_gateway" {
  description = "Whether to enable NAT gateway"
  type        = bool
  default     = false
}

# --------------------------
# NODE POOL VARIABLES
# --------------------------

# Allowed instance categories "c", "m", "r", "i"
variable "instance_types" {
  description = "Instance types for EKS nodes"
  type        = list(string)
  default     = ["m8g.xlarge", "m7g.xlarge", "c8g.xlarge", "c7g.xlarge"]
}

variable "min_size" {
  description = "Node group min size"
  type        = number
  default     = 3
}

variable "max_size" {
  description = "Node group max size"
  type        = number
  default     = 9
}

variable "desired_size" {
  description = "Node group desired size"
  type        = number
  default     = 3
}

variable "ebs_volume_type" {
  description = "Root Volume type"
  type        = string
  default     = "gp3"
}

variable "ebs_volume_size" {
  description = "Root volume size"
  type        = number
  default     = 1000
}

# --------------------------
# ADDONS VARIABLES
# --------------------------
variable "karpenter_version" {
  description = "Karpenter version"
  type        = string
  default     = "1.1.0"
}

# --------------------------
# AEROSPIKE VARIABLES
# --------------------------

variable "aerospike_operator_version" {
  description = "Aerospike Kubernetes Operator version"
  type        = string
  default     = "4.0.0"
}

variable "aerospike_admin_password" {
  description = "password for aerospike admin user"
  type        = string
  sensitive   = true
}

variable "aerospike_secret_files_path" {
  description = "path of the directory containing aerospike secret files like feature.conf and tls certs"
  type        = string
}
