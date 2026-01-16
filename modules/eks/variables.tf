variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "vpc id"
  type        = string
}

variable "cluster_name" {
  description = "Name of eks cluster"
  type        = string
}

variable "cluster_version" {
  description = "version of eks cluster"
  type        = string
}

variable "public_subnet_id" {
  description = "public subnet id for eks cluster"
  type        = list(string)
}

variable "private_subnet_id" {
  description = "private subnet id for eks cluster"
  type        = list(string)
}

variable "default_ami_type" {
  description = "type of AMI to use"
  type        = string
  default     = "AL2_x86_64"
}

variable "default_capacity_type" {
  description = "capacity type of node group"
  type        = string
  default     = "SPOT"
}

variable "managed_node_groups" {
  description = "specify node groups"
  type = map(object({
    name : string
    desired_size : number
    min_size : number
    max_size : number
    instance_types : list(string)
  }))
  default = {}
}

variable "cluster_addons" {
  description = "cluster addons"
  type        = list(string)
  default     = ["vpc-cni", "kube-proxy", "coredns", "aws-ebs-csi-driver"]
}

variable "enable_cluster_log_types" {
  description = "list of cluster log type"
  type        = list(string)
  default     = ["audit", "api", "authenticator"]
}