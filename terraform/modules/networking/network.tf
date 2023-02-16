
variable "vpc_cidr_block" {
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
  count = length(var.public_subnet_cidr_blocks)
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
  availability_zone = "${var.aws_region}${substr("abc", tonumber(count.index), 1)}"
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
