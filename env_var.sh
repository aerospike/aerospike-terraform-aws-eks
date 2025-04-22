#!/bin/bash
set -euo pipefail

# --------------------------------------
# Check if all the required env vars are set
# --------------------------------------
check_required_env_vars() {
    REQUIRED_ENV_VARS=(
    "AWS_DEFAULT_REGION"
    "TF_VAR_aerospike_admin_password"
    "TF_VAR_aerospike_secret_files_path"
    )

    echo "Checking required environment variables..."
    for var in "${REQUIRED_ENV_VARS[@]}"; do
    echo "  - $var"
    done

    for var in "${REQUIRED_ENV_VARS[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        echo "Error: Environment variable '$var' is not set or is empty."
        echo "Error: All required environment variables should be set."
        exit 1
    fi
    done

    echo "All required environment variables are set."
}