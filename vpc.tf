#module for vpc
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr             = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  subnet_cidr_bits        = 8
  availability_zone_count = 3
}