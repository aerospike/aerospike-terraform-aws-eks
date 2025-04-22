#!/bin/bash
set -euo pipefail

# Ensure script runs from project root (adjust if needed)
cd "$(dirname "$0")"

# Import common helpers
source "env_var.sh"

# Verify if all the required environment variables are set
check_required_env_vars

# Assign AWS region after prompting
region="${AWS_DEFAULT_REGION}"
echo "AWS_DEFAULT_REGION set to: $region"

# List of Terraform modules to apply in sequence
targets=(
  "module.eks_blueprints_addons"
  "module.ebs_csi_driver_irsa"
  "module.eks"
  "module.vpc"
)

echo "Destroying aerospike resources..."
aerospike_targets=(
  "helm_release.aerospike_cluster"
  "helm_release.aerospike_operator"
)

# Destroy modules in sequence
for target in "${aerospike_targets[@]}"
do
  echo "Destroying module $target..."
  destroy_output=$(terraform destroy -target="$target" -var="region=$region" -auto-approve 2>&1 | tee /dev/tty)
  if [[ ${PIPESTATUS[0]} -eq 0 && $destroy_output == *"Destroy complete"* ]]; then
    echo "SUCCESS: Terraform destroy of $target completed successfully"
  else
    echo "FAILED: Terraform destroy of $target failed"
    exit 1
  fi
done

# Delete Karpenter resources
kubectl delete --all nodeclaim
kubectl delete --all nodepool
kubectl delete --all ec2nodeclass

# Destroy modules in sequence
for target in "${targets[@]}"
do
  echo "Destroying module $target..."
  destroy_output=$(terraform destroy -target="$target" -var="region=$region" -auto-approve 2>&1 | tee /dev/tty)
  if [[ ${PIPESTATUS[0]} -eq 0 && $destroy_output == *"Destroy complete"* ]]; then
    echo "SUCCESS: Terraform destroy of $target completed successfully"
  else
    echo "FAILED: Terraform destroy of $target failed"
    exit 1
  fi
done

## Final destroy to catch any remaining resources
echo "Destroying remaining resources..."
destroy_output=$(terraform destroy -var="region=$region" -auto-approve 2>&1 | tee /dev/tty)
if [[ ${PIPESTATUS[0]} -eq 0 && $destroy_output == *"Destroy complete"* ]]; then
  echo "SUCCESS: Terraform destroy of all modules completed successfully"
else
  echo "FAILED: Terraform destroy of all modules failed"
  exit 1
fi
