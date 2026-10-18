data "aws_availability_zones" "azs" {
  state = "available"
}

module "my_custom_vpc" {
  source = "./modules/vpc"

  vpc_cidr            = "10.0.0.0/16"
  public_subnet_cidr  = "10.0.1.0/24"
  private_subnet_cidr = "10.0.2.0/24"
  azs = data.aws_availability_zones.azs.names[0]
  
}