variable "region" {
  description = "Region"
  type        = string
  default     = "us-west-2"
}

variable "name" {
  description = "Name of the VPC and EKS Cluster"
  type        = string
  default     = "aerospike-on-eks"
}

variable "eks_cluster_version" {
  description = "EKS Cluster version"
  type        = string
  default     = "1.30"
}

variable "aerospike_operator_version" {
  description = "Aerospike Kubernetes Operator version"
  type        = string
  default     = "3.3.1"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.1.0.0/16"
}