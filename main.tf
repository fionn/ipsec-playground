locals {
  common_tags = {
    Env     = "test"
    Project = "ipsec-playground"
  }
}

resource "aws_vpc" "ipsec" {
  cidr_block                       = "10.0.0.0/16"
  enable_dns_hostnames             = true
  assign_generated_ipv6_cidr_block = false

  tags = local.common_tags
}

resource "aws_internet_gateway" "ipsec" {
  vpc_id = aws_vpc.ipsec.id
  tags   = local.common_tags
}

resource "aws_subnet" "left" {
  cidr_block              = cidrsubnet(aws_vpc.ipsec.cidr_block, 8, 1)
  vpc_id                  = aws_vpc.ipsec.id
  map_public_ip_on_launch = true
  tags                    = local.common_tags
}

resource "aws_subnet" "right" {
  cidr_block              = cidrsubnet(aws_vpc.ipsec.cidr_block, 8, 0)
  vpc_id                  = aws_vpc.ipsec.id
  map_public_ip_on_launch = true
  tags                    = local.common_tags
}

resource "aws_route_table" "internet" {
  vpc_id = aws_vpc.ipsec.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ipsec.id
  }

  tags = local.common_tags
}

resource "aws_route_table_association" "left" {
  subnet_id      = aws_subnet.left.id
  route_table_id = aws_route_table.internet.id
}

resource "aws_route_table_association" "right" {
  subnet_id      = aws_subnet.right.id
  route_table_id = aws_route_table.internet.id
}

resource "aws_security_group" "allow_all" {
  name   = "allow-all"
  vpc_id = aws_vpc.ipsec.id

  ingress {
    description = "Allow all inbound"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

data "aws_ami" "fedora" {
  owners      = ["125523088429"] # Fedora
  most_recent = true

  filter {
    name   = "name"
    values = ["Fedora-Cloud-Base-35-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_eip" "left" {
  instance = aws_instance.left.id
  tags     = local.common_tags
}

resource "aws_eip" "right" {
  instance = aws_instance.right.id
  tags     = local.common_tags
}


data "cloudinit_config" "left" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    content      = file("${path.root}/data/base.yml")
  }

  part {
    content_type = "text/cloud-config"
    content      = file("${path.root}/data/forwarding.yml")
  }
}

data "cloudinit_config" "right" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    content      = file("${path.root}/data/base.yml")
  }
}

resource "aws_instance" "left" {
  ami                    = data.aws_ami.fedora.id
  instance_type          = "t2.micro"
  user_data              = data.cloudinit_config.left.rendered
  vpc_security_group_ids = [aws_security_group.allow_all.id]
  subnet_id              = aws_subnet.left.id
  key_name               = aws_key_pair.ipsec.key_name
  tags                   = merge(local.common_tags, { "Name" = "ipsec-left" })
}

resource "aws_instance" "right" {
  ami                    = data.aws_ami.fedora.id
  instance_type          = "t2.micro"
  user_data              = data.cloudinit_config.right.rendered
  vpc_security_group_ids = [aws_security_group.allow_all.id]
  subnet_id              = aws_subnet.right.id
  key_name               = aws_key_pair.ipsec.key_name
  tags                   = merge(local.common_tags, { "Name" = "ipsec-right" })
}

resource "aws_key_pair" "ipsec" {
  key_name   = "ipsec_local_key"
  public_key = file("~/.ssh/id_ed25519.pub")
  tags       = local.common_tags
}
