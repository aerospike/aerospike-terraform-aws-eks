# Aerospike on EKS using Terraform

Aerospike is a high-performance, scalable, real-time NoSQL database designed for ultra-low latency and petabyte-scale workloads. It’s ideal for use cases that demand fast data processing and real-time decision-making.

This repository provides a Terraform-based blueprint for deploying Aerospike Database Enterprise Edition on Amazon Elastic Kubernetes Service (EKS). It follows the conventions of the Data on EKS (DoEKS) project, combining Kubernetes orchestration with Terraform’s infrastructure-as-code approach for scalable, cloud-native deployments.

The blueprint includes configuration for Aerospike clustering, storage optimization, networking, and security—enabling a production-ready deployment on AWS in under 30 minutes.

# Prerequisites

Ensure the following tools are installed locally:

* [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
* [kubectl](https://kubernetes.io/docs/tasks/tools/)
* [terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)

# Deployment Steps
This blueprint is designed to deploy **Aerospike Database Enterprise Edition**. To proceed, make sure you have a valid [`features.conf`](https://aerospike.com/docs/server/operations/configure/feature-key) file, which is required to validate your Aerospike license.

## Prepare Secrets and Admin Credentials
Put your features.conf file and any additional cert files into a single directory (e.g., ~/aerospike-secrets/).

Then, set the following environment variables in your terminal:

```
export TF_VAR_aerospike_admin_password=<password-for-admin-user>
export TF_VAR_aerospike_secret_files_path=<absolute-path-to-directory-containing-features.conf-and-certs>
```
These environment variables are used by the blueprint to create two Kubernetes secrets:
- **auth-secret**: Stores the password for the Aerospike `admin` user. This password is set in the Aerospike cluster and must be used by Aerospike clients to authenticate.
- **aerospike-secret**: Stores the `features.conf and any other cert files` you’ve provided. These files are mounted into the Aerospike pods and used for license validation and secure configuration.

## Clone the Blueprint Repository
To deploy this blueprint into an AWS EKS cluster, you first need to clone the repository. To do so, run these commands:

```
git clone https://github.com/aerospike/aerospike-terraform-aws-eks.git
cd aerospike-terraform-aws-eks
```

## Customizing the Blueprint Configuration (Optional)
You can customize this blueprint by providing your own values in a `terraform.tfvars` file placed in the root of the repository.

Terraform will automatically pick up this file when you run the `install.sh` script, no extra configuration is needed.

Here’s a [sample terraform.tfvars](terraform.tfvars.example) you can use as a starting point. Rename this file to `terraform.tfvars` and update values before running the install script.

## Run the Installation Script
Make the install script executable and run it. Enter the region name when prompted (i.e. `eu-west-1`):

```
chmod +x install.sh
./install.sh
```

The script will deploy all the resources using Terraform. The Terraform template creates an EKS cluster with the AKO controller, along with an Aerospike cluster. This will take around 20 to 25 minutes.

## Connecting to the EKS cluster
To connect to your Aerospike EKS cluster using kubectl, run the following command:

```
aws eks --region <your-region> update-kubeconfig --name <your-cluster-name>
```
- Replace `<your-region>` with the region you deployed the cluster to (e.g., us-west-2).
- Replace `<your-cluster-name>` with the value of the `name` variable defined in your variables.tf or *.auto.tfvars file.

## Verify Aerospike Cluster Deployment

To confirm that the Aerospike cluster has been created, check the status of the pods running this command:

```
kubectl get pods -n aerospike
```

You should see an output like this:

```
NAME                   READY   STATUS    RESTARTS   AGE
aerospikecluster-0-0   1/1     Running   0          20m
aerospikecluster-0-1   1/1     Running   0          20m
aerospikecluster-0-2   1/1     Running   0          20m
```

If the pods are crashing, check the logs of one of the pods by running this command:

```
kubectl logs aerospikecluster-0-0 -c aerospike-server -n aerospike
```

# Testing the Deployment

Once the Aerospike cluster is running, let's make sure it's working. To do so, let's create some environment variables to get one of the Aerospike host IPs, the user, and the password to connect to the server. Run these commands:

```
export HOST=$(kubectl get aerospikecluster aerospikecluster -n aerospike -o jsonpath='{.status.pods.aerospikecluster-0-0.aerospike.accessEndpoints[0]}')
export USER=$(kubectl get aerospikecluster aerospikecluster -n aerospike -o jsonpath='{.status.aerospikeAccessControl.users[0].name}')
export PASSWORD=$(kubectl get secret auth-secret -n aerospike -o jsonpath='{.data.password}' | base64 --decode)
```

Next, let's create a temporary pod that uses the Aerospike tools container, and connect to the cluster by running this command:

```
kubectl run -it --rm --restart=Never aerospike-tool -n aerospike --image=aerospike/aerospike-tools:latest -- asadm -h $HOST -U $USER -P $PASSWORD
```

You should see a prompt like the following, meaning that the Aerospike cluster is working correctly:

```
If you don't see a command prompt, try pressing enter.
Seed:        [('10.1.2.213', 3000, None)]
Config_file: /root/.aerospike/astools.conf, /etc/aerospike/astools.conf
Aerospike Interactive Shell, version 3.1.1

Found 3 nodes
Online:  10.1.2.213:3000, 10.1.1.210:3000, 10.1.0.112:3000

Admin>
```

# Key Cluster Configuration Details

This blueprint uses Karpenter for dynamic provisioning of EKS compute nodes. Karpenter launches right-sized EC2 instances based on pod requirements and scheduling constraints.

When the Aerospike cluster is created, there are unscheduled pods as none of the existing nodes have a label `NodeGroupType: aerospike`. Therefore, Karpenter will launch the node(s) needed based on the pod's constraints. In this case, if you look at the `examples/aerospike-cluster-values.yaml` file, the Aerospike pods have the following constraints:

```
podSpec:
  multiPodPerHost: false
  nodeSelector:
    NodeGroupType: ${node_group_type}
```

We’ve set `multiPodPerHost: false` to ensure that Aerospike cluster pods are spread across separate nodes. This may result in some pods initially remaining unscheduled, which Karpenter will detect and respond to by provisioning one node per pod. This configuration is recommended to minimize the blast radius during maintenance operations in a live environment.

Notice that the pods are requesting a node with the `NodeGroupType` selector, which will match the Aerospike NodePool in Karpenter. Karpenter NodePools define how Karpenter manages unschedulable pods and configures nodes. Although most use cases are addressed with a single NodePool for multiple workloads/teams, multiple NodePools are useful to isolate nodes for billing, use different node constraints (such as no GPUs for a team), or use different disruption settings.

In this case, the NodePools the blueprint is creating have the constraint to only use Graviton instances as they've been proven to provide a better performance to run Aerospike clusters. You don't need to build a different Aerospike container image for this as we already have support for arm-based container images. Here's a portion of the NodePool constraints that launch only Graviton instances for certain families:

```
      requirements:
        - key: "kubernetes.io/arch"
          operator: In
          values: ["arm64"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        - key: "karpenter.k8s.aws/instance-category"
          operator: In
          values: ["c", "m", "r", "i"]
```

# Cleanup

To cleanup the environment, simply run the following commands, this script uses Terraform with the `-target` option to ensure all the resources are deleted in correct order:

```
chmod +x cleanup.sh
./cleanup.sh
```
