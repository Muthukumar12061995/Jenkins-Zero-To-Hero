locals {
  tag = "mk-cicd-lab"
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "${local.tag}-vpc"
  }
}

resource "aws_subnet" "public-subnet" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.tag}-us-east-1a-public-subnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  
  tags = {
    Name = "${local.tag}-igw"
  }
  
}

resource "aws_route_table" "public-route-table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  route {
    cidr_block = aws_vpc.vpc.cidr_block
    gateway_id = "local"
  }

  tags = {
    Name = "${local.tag}-public-route-table"
  }
}

resource "aws_route_table_association" "public-route-asso" {
  route_table_id = aws_route_table.public-route-table.id
  subnet_id = aws_subnet.public-subnet.id
}

variable "public_key" {
  default = "~/.ssh/ec2.pub"
}
resource "aws_key_pair" "ssh-key" {
  key_name = "ec2-ssh"
  public_key = file(var.public_key)
}

locals {
  rules = {
    ssh = {
      port = 22,
      protocol = "tcp"
      cidr_block = [ "0.0.0.0/0" ]
    }
    http = {
      port = 80
      protocol = "tcp"
      cidr_block = [ "0.0.0.0/0" ]
    }
    https = {
      port = 443
      protocol = "tcp"
      cidr_block = [ "0.0.0.0/0" ]
    }
    sonar = {
      port = 9000
      protocol = "tcp"
      cidr_block = [ "0.0.0.0/0" ]
    }
    jenkins = {
      port = 8080
      protocol = "tcp"
      cidr_block = [ "0.0.0.0/0" ]
    }
  }

}

resource "aws_security_group" "ec2-sg" {
  vpc_id = aws_vpc.vpc.id
  description = "allow access"
  dynamic "ingress" {
    for_each = local.rules
    content {
      from_port = ingress.value.port
      to_port = ingress.value.port
      protocol = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_block
    }
  }

  dynamic "egress" {
    for_each = local.rules
    content {
      from_port = egress.value.port
      to_port = egress.value.port
      protocol = egress.value.protocol
      cidr_blocks = egress.value.cidr_block
    }
  }
}

resource "aws_instance" "ec2" {
  ami = "ami-0a0e5d9c7acc336f1"
  instance_type = "t2.large"
  subnet_id = aws_subnet.public-subnet.id
  security_groups = [ aws_security_group.ec2-sg.id ]
  key_name = aws_key_pair.ssh-key.key_name
  user_data = file("${path.module}/user-data.sh")
  tags = {
    Name = "${local.tag}-ec2"
  }
}