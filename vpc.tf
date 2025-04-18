# WARNING: This VPC includes internet and NAT gateways, which are ideal for sandbox/test environments.
# For production use, consider a fully private architecture, and consult your cloud security team.

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.12.1"

  name = local.name
  cidr = local.vpc_cidr

  azs = local.azs

  # Dynamically generate private subnets using subnetting logic
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  
  # Public subnets use different offset to avoid overlap (k + 10)
  public_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 10)]

  # Enable NAT gateway (1 per region, not per AZ) to allow private subnet internet access
  enable_nat_gateway = true
  single_nat_gateway = true

  # Tag public subnets to be discovered as ELB-compatible by Kubernetes
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  # Tag private subnets for internal ELBs and Karpenter node discovery
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "karpenter.sh/discovery"          = local.name
  }

  tags = local.tags
}