locals {
  common_tags = {
    Env     = "test"
    Project = "ipsec-playground"
  }
}

resource "aws_vpc" "left" {
  cidr_block                       = "10.0.0.0/24"
  enable_dns_hostnames             = true
  assign_generated_ipv6_cidr_block = false

  tags = local.common_tags
}

resource "aws_vpc" "right" {
  cidr_block                       = "10.1.0.0/24"
  enable_dns_hostnames             = true
  assign_generated_ipv6_cidr_block = false

  tags = local.common_tags
}

resource "aws_internet_gateway" "left" {
  vpc_id = aws_vpc.left.id
  tags   = local.common_tags
}

resource "aws_internet_gateway" "right" {
  vpc_id = aws_vpc.right.id
  tags   = local.common_tags
}

resource "aws_subnet" "left" {
  cidr_block              = cidrsubnet(aws_vpc.left.cidr_block, 2, 0)
  vpc_id                  = aws_vpc.left.id
  map_public_ip_on_launch = true
  tags                    = local.common_tags
}

resource "aws_subnet" "right" {
  cidr_block              = cidrsubnet(aws_vpc.right.cidr_block, 2, 0)
  vpc_id                  = aws_vpc.right.id
  map_public_ip_on_launch = true
  tags                    = local.common_tags
}

resource "aws_network_interface" "left" {
  subnet_id         = aws_subnet.left.id
  security_groups   = [aws_security_group.allow_all_left.id]
  private_ips       = [cidrhost(aws_vpc.left.cidr_block, 4)]
  source_dest_check = false
  tags              = local.common_tags
}

resource "aws_network_interface" "right" {
  subnet_id         = aws_subnet.right.id
  security_groups   = [aws_security_group.allow_all_right.id]
  private_ips       = [cidrhost(aws_vpc.right.cidr_block, 4)]
  source_dest_check = false
  tags              = local.common_tags
}

resource "aws_route_table" "left" {
  vpc_id = aws_vpc.left.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.left.id
  }

  tags = local.common_tags
}

resource "aws_route_table" "right" {
  vpc_id = aws_vpc.right.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.right.id
  }

  tags = local.common_tags
}

resource "aws_route_table_association" "left" {
  subnet_id      = aws_subnet.left.id
  route_table_id = aws_route_table.left.id
}

resource "aws_route_table_association" "right" {
  subnet_id      = aws_subnet.right.id
  route_table_id = aws_route_table.right.id
}

resource "aws_security_group" "allow_all_left" {
  name   = "allow-all"
  vpc_id = aws_vpc.left.id

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

resource "aws_security_group" "allow_all_right" {
  name   = "allow-all"
  vpc_id = aws_vpc.right.id

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
  network_interface = aws_network_interface.left.id
  tags              = local.common_tags
}

resource "aws_eip" "right" {
  network_interface = aws_network_interface.right.id
  tags     = local.common_tags
}

data "cloudinit_config" "ipsec" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    content      = file("${path.root}/data/init.yml")
  }
}

resource "aws_instance" "left" {
  ami           = data.aws_ami.fedora.id
  instance_type = "t2.micro"
  user_data     = data.cloudinit_config.ipsec.rendered
  key_name      = aws_key_pair.ipsec.key_name

  network_interface {
    network_interface_id = aws_network_interface.left.id
    device_index         = 0
  }

  tags = merge(local.common_tags, { "Name" = "ipsec-left" })
}

resource "aws_instance" "right" {
  ami           = data.aws_ami.fedora.id
  instance_type = "t2.micro"
  user_data     = data.cloudinit_config.ipsec.rendered
  key_name      = aws_key_pair.ipsec.key_name

  network_interface {
    network_interface_id = aws_network_interface.right.id
    device_index         = 0
  }

  tags = merge(local.common_tags, { "Name" = "ipsec-right" })
}

resource "aws_key_pair" "ipsec" {
  key_name   = "ipsec_local_key"
  public_key = file("~/.ssh/id_ed25519.pub")
  tags       = local.common_tags
}
