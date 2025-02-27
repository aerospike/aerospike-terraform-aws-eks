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
  default     = "1.31"
}

variable "karpenter_version" {
  description = "Karpenter version"
  type        = string
  default     = "1.1.0"
}

variable "aerospike_operator_version" {
  description = "Aerospike Kubernetes Operator version"
  type        = string
  default     = "3.4.0"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.1.0.0/16"
}