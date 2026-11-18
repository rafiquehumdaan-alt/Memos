variable "vpc_id" {
  description = "ID of the Memos VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC address range allowed to reach the interface endpoints"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs of the private subnets that get an interface endpoint network interface"
  type        = list(string)
}

variable "private_route_table_ids" {
  description = "IDs of the private route tables that get the S3 gateway endpoint route"
  type        = list(string)
}