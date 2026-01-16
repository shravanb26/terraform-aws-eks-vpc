terraform {
  backend "s3" {
    bucket = "bootcamp-tfstate-bucket-vpceks-module"
    key    = "aws-vpc-terraform-configuration/terraform.tfstate"
    region = "us-east-1"
  }
}