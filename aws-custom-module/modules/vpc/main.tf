resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "Custom-Module-VPC"
  }
}

data "aws_availability_zones" "azs" {
  state = "available"
}

resource "aws_subnet" "public_vpc_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.azs
  map_public_ip_on_launch = true

  tags = {
    Name = "Public-VPC-Subnet"
  }
}

resource "aws_subnet" "private_vpc_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.private_subnet_cidr
  availability_zone       = var.azs
  map_public_ip_on_launch = false

  tags = {
    Name = "Private-VPC-Subnet"
  }
}

resource "aws_internet_gateway" "vpc_igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "VPC-IGW"
  }
}

# --- PUBLIC ROUTE TABLE ---
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpc_igw.id
  }

  tags = {
    Name = "Public-VPC-Route-Table"
  }
}

resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.public_vpc_subnet.id
  route_table_id = aws_route_table.public_rt.id
}


# --- NAT GATEWAY & PRIVATE ROUTE TABLE ---

# 1. Elastic IP required for the NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = {
    Name = "VPC-NAT-EIP"
  }
}

# 2. NAT Gateway placed in the PUBLIC subnet
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_vpc_subnet.id

  tags = {
    Name = "VPC-NAT-Gateway"
  }

  # Ensures the Internet Gateway is fully available before building the NAT Gateway
  depends_on = [aws_internet_gateway.vpc_igw]
}

# 3. Route Table for the Private Subnet
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "Private-VPC-Route-Table"
  }
}

# 4. Association linking the Private Route Table to the Private Subnet
resource "aws_route_table_association" "private_rta" {
  subnet_id      = aws_subnet.private_vpc_subnet.id
  route_table_id = aws_route_table.private_rt.id
}