module "vpc1" {
  source                     = "./modules/networking"
  vpc_cidr_block             = var.vpc_cidr_block
  public_subnet_cidr_blocks  = var.public_subnet_cidr_blocks
  private_subnet_cidr_blocks = var.private_subnet_cidr_blocks
  aws_region                 = var.aws_region
  instance_type              = var.instance_type
  ami_id                     = var.ami_id
  key_name                   = var.key_name
  private_key_path           = var.private_key_path
  protect_from_termination   = var.protect_from_termination
  root_volume_size           = var.root_volume_size
  root_volume_type           = var.root_volume_type
  availability_zones_suffix  = var.availability_zones_suffix
  profile                    = var.profile

  # Define other variables as needed...
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "profile" {
  type    = string
  default = "demo"

}

variable "vpc_cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr_blocks" {
  type = list(string)
  default = [
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24",
  ]
}

variable "private_subnet_cidr_blocks" {
  type = list(string)
  default = [
    "10.0.11.0/24",
    "10.0.12.0/24",
    "10.0.13.0/24",
  ]
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "ami_id" {
  type = string

}

variable "key_name" {
  type    = string
  default = "amiLogin"
}

variable "private_key_path" {
  type    = string
  default = "~/.aws/credentials"
}

variable "protect_from_termination" {
  type    = bool
  default = true
}

variable "root_volume_size" {
  type    = number
  default = 50
}

variable "root_volume_type" {
  type    = string
  default = "gp2"
}

variable "availability_zones_suffix" {
  type = map(string)
  default = {
    "us-east-1" = "abc"
    "us-west-2" = "def"
  }
}