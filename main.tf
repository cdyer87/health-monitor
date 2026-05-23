# main.tf - Foundation: The VPC

resource "aws_vpc" "main_network" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "enterprise-web-vpc"
    Environment = "production-ready"
    Project     = "AutoScalingWebStack"
  }
}