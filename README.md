# Terraform VPC + EKS Module

This Terraform configuration creates a complete AWS infrastructure with a VPC and an EKS (Elastic Kubernetes Service) cluster, including all necessary networking, security, IAM, and Kubernetes components.

## 📋 Table of Contents

- [Overview](#overview)
- [Infrastructure Components](#infrastructure-components)
- [Architecture Diagram](#architecture-diagram)
- [Project Structure](#project-structure)
- [How It Works](#how-it-works)
- [Prerequisites](#prerequisites)
- [Usage](#usage)
- [Configuration](#configuration)
- [Outputs](#outputs)

---

## Overview

This project creates a **production-ready EKS cluster** with proper VPC networking, security controls, IAM permissions, and Kubernetes addons. The infrastructure is organized into two reusable modules:

1. **VPC Module** (`modules/vpc/`): Creates networking infrastructure
2. **EKS Module** (`modules/eks/`): Creates Kubernetes cluster and worker nodes

---

## Infrastructure Components

### 🌐 VPC & Networking

#### VPC (Virtual Private Cloud)
- **CIDR Block**: `11.1.0.0/16` (configurable via `terraform.tfvars`)
- **DNS Support**: Enabled (allows pods to resolve hostnames)
- **DNS Hostnames**: Enabled (allows pods to have DNS names)

#### Public Subnets
- **Count**: 3 (one per availability zone)
- **CIDR Blocks**: `11.1.0.0/24`, `11.1.1.0/24`, `11.1.2.0/24`
- **Purpose**: Hosts NAT Gateway and Load Balancers
- **IP Assignment**: Auto-assigns public IPs to instances

#### Private Subnets
- **Count**: 3 (one per availability zone)
- **CIDR Blocks**: `11.1.3.0/24`, `11.1.4.0/24`, `11.1.5.0/24`
- **Purpose**: Hosts EKS worker nodes (safer, less exposed)
- **Outbound Traffic**: Routed through NAT Gateway

#### Internet Gateway (IGW)
- **Purpose**: Provides internet access to public subnets
- **Routes**: Public subnets have a route to `0.0.0.0/0` → IGW

#### NAT Gateway + Elastic IP
- **Purpose**: Allows private subnet resources to reach the internet (for image pulls, API calls)
- **Location**: Placed in public subnet
- **Elastic IP**: Static IP for NAT Gateway (required)
- **Private Route**: Private subnets route `0.0.0.0/0` → NAT Gateway

#### Route Tables
- **Public Route Table**: Routes internet traffic through IGW
- **Private Route Table**: Routes internet traffic through NAT Gateway
- **Associations**: Public/private subnets associated with their respective route tables

#### Security Groups
- **Public Security Group** (`public_sg`):
  - Allows inbound HTTP (80) and HTTPS (443) from anywhere
  - Allows all outbound traffic
  - Used for public-facing services

- **EKS Node Security Group** (`eks_node_sg`):
  - Allows node-to-node communication (TCP 0-65535)
  - Allows kubelet API access (port 10250)
  - Allows all outbound traffic
  - Used for EKS worker nodes

---

### ☸️ EKS Cluster

#### EKS Control Plane
- **Cluster Name**: `bootcampeks-cluster` (configurable)
- **Kubernetes Version**: `1.31` (configurable via `terraform.tfvars`)
- **Endpoints**:
  - Private Access: Enabled (pods can call the Kubernetes API privately)
  - Public Access: Enabled (you can manage the cluster from your machine)
- **Networking**: Placed in public subnets (accessible from internet)

#### Node Group (Worker Nodes)
- **Name**: `public-ng`
- **Instance Type**: `t3.medium` (configurable)
- **Capacity Type**: `SPOT` (cost-optimized, interruptible)
- **Desired Size**: 2 nodes
- **Min/Max Size**: 1-3 nodes (auto-scaling range)
- **Disk Size**: 20 GB
- **AMI Type**: `AL2_x86_64` (Amazon Linux 2)
- **Subnets**: Deployed in public subnets (can receive internet traffic)
- **Security Groups**: Uses `eks_node_sg`

---

### 🔐 IAM Roles & Policies

#### EKS Cluster Role
- **Name**: `bootcampeks-cluster-eks-cluster-role`
- **Trust Relationship**: Trusts `eks.amazonaws.com` service
- **Policy**: `AmazonEKSClusterPolicy` (allows EKS control plane to manage AWS resources)
- **Purpose**: Allows the EKS control plane to create/manage networking, security groups, etc.

#### EKS Node Role
- **Name**: `bootcampeks-cluster-eks-node-role`
- **Trust Relationship**: Trusts `ec2.amazonaws.com` service
- **Policies Attached**:
  - `AmazonEKSWorkerNodePolicy`: Allows nodes to join the cluster
  - `AmazonEKS_CNI_Policy`: Allows VPC CNI addon to manage ENIs
  - `AmazonEC2ContainerRegistryReadOnly`: Allows pulling container images from ECR
- **Purpose**: Allows worker nodes to communicate with control plane and AWS services

#### VPC CNI Role (IRSA - IAM Roles for Service Accounts)
- **Name**: `bootcampeks-cluster-vpc-cni-role`
- **Trust Relationship**: Trusts the EKS cluster's OIDC provider
- **Service Account**: `aws-node` in `kube-system` namespace
- **Policy**: `AmazonEKS_CNI_Policy`
- **Purpose**: Allows the VPC CNI pod to manage Elastic Network Interfaces (ENIs) for pod networking

#### EBS CSI Driver Role (IRSA)
- **Name**: `bootcampeks-cluster-ebs-csi-driver-role`
- **Trust Relationship**: Trusts the EKS cluster's OIDC provider
- **Service Account**: `ebs-csi-controller-sa` in `kube-system` namespace
- **Policy**: `AmazonEBSCSIDriverPolicy`
- **Purpose**: Allows the EBS CSI driver pod to create/delete EBS volumes for persistent storage

---

### 🔗 OIDC Provider

#### OIDC (OpenID Connect)
- **Provider**: EKS cluster's OIDC endpoint
- **Client ID**: `sts.amazonaws.com`
- **Certificate Thumbprint**: Automatically fetched from the cluster
- **Purpose**: Enables Kubernetes pods to assume IAM roles (fine-grained permissions)
- **How It Works**:
  1. A Kubernetes pod needs AWS permissions
  2. The pod gets a Kubernetes-signed JWT token
  3. The pod exchanges this token with AWS STS (Security Token Service)
  4. AWS verifies the token using the OIDC provider
  5. If valid, AWS grants temporary credentials for the associated IAM role
  6. The pod can now call AWS APIs (e.g., S3, DynamoDB) without hardcoded credentials

---

### 🧩 EKS Addons

Addons are AWS-managed Kubernetes extensions that provide essential cluster functionality.

#### 1. VPC CNI (`vpc-cni`)
- **Purpose**: Container Network Interface for networking pods
- **What It Does**:
  - Assigns AWS VPC IPs directly to pods (not NAT'd)
  - Manages ENIs (Elastic Network Interfaces) on worker nodes
  - Enables pod-to-pod and pod-to-service communication
- **Version**: Auto-fetched (latest compatible with cluster Kubernetes version)
- **IAM Role**: Uses `vpc_cni_role` (IRSA)
- **Namespace**: `kube-system`

#### 2. CoreDNS (`coredns`)
- **Purpose**: Kubernetes DNS service
- **What It Does**:
  - Resolves service names (e.g., `my-service.default`)
  - Enables pods to discover each other by hostname
  - Provides DNS caching
- **Version**: Auto-fetched
- **Namespace**: `kube-system`

#### 3. Kube-Proxy (`kube-proxy`)
- **Purpose**: Kubernetes networking service
- **What It Does**:
  - Routes traffic between pods and services
  - Implements network policies
  - Maintains iptables/ipvs rules on nodes
- **Version**: Auto-fetched
- **Namespace**: `kube-system`

#### 4. AWS EBS CSI Driver (`aws-ebs-csi-driver`)
- **Purpose**: Container Storage Interface for EBS volumes
- **What It Does**:
  - Allows pods to use EBS volumes as persistent storage
  - Dynamically provisions and manages EBS volumes
  - Handles volume snapshots
- **Version**: Auto-fetched
- **IAM Role**: Uses `ebs_csi_driver_role` (IRSA)
- **Namespace**: `kube-system`

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                          AWS Region (us-east-1)                 │
│                                                                   │
│ ┌──────────────────────────────────────────────────────────┐   │
│ │                    VPC (11.1.0.0/16)                      │   │
│ │                                                            │   │
│ │  ┌────────────────────────────────────────────────────┐  │   │
│ │  │           Internet Gateway (IGW)                   │  │   │
│ │  └────────────────────────────────────────────────────┘  │   │
│ │                          ▲                                │   │
│ │                          │ (routes 0.0.0.0/0)            │   │
│ │  ┌────────────────────────────────────────────────────┐  │   │
│ │  │      Public Subnets (1a, 1b, 1c)                  │  │   │
│ │  │  11.1.0.0/24 | 11.1.1.0/24 | 11.1.2.0/24         │  │   │
│ │  │                                                    │  │   │
│ │  │  ┌──────────────────────────────────────────────┐ │  │   │
│ │  │  │  NAT Gateway (with EIP)                      │ │  │   │
│ │  │  │  - Allows private subnets internet access    │ │  │   │
│ │  │  └──────────────────────────────────────────────┘ │  │   │
│ │  │                                                    │  │   │
│ │  │  ┌──────────────────────────────────────────────┐ │  │   │
│ │  │  │  EKS Control Plane (Kubernetes API)          │ │  │   │
│ │  │  │  - Public endpoint enabled                   │ │  │   │
│ │  │  │  - Private endpoint enabled                  │ │  │   │
│ │  │  └──────────────────────────────────────────────┘ │  │   │
│ │  └────────────────────────────────────────────────────┘  │   │
│ │                          ▲                                │   │
│ │                    (routes 0.0.0.0/0)                    │   │
│ │                          │                                │   │
│ │  ┌────────────────────────────────────────────────────┐  │   │
│ │  │     Private Subnets (1a, 1b, 1c)                 │  │   │
│ │  │  11.1.3.0/24 | 11.1.4.0/24 | 11.1.5.0/24        │  │   │
│ │  │                                                    │  │   │
│ │  │  ┌──────────────────────────────────────────────┐ │  │   │
│ │  │  │  EKS Worker Node 1 (t3.medium)               │ │  │   │
│ │  │  │  - Pods running on this node                 │ │  │   │
│ │  │  │  - Security Group: eks_node_sg               │ │  │   │
│ │  │  │  - IAM Role: eks_node_role                   │ │  │   │
│ │  │  └──────────────────────────────────────────────┘ │  │   │
│ │  │                                                    │  │   │
│ │  │  ┌──────────────────────────────────────────────┐ │  │   │
│ │  │  │  EKS Worker Node 2 (t3.medium)               │ │  │   │
│ │  │  │  - Pods running on this node                 │ │  │   │
│ │  │  │  - Security Group: eks_node_sg               │ │  │   │
│ │  │  │  - IAM Role: eks_node_role                   │ │  │   │
│ │  │  └──────────────────────────────────────────────┘ │  │   │
│ │  │                                                    │  │   │
│ │  │  ┌──────────────────────────────────────────────┐ │  │   │
│ │  │  │  Kubernetes Addons (kube-system namespace)  │ │  │   │
│ │  │  │  - vpc-cni (networking)                      │ │  │   │
│ │  │  │  - coredns (DNS)                             │ │  │   │
│ │  │  │  - kube-proxy (service routing)              │ │  │   │
│ │  │  │  - ebs-csi-driver (storage)                  │ │  │   │
│ │  │  └──────────────────────────────────────────────┘ │  │   │
│ │  └────────────────────────────────────────────────────┘  │   │
│ │                                                            │   │
│ └──────────────────────────────────────────────────────────┘   │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        IAM & Security                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  EKS Cluster Role ─── (trusts eks.amazonaws.com)                │
│  │                                                               │
│  └─ Policy: AmazonEKSClusterPolicy                              │
│                                                                   │
│  EKS Node Role ─────── (trusts ec2.amazonaws.com)               │
│  │                                                               │
│  ├─ Policy: AmazonEKSWorkerNodePolicy                           │
│  ├─ Policy: AmazonEKS_CNI_Policy                                │
│  └─ Policy: AmazonEC2ContainerRegistryReadOnly                  │
│                                                                   │
│  VPC CNI Role (IRSA) ─ (trusts EKS OIDC provider)               │
│  │                                                               │
│  ├─ Service Account: aws-node (kube-system)                     │
│  └─ Policy: AmazonEKS_CNI_Policy                                │
│                                                                   │
│  EBS CSI Driver Role (IRSA) ─ (trusts EKS OIDC provider)        │
│  │                                                               │
│  ├─ Service Account: ebs-csi-controller-sa (kube-system)        │
│  └─ Policy: AmazonEBSCSIDriverPolicy                            │
│                                                                   │
│  OIDC Provider ───────────────────────────────────────────      │
│  │                                                               │
│  ├─ URL: https://oidc.eks.us-east-1.amazonaws.com/id/<ID>      │
│  ├─ Client ID: sts.amazonaws.com                                │
│  └─ Certificate Thumbprint: <auto-fetched>                      │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
terraform-vpc-eks-module-ex2/
├── README.md                           # This file
├── backend.tf                          # Remote state configuration (S3)
├── provider.tf                         # AWS provider configuration
├── versions.tf                         # Terraform version constraints
├── variables.tf                        # Root-level input variables
├── terraform.tfvars                    # Variable values (dev/staging/prod)
├── vpc.tf                              # VPC module instantiation
├── eks.tf                              # EKS module instantiation
├── datasource.tf                       # Data sources (availability zones)
│
├── modules/
│   │
│   ├── vpc/
│   │   ├── main.tf                     # VPC, subnets, routes, IGW, NAT, SG
│   │   ├── variables.tf                # VPC module variables
│   │   ├── outputs.tf                  # VPC module outputs (VPC ID, subnet IDs)
│   │
│   └── eks/
│       ├── main.tf                     # EKS cluster, node group, IAM, addons, OIDC
│       ├── variables.tf                # EKS module variables
│
└── terraform.tfstate                   # Local state file (or remote if using backend.tf)
```

---

## How It Works

### 1️⃣ Infrastructure Creation Flow

```
terraform apply
    ↓
1. Create VPC with CIDR 11.1.0.0/16
    ↓
2. Create 3 public subnets (11.1.0.0/24, 11.1.1.0/24, 11.1.2.0/24)
    ↓
3. Create 3 private subnets (11.1.3.0/24, 11.1.4.0/24, 11.1.5.0/24)
    ↓
4. Create Internet Gateway and attach to VPC
    ↓
5. Create Elastic IP for NAT Gateway
    ↓
6. Create NAT Gateway in public subnet
    ↓
7. Create public route table (0.0.0.0/0 → IGW)
    ↓
8. Create private route table (0.0.0.0/0 → NAT)
    ↓
9. Associate subnets with route tables
    ↓
10. Create security groups (public_sg, eks_node_sg)
    ↓
11. Create IAM roles (cluster role, node role, addon roles)
    ↓
12. Create EKS cluster in public subnets
    ↓
13. Create OIDC provider (for pod IAM roles)
    ↓
14. Create EKS node group in private subnets
    ↓
15. Install EKS addons (vpc-cni, coredns, kube-proxy, ebs-csi-driver)
    ↓
✅ Cluster is ready!
```

### 2️⃣ Networking Flow

**Pod-to-Pod Communication:**
```
Pod A (11.1.3.5)  ──[vpc-cni]──> Pod B (11.1.4.10)
    ↓                                ↓
Node 1 (ENI 1)                    Node 2 (ENI 2)
    ↓                                ↓
VPC routing finds both in VPC → Direct communication (no NAT)
```

**Pod-to-Internet Communication:**
```
Pod A (11.1.3.5) ──[vpc-cni]──> Internet (e.g., DockerHub)
    ↓
Node 1 (private subnet)
    ↓
NAT Gateway (public subnet, EIP: 54.x.x.x)
    ↓
Internet Gateway
    ↓
✅ Reply comes back through the same path
```

### 3️⃣ OIDC & Pod IAM Role Flow

**VPC CNI Pod Needs to Manage ENIs:**
```
vpc-cni pod (kube-system)
    ↓
Pod gets Kubernetes JWT token (signed by cluster OIDC key)
    ↓
Pod calls AWS STS: "I want credentials for vpc-cni role"
    ↓
STS checks OIDC provider: "Is this a valid token from EKS cluster?"
    ↓
OIDC provider verifies JWT signature → ✅ Valid
    ↓
STS checks service account: "Is this aws-node in kube-system?" → ✅ Yes
    ↓
STS grants temporary credentials for vpc-cni role
    ↓
vpc-cni can now call AWS EC2 API (e.g., AssignPrivateIpAddresses)
```

### 4️⃣ Variable Flow

```
terraform.tfvars
    ↓
    ├─ region = "us-east-1"         ──→ eks.tf (var.region)
    ├─ cluster_name = "bootcampeks"  ──→ eks.tf (var.cluster_name)
    ├─ cluster_version = "1.31"      ──→ eks.tf (var.cluster_version)
    └─ vpc_cidr = "11.1.0.0/16"      ──→ vpc.tf (var.vpc_cidr)
            ↓
        modules/vpc/main.tf
            ├─ Creates subnets: cidrsubnet(11.1.0.0/16, 8, 0), cidrsubnet(..., 1), ...
            ├─ Outputs: vpc_id, public_subnet_cidrs, private_subnet_cidrs
            ↓
        modules/eks/main.tf
            ├─ Uses: module.vpc.vpc_id, module.vpc.public_subnet_cidrs
            └─ Creates: EKS cluster + nodes in VPC
```

---

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** installed (v1.0+)
3. **AWS CLI** configured with credentials
4. **kubectl** (optional, for managing the cluster)

```bash
# Check versions
terraform version
aws --version
kubectl version --client
```

---

## Usage

### 1. Initialize Terraform

```bash
cd terraform-vpc-eks-module-ex2
terraform init -upgrade
```

This initializes Terraform and downloads providers (AWS, TLS).

### 2. Validate Configuration

```bash
terraform validate
```

Checks for syntax errors and configuration issues.

### 3. Plan Infrastructure

```bash
terraform plan -var-file=terraform.tfvars
```

Shows what will be created (review before applying).

### 4. Apply Configuration

```bash
terraform apply --var-file=terraform.tfvars --auto-approve
```

Creates the infrastructure (~20-30 minutes for EKS cluster).

### 5. Verify Cluster

```bash
# Get cluster info
aws eks describe-cluster --name bootcampeks-cluster --region us-east-1

# Update kubeconfig
aws eks update-kubeconfig --name bootcampeks-cluster --region us-east-1

# Check nodes
kubectl get nodes

# Check addons
kubectl get pods -n kube-system
```

### 6. Destroy Infrastructure

```bash
terraform destroy --var-file=terraform.tfvars --auto-approve
```

Removes all created resources (saves costs).

---

## Configuration

### Key Variables (in `terraform.tfvars`)

| Variable | Default | Description |
|----------|---------|-------------|
| `region` | `us-east-1` | AWS region |
| `cluster_name` | `bootcampeks-cluster` | EKS cluster name |
| `cluster_version` | `1.31` | Kubernetes version |
| `vpc_cidr` | `11.1.0.0/16` | VPC CIDR block |

### Module Variables

#### VPC Module (`modules/vpc/variables.tf`)

| Variable | Default | Description |
|----------|---------|-------------|
| `vpc_cidr` | - | VPC CIDR block (required) |
| `subnet_cidr_bits` | `8` | Bits for subnet sizing (creates /24 subnets) |
| `availability_zone_count` | `3` | Number of AZs |
| `enable_dns_hostnames` | `true` | Enable DNS hostnames |
| `enable_dns_support` | `true` | Enable DNS support |

#### EKS Module (`modules/eks/variables.tf`)

| Variable | Default | Description |
|----------|---------|-------------|
| `region` | - | AWS region (required) |
| `cluster_name` | - | EKS cluster name (required) |
| `cluster_version` | - | Kubernetes version (required) |
| `vpc_id` | - | VPC ID (required) |
| `public_subnet_id` | - | List of public subnet IDs (required) |
| `private_subnet_id` | - | List of private subnet IDs (required) |

---

## Outputs

After `terraform apply`, key information is displayed:

```bash
# View outputs
terraform output

# Get specific output
terraform output eks_cluster_name
terraform output vpc_id
```

### Available Outputs

- `vpc_id`: ID of the created VPC
- `vpc_cidr`: CIDR block of the VPC
- `public_subnet_ids`: IDs of public subnets
- `private_subnet_ids`: IDs of private subnets
- `eks_cluster_name`: EKS cluster name
- `eks_cluster_endpoint`: EKS API endpoint
- `eks_cluster_version`: Kubernetes version
- `eks_cluster_security_group_id`: Security group for EKS cluster
- `eks_node_group_id`: Node group ID
- `eks_node_group_status`: Node group status

---

## Cost Estimation

**Monthly costs (approximate, in us-east-1):**

| Component | Type | Cost |
|-----------|------|------|
| EKS Control Plane | Fixed | $0.10/hour (~$73/month) |
| EC2 Nodes (2x t3.medium) | On-Demand | ~$60/month |
| EC2 Nodes (2x t3.medium) | Spot | ~$18/month |
| NAT Gateway | Data processing | ~$32/month (varies) |
| EBS (20GB per node) | Storage | ~$2/month |
| Data Transfer | Out of VPC | ~$0.09/GB |
| **Total** | **On-Demand** | ~$167/month |
| **Total** | **Spot** | ~$107/month |

**To reduce costs:**
- Use Spot instances (already configured)
- Delete cluster when not in use
- Use smaller instance types (t3.small)

---

## Troubleshooting

### Cluster Creation Timeout
- **Cause**: Network or API issues during cluster creation
- **Solution**: Run `terraform destroy` and try again

### Addons Stuck in "Creating"
- **Cause**: OIDC provider not properly configured
- **Solution**: Ensure `aws_iam_openid_connect_provider` is created first

### Nodes Not Ready
- **Cause**: Missing IAM permissions or security group rules
- **Solution**: Check IAM roles and security group rules

### Pods Cannot Pull Images
- **Cause**: ECR read permissions or network issues
- **Solution**: Ensure `AmazonEC2ContainerRegistryReadOnly` policy is attached

---

## Security Best Practices

✅ **Implemented in this setup:**
- Private subnets for worker nodes (not directly exposed to internet)
- NAT Gateway for secure outbound internet access
- OIDC provider for fine-grained pod IAM roles (no hardcoded credentials)
- Security groups with restrictive rules
- DNS enabled for service discovery

⚠️ **Additional recommendations:**
- Enable EKS pod security policies or Pod Security Standards
- Use network policies to restrict pod-to-pod communication
- Enable logging (control plane logs, VPC Flow Logs)
- Implement RBAC for Kubernetes access control
- Use AWS Secrets Manager for application secrets
- Enable EC2 auto-scaling based on metrics

---

## Additional Resources

- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS User Guide](https://docs.aws.amazon.com/eks/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

---

## License

This project is provided as-is for educational and development purposes.

---

**Last Updated**: January 2026  
**Terraform Version**: 1.0+  
**AWS Provider Version**: 5.0+  
**Kubernetes Version**: 1.31
