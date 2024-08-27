# Aerospike on EKS using Terraform

Aerospike is a high-performance, scalable, real-time NoSQL database that delivers sub-millisecond latency at petabyte scale. It is designed to handle massive amounts of data with extreme efficiency, making it ideal for use cases that require rapid data processing and real-time decision making. This repository provides a blueprint to deploy Aerospike to an Amazon Elastic Kubernetes Service (EKS) cluster using Terraform, following the pattern established by the Data on EKS (DoEKS) project. By leveraging the power of Kubernetes and the flexibility of Terraform, this deployment method allows for efficient management and scaling of Aerospike instances in a cloud-native environment. The blueprint covers aspects such as cluster configuration, storage optimization, networking, and security, enabling you to quickly set up a production-ready Aerospike environment on EKS.

# Deploy

Clone the repository.

```
git clone https://github.com/aerospike/aerospike-terraform-aws-eks.git
cd aerospike-terraform-aws-eks
```

Run the `install.sh` script, and enter the region name (i.e. `eu-west-1`).

```
chmod +x install.sh
./install.sh
```

# Cleanup

This script will cleanup the environment using -target option to ensure all the resources are deleted in correct order.

```
chmod +x cleanup.sh
./cleanup.sh
```
