# Primary VPC in us-east-1
resource "aws_vpc" "primary_vpc" {
  cidr_block       = var.primary_vpc_cidr
  provider        = aws.primary
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "Primary-VPC"
  }
}

# Secondary VPC in us-west-2
resource "aws_vpc" "secondary_vpc" {
  cidr_block       = var.secondary_vpc_cidr
  provider        = aws.secondary
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "Secondary-VPC"
  }
}

# Subnet in Primary VPC
resource "aws_subnet" "primary_vpc_subnet" {
  vpc_id     = aws_vpc.primary_vpc.id
  cidr_block = var.primary_vpc_cidr
  provider   = aws.primary
  availability_zone = data.aws_availability_zones.primary.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "Primary-VPC-Subnet"
  }
}

# Subnet in Secondary VPC
resource "aws_subnet" "secondary_vpc_subnet" {
  vpc_id     = aws_vpc.secondary_vpc.id
  cidr_block = var.secondary_vpc_cidr
  provider   = aws.secondary
  availability_zone = data.aws_availability_zones.secondary.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "Secondary-VPC-Subnet"
  }
}

# Internet Gateway for Primary VPC
resource aws_internet_gateway "primary_vpc_igw" {
  vpc_id   = aws_vpc.primary_vpc.id
  provider = aws.primary

  tags = {
    Name = "Primary-VPC-IGW"
  }
}

# Internet Gateway for Secondary VPC
resource aws_internet_gateway "secondary_vpc_igw" {
  vpc_id   = aws_vpc.secondary_vpc.id
  provider = aws.secondary

  tags = {
    Name = "Secondary-VPC-IGW"
  }
}

# Route table for Primary VPC
resource "aws_route_table" "primary_rt" {
  vpc_id = aws_vpc.primary_vpc.id
  provider = aws.primary

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.primary_vpc_igw.id
  }

  route {
    cidr_block = aws_vpc.secondary_vpc.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary.id
  }

  tags = {
    Name = "Primary-VPC-Route-Table"
  }

  depends_on = [aws_vpc_peering_connection_accepter.secondary_accepter]
}

# Associate route table with Primary subnet
resource "aws_route_table_association" "primary_rta" {
  provider = aws.primary
  subnet_id      = aws_subnet.primary_vpc_subnet.id
  route_table_id = aws_route_table.primary_rt.id
}

# Route table for Secondary VPC
resource "aws_route_table" "secondary_rt" {
  vpc_id = aws_vpc.secondary_vpc.id
  provider = aws.secondary

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.secondary_vpc_igw.id
  }

  route {
    cidr_block = aws_vpc.primary_vpc.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary.id
  }

  tags = {
    Name = "Secondary-VPC-Route-Table"
  }

  depends_on = [aws_vpc_peering_connection_accepter.secondary_accepter]
}

# Associate route table with Secondary subnet
resource "aws_route_table_association" "secondary_rta" {
  provider = aws.secondary
  subnet_id      = aws_subnet.secondary_vpc_subnet.id
  route_table_id = aws_route_table.secondary_rt.id
}

# VPC Peering Connection (Requester side - Primary VPC)
resource "aws_vpc_peering_connection" "primary_to_secondary" {
  provider = aws.primary
  vpc_id        = aws_vpc.primary_vpc.id
  peer_vpc_id   = aws_vpc.secondary_vpc.id
  peer_region  = "us-west-2"
  auto_accept   = false

  tags = {
    Name = "VPC-Peering primary to secondary"
  }
}

# VPC Peering Connection Accepter (Accepter side - Secondary VPC)
resource "aws_vpc_peering_connection_accepter" "secondary_accepter" {
  provider = aws.secondary
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary.id
  auto_accept   = true

  tags = {
    Name = "VPC-Peering secondary accepter"
  }
}

# Security Group for Primary VPC EC2 instance
resource "aws_security_group" "primary_sg" {
  provider    = aws.primary
  name        = "primary-vpc-sg"
  description = "Security group for Primary VPC instance"
  vpc_id      = aws_vpc.primary_vpc.id

  dynamic "ingress" {
    for_each = var.ingress_primary
    content {
      description = ingress.value.description
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "Primary-VPC-SG"
    Environment = "Demo"
  }
}

# Security Group for Secondary VPC EC2 instance
resource "aws_security_group" "secondary_sg" {
  provider    = aws.secondary
  name        = "secondary-vpc-sg"
  description = "Security group for Secondary VPC instance"
  vpc_id      = aws_vpc.secondary_vpc.id

  dynamic "ingress" {
    for_each = var.ingress_secondary
    content {
      description = ingress.value.description
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "Secondary-VPC-SG"
  }
}

# EC2 Instance in Primary VPC
resource "aws_instance" "primary_instance" {
  provider               = aws.primary
  ami                    = data.aws_ami.primary_ami.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.primary_vpc_subnet.id
  vpc_security_group_ids = [aws_security_group.primary_sg.id]
  key_name               = "vpc-peering-demo"

  user_data = local.primary_user_data

  tags = {
    Name        = "Primary-VPC-Instance"
    Region      = "us-east-1"
  }

  depends_on = [aws_vpc_peering_connection_accepter.secondary_accepter]
}

# EC2 Instance in Secondary VPC
resource "aws_instance" "secondary_instance" {
  provider               = aws.secondary
  ami                    = data.aws_ami.secondary_ami.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.secondary_vpc_subnet.id
  vpc_security_group_ids = [aws_security_group.secondary_sg.id]
  key_name               = "vpc-peering-demo"

  user_data = local.secondary_user_data

  tags = {
    Name        = "Secondary-VPC-Instance"
    Region      = "us-west-2"
  }

  depends_on = [aws_vpc_peering_connection_accepter.secondary_accepter]
}