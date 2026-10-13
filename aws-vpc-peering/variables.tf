variable "primary_vpc_cidr" {
    default = "10.0.0.0/16"
}

variable "secondary_vpc_cidr" {
    default = "10.1.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ingress_primary" {
    type = list(object(
    {
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    }))
    default = [{
        description = "SSH from anywhere"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "ICMP from Secondary VPC"
      from_port   = -1
      to_port     = -1
      protocol    = "icmp"
      cidr_blocks = ["10.1.0.0/16"]
    },
    {
      description = "All traffic from Secondary VPC"
      from_port   = 0
      to_port     = 65535
      protocol    = "tcp"
      cidr_blocks = ["10.1.0.0/16"]
    }]
}

variable "ingress_secondary" {
    type = list(object(
    {
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    }))
    default = [{
        description = "SSH from anywhere"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "ICMP from Primary VPC"
      from_port   = -1
      to_port     = -1
      protocol    = "icmp"
      cidr_blocks = ["10.0.0.0/16"]
    },
    {
      description = "All traffic from Primary VPC"
      from_port   = 0
      to_port     = 65535
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
    }]
}