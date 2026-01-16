variable "region" {
  type        = string
  default     = "us-east-1"
  description = "Target AWS region"
}

variable "cluster_name" {
  type        = string
  default     = "bookcamp-eks-cluster"
  description = "Name of the EKS cluster"
}

variable "cluster_version" {
  type        = string
  description = "version of eks cluster"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for VPC"
  default     = "11.1.0.0/16"
}