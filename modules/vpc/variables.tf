variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

# variable "public_subnet_cidrs" {
#     description = "public subnet CIDR block"
#     type = list(string)
#     default = []
# }

# variable "private_subnet_cidrs" {
#   description = "private subnet CIDR block"
#   type = list(string)
#   default = []
# }

variable "subnet_cidr_bits" {
  description = "The number of subnet bits for the CIDR"
  type        = number
  default     = 8
}

# variable "azs" {
#   description = "availability zones"
#   type = list(string)
#   default = []
# }

variable "availability_zone_count" {
  description = "number of azs"
  type        = number
  default     = 3
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support"
  type        = bool
  default     = true
}

variable "tags" {
  description = "apply tags to all resources"
  type        = map(string)
  default     = {}
}