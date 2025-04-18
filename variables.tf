
# --------------------------
# AWS VARIABLES
# --------------------------

variable "region" {
  description = "Region"
  type        = string
  default     = "us-west-2"
}

# Optional variable: User-defined list of AZs
variable "availability_zones" {
  description = "Optional list of AZs to use for subnets, node groups, and aerospike rack config. If not set, 2 random AZs will be picked."
  type        = list(string)
  default     = []
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
  description = "Enable public endpoint for EKS cluster API server"
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

# -----------------------------------------------------------------------------------
# CORE NODE GROUP VARIABLES (used for system/setup pods like Karpenter, CoreDNS, etc.)
# NOTE: These nodes are NOT used for Aerospike or AKO pods — those are handled by Karpenter
# -----------------------------------------------------------------------------------
variable "instance_types" {
  description = "Instance types for EKS nodes"
  type        = list(string)
  default     = ["m8g.xlarge", "m7g.xlarge", "c8g.xlarge", "c7g.xlarge"]
}

variable "desired_size" {
  description = "Node group desired size"
  type        = number
  default     = 3
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
