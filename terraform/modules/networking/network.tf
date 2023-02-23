variable "vpc_cidr_block" {
}


variable "availability_zones_suffix" {
  type = map(string)
}
variable "aws_region" {

  type = string
}

variable "public_subnet_cidr_blocks" {

  type = list(string)
}

variable "private_subnet_cidr_blocks" {

  type = list(string)
}

variable "instance_type" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "key_name" {
  type = string
}

variable "private_key_path" {
  type = string
}

variable "protect_from_termination" {
  type = bool
}

variable "root_volume_size" {
  type = number
}

variable "root_volume_type" {
  type = string
}
resource "aws_vpc" "vpc1" {

  cidr_block = var.vpc_cidr_block
  tags = {
    Name = "vpc1"
  }
}


resource "aws_internet_gateway" "igw" {

  vpc_id = aws_vpc.vpc1.id
  tags = {
    Name = "internet_gateway"
  }
}


resource "aws_subnet" "public_subnets" {
  count                   = length(var.public_subnet_cidr_blocks)
  map_public_ip_on_launch = true
  tags = {
    Name = "public_subnet${count.index}"
  }
  vpc_id            = aws_vpc.vpc1.id
  cidr_block        = var.public_subnet_cidr_blocks[count.index]
  availability_zone = "${var.aws_region}${substr("abc", tonumber(count.index), 1)}"
}

resource "aws_subnet" "private_subnets" {
  count = length(var.private_subnet_cidr_blocks)
  tags = {
    Name = "private_subnet${count.index}"
  }

  vpc_id            = aws_vpc.vpc1.id
  cidr_block        = var.private_subnet_cidr_blocks[count.index]
  availability_zone = "${var.aws_region}${substr(var.availability_zones_suffix[var.aws_region], count.index, 1)}"
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc1.id
  tags = {
    Name = "public_route_table"
  }
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id

}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc1.id
  tags = {
    Name = "private_route_table"
  }

}

resource "aws_route_table_association" "public_subnet_associations" {
  count          = length(aws_subnet.public_subnets)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_route_table.id

}

resource "aws_route_table_association" "private_subnet_associations" {
  count          = length(aws_subnet.private_subnets)
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_route_table.id

}


resource "aws_security_group" "app_security_group" {
  name_prefix = "app_security_group"
  vpc_id      = aws_vpc.vpc1.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "my_ec2_instance" {

  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public_subnets[1].id
  vpc_security_group_ids = [aws_security_group.app_security_group.id]
  root_block_device {
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type
  }
  disable_api_termination = var.protect_from_termination

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file(var.private_key_path)
    host        = self.public_ip
  }


}
