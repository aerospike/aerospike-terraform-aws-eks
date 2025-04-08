# Aerospike on EKS using Terraform

Aerospike is a high-performance, scalable, real-time NoSQL database that delivers sub-millisecond latency at petabyte scale. It is designed to handle massive amounts of data with extreme efficiency, making it ideal for use cases that require rapid data processing and real-time decision making. This repository provides a blueprint to deploy `Aerospike Database Enterprise Edition` to an Amazon Elastic Kubernetes Service (EKS) cluster using Terraform, following the pattern established by the Data on EKS (DoEKS) project. By leveraging the power of Kubernetes and the flexibility of Terraform, this deployment method allows for efficient management and scaling of Aerospike instances in a cloud-native environment. The blueprint covers aspects such as aerospike cluster configuration, storage optimization, networking, and security, enabling you to quickly set up a production-ready Aerospike environment on EKS.

# Pre-Requisites

Ensure that you have installed the following tools on your machine.

* [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
* [kubectl](https://kubernetes.io/docs/tasks/tools/)
* [terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)

# Deploy

To deploy this blueprint into an AWS EKS cluster, you first need to clone the repository. To do so, run these commands:

```
git clone https://github.com/aerospike/aerospike-terraform-aws-eks.git
cd aerospike-terraform-aws-eks
```

Then, run the `install.sh` script, and enter the region name when prompted (i.e. `eu-west-1`):

```
chmod +x install.sh
./install.sh
```

The script will deploy all the resources using Terraform. The Terraform template creates an EKS cluster with the AKO controller, along with an Aerospike cluster.

This will take around 20 to 25 minutes. When it's done, you need to create the `aerospike-secret` that the blueprint is using to access the [`features.conf`](https://aerospike.com/docs/server/operations/configure/feature-key) file to validate your Aerospike license. So, make sure you have a valid `features.conf` file, then run the following command:

```
kubectl create secret generic aerospike-secret --from-file=<path to features.conf> -n aerospike
```

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

If the pods are crashing, give it around five minutes for them to use the missing secret you created before. However, if for some reason they keep failing, check the logs of one of the pods by running this command:

```
kubectl logs aerospikecluster-0-0 -c aerospike-server -n aerospike
```

# Test

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

# Key Cluster Configurations

First of all, the blueprint is using Karpenter to provision the compute nodes for the EKS cluster. Karpenter is a node lifecycle management solution used to scale your Kubernetes cluster. Karpenter observes incoming pods and launches the right-sized Amazon EC2 instances based on your workloads' requirements. Instance selection decisions are intent-based and driven by the specification of incoming pods, including resource requests and Kubernetes scheduling constraints.

When the Aerospike cluster is created, there are unscheduled pods as none of the existing nodes have a label `NodeGroupType: aerospike`. Therefore, Karpenter will launch the node(s) needed based on the pod's constraints. In this case, if you look at the `examples/aerospike-cluster-values.yaml` file, the Aerospike pods have the following constraints:

```
podSpec:
  multiPodPerHost: false
  nodeSelector:
    NodeGroupType: ${node_group_type}
```

We're using the `multiPodPerHost: false` configuration to say that we want Aerospike cluster pods to be spread within nodes. This will cause to have unscheduled pods, and Karpenter will pick them up and will create a node per pod. This is recommended to reduce the blast radius of doing maintenance operations in a live environment.

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