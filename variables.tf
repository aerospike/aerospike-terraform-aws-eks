# --------------------------
# AWS VARIABLES
# --------------------------

variable "region" {
  description = "AWS region to deploy the infrastructure."
  type        = string
  default     = "us-west-2"
}

variable "availability_zones" {
  description = "Optional list of AZs to use for subnets, node groups, and Aerospike rack config. If not set, 2 random AZs will be picked."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.availability_zones) == 0 || length(var.availability_zones) >= 2
    error_message = "If availability_zones is provided, it must contain at least 2 entries."
  }
}

# --------------------------
# EKS VARIABLES
# --------------------------

variable "name" {
  description = "Name of the VPC and EKS cluster."
  type        = string
  default     = "aerospike-on-eks"
}

variable "eks_cluster_version" {
  description = "Version of the EKS cluster to deploy."
  type        = string
  default     = "1.31"
}

variable "enable_public_endpoint" {
  description = "Enable public endpoint access for the EKS API server. WARNING: Not recommended for production environments."
  type        = bool
  default     = true
}

# --------------------------
# VPC VARIABLES
# --------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.1.0.0/16"
}

# -----------------------------------------------------------------------------------
# CORE NODE GROUP VARIABLES (used for system/setup pods like Karpenter, CoreDNS, etc.)
# NOTE: These nodes are NOT used for Aerospike or AKO pods — those are handled by Karpenter
# -----------------------------------------------------------------------------------

variable "instance_types" {
  description = "List of instance types for the EKS core node group."
  type        = list(string)
  default     = ["m8g.xlarge", "m7g.xlarge", "c8g.xlarge", "c7g.xlarge"]
}

variable "desired_size" {
  description = "Desired number of nodes in the core node group."
  type        = number
  default     = 3
}

variable "ebs_volume_size" {
  description = "Root EBS volume size (in GiB) for each node in the core node group."
  type        = number
  default     = 1000
}

# --------------------------
# ADDONS VARIABLES
# --------------------------

variable "karpenter_version" {
  description = "Version of the Karpenter add-on."
  type        = string
  default     = "1.1.0"
}

# --------------------------
# AEROSPIKE VARIABLES
# --------------------------

variable "aerospike_operator_version" {
  description = "Version of the Aerospike Kubernetes Operator to deploy."
  type        = string
  default     = "4.0.0"
}

variable "aerospike_admin_password" {
  description = "Password for Aerospike admin user"
  type        = string
  sensitive   = true
}

variable "aerospike_secret_files_path" {
  description = "Path to the directory containing Aerospike secret files like feature.conf and TLS certs"
  type        = string
}