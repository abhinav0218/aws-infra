variable "vpc_cidr_block" {
}

variable "profile" {
  type = string
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


resource "random_id" "random" {
  byte_length = 4
}


resource "aws_iam_policy" "webapp_s3_policy" {
  name = "WebAppS3"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::my-bucket-${random_id.random.hex}",
          "arn:aws:s3:::my-bucket-${random_id.random.hex}/*",
        ]
      },
    ]
  })
}

resource "aws_s3_bucket" "private_s3_bucket" {
  bucket        = "my-bucket-${random_id.random.hex}"
  acl           = "private"
  force_destroy = true

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }


  tags = {
    Environment = "dev"
    Name        = "private_s3_bucket"
  }
}

resource "aws_s3_bucket_public_access_block" "my_bucket_public_access_block" {
  bucket = "my-bucket-${random_id.random.hex}"

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "private_bucket_lifecycle" {
  bucket = aws_s3_bucket.private_s3_bucket.id
  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }

  rule {
    id     = "delete-empty-bucket"
    prefix = ""
    status = "Enabled"
    //abort_incomplete_multipart_upload_days = 7
    expiration {
      days = 14
    }
  }
}




# Configure the PostgreSQL parameter group
resource "aws_db_parameter_group" "postgres_params" {
  name_prefix = "csye6225-postgres-params"
  family      = "postgres13"

  parameter {
    apply_method = "pending-reboot"
    name         = "max_connections"
    value        = "100"
  }

  parameter {
    apply_method = "pending-reboot"
    name         = "shared_buffers"
    value        = "16"
  }
}





resource "aws_db_subnet_group" "private_rds_subnet_group" {
  name        = "private-rds-subnet-group"
  description = "Private subnet group for RDS instances"
  subnet_ids  = aws_subnet.private_subnets.*.id
}


resource "aws_iam_role" "ec2_csye6225_role" {
  name = "EC2-CSYE6225"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "EC2-CSYE6225-Role"
  }
}

resource "aws_iam_role_policy_attachment" "webapp_s3_policy_attachment" {
  policy_arn = aws_iam_policy.webapp_s3_policy.arn
  role       = aws_iam_role.ec2_csye6225_role.name
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "EC2-CSYE6225-Instance-Profile"

  role = aws_iam_role.ec2_csye6225_role.name
}



resource "aws_security_group" "database_security_group" {
  name_prefix = "db_security_group"
  vpc_id      = aws_vpc.vpc1.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    
    security_groups = [aws_security_group.app_security_group.id]

  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "rds_instance" {
  allocated_storage    = 10
  identifier           = "csye6225"
  engine               = "postgres"
  instance_class       = "db.t3.micro"
  multi_az             = false
  username             = "csye6225"
  password             = "pickapassword"
  db_subnet_group_name = aws_db_subnet_group.private_rds_subnet_group.name
  publicly_accessible  = false
  name                 = "csye6225"
  skip_final_snapshot  = true
  # Attach database security group
  vpc_security_group_ids = [
    aws_security_group.app_security_group.id,
    aws_security_group.database_security_group.id
  ]
}

resource "aws_instance" "my_ec2_instance" {

  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public_subnets[1].id
  vpc_security_group_ids = [aws_security_group.app_security_group.id, aws_security_group.database_security_group.id]
  
  user_data = <<-EOF
#!/bin/bash
cd /home/ec2-user/script
touch ./.env

echo "DB_HOST=$(echo ${aws_db_instance.rds_instance.endpoint} | cut -d ':' -f 1)" >> .env
echo "DB_USER=${aws_db_instance.rds_instance.username}" >> .env
echo "DB_PASSWORD=${aws_db_instance.rds_instance.password}" >> .env
echo "S3_BUCKET_NAME=${aws_s3_bucket.private_s3_bucket.bucket}" >> .env

sudo su
mkdir ./upload
sudo chown ec2-user:ec2-user /home/ec2-user/script/*
sudo systemctl stop webapp.service
sudo systemctl daemon-reload
sudo systemctl enable webapp.service
sudo systemctl start webapp.service

source ./.env

EOF

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
iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

}

