module "eks" {
  source = "./modules/eks"

  region            = var.region
  cluster_name      = var.cluster_name
  private_subnet_id = module.vpc.private_subnet_cidrs
  public_subnet_id  = module.vpc.public_subnet_cidrs
  vpc_id            = module.vpc.vpc_id
  cluster_version   = var.cluster_version

  managed_node_groups = {
    demo-group = {
      name           = "public-ng"
      desired_size   = 2
      max_size       = 3
      min_size       = 1
      instance_types = ["t3a.small"]
    }
  }
}