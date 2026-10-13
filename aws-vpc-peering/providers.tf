terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.68.0"
    }
  }
}

# Provider for the primary region (us-east-1)
provider "aws" {
  region = "us-east-1"
  alias = "primary"
}

# Provider for the secondary region (us-west-2)
provider "aws" {
  region = "us-west-2"
  alias = "secondary"
}