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
resource "aws_internet_gateway" "igw" {

  vpc_id = aws_vpc.vpc1.id
  tags = {
    Name = "internet_gateway"
  }
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


resource "aws_security_group" "instance" {
  name_prefix = "instance-security-group"
  vpc_id      = aws_vpc.vpc1.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.load_balancer_security_group.id]
    cidr_blocks     = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.load_balancer_security_group.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "all"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "database_security_group" {
  name_prefix = "db_security_group"
  vpc_id      = aws_vpc.vpc1.id

  ingress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"

    security_groups = [aws_security_group.instance.id]

  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "all"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "load_balancer_security_group" {
  name_prefix = "load_balancer_security_group"
  vpc_id      = aws_vpc.vpc1.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "all"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "load_balancer_security_group"
  }
}


resource "random_id" "random" {
  byte_length = 4
}







resource "aws_lb" "load_balancer" {
  name               = "web-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.load_balancer_security_group.id]
  subnets            = [aws_subnet.public_subnets[0].id, aws_subnet.public_subnets[1].id, aws_subnet.public_subnets[2].id]
  enable_deletion_protection = false
  tags = {
    Environment = "prod"
  }
}
output "load_balancer_dns_name" {
  value = aws_lb.load_balancer.dns_name
}




resource "aws_lb_target_group" "target_group" {
  name        = "web-tg"
  port        = 3000
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.vpc1.id
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 300
    path                = "/healthz"
  }


}

resource "aws_lb_listener" "lb_listener" {

  load_balancer_arn = aws_lb.load_balancer.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }

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
          "s3:ListBucket",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics",
          "cloudwatch:PutMetricData",
          "ec2:DescribeTags",
          "application-autoscaling:*"
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
    Environment = "${var.profile}"
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

resource "aws_db_parameter_group" "postgres_params" {
  name_prefix = "csye6225-postgres-params"
  family      = "postgres14"

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

resource "aws_db_instance" "rds_instance" {
  allocated_storage    = 20
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
  parameter_group_name = aws_db_parameter_group.postgres_params.name
  # Attach database security group
  vpc_security_group_ids = [
    aws_security_group.database_security_group.id
  ]
}
resource "aws_autoscaling_policy" "upautoscaling_policy" {
  name                   = "upautoscaling_policy"
  scaling_adjustment     = 1
  adjustment_type        = "PercentChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.autoscaling.name
}

resource "aws_cloudwatch_metric_alarm" "scaleuppolicyalarm" {
  alarm_name          = "scaleuppolicyalarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 5

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.autoscaling.name
  }

  alarm_description = "ec2 cpu utilization monitoring"
  alarm_actions     = [aws_autoscaling_policy.upautoscaling_policy.arn]
}

resource "aws_autoscaling_policy" "downautoscaling_policy" {
  name                   = "downautoscaling_policy"
  scaling_adjustment     = -1
  adjustment_type        = "PercentChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.autoscaling.name
}
resource "aws_cloudwatch_metric_alarm" "scaledownpolicyalarm" {
  alarm_name          = "scaledownpolicyalarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 3

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.autoscaling.name
  }

  alarm_description = "ec2 cpu utilization monitoring"
  alarm_actions     = [aws_autoscaling_policy.downautoscaling_policy.arn]
}

resource "aws_autoscaling_group" "autoscaling" {

  name                      = "csye6225-asg-spring2023"
  vpc_zone_identifier       = [aws_subnet.public_subnets[0].id, aws_subnet.public_subnets[1].id, aws_subnet.public_subnets[2].id ]
  max_size                  = 3
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "EC2"
  force_delete              = true
  default_cooldown          = 60

  launch_template {
    id      = aws_launch_template.lt.id
    version = aws_launch_template.lt.latest_version
  }
  target_group_arns = [aws_lb_target_group.target_group.arn]
  tag {
    key                 = "Key"
    value               = "Value"
    propagate_at_launch = true
  }

}

resource "aws_launch_template" "lt" {
  name                    = "asg_launch_config"
  image_id                = var.ami_id
  instance_type           = var.instance_type
  key_name                = var.key_name
  disable_api_termination = false


  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.instance.id]
    subnet_id                   = aws_subnet.public_subnets[1].id
  }

  user_data = base64encode(templatefile("userdata.sh", {
    DB_HOST        = "${aws_db_instance.rds_instance.endpoint}"
    DB_USER        = "${aws_db_instance.rds_instance.username}"
    DB_PASSWORD    = "${aws_db_instance.rds_instance.password}"
    S3_BUCKET_NAME = "${aws_s3_bucket.private_s3_bucket.bucket}"
  }))


  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }



  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      delete_on_termination = true
      volume_size           = 50
      volume_type           = "gp2"
    }
  }
  tags = {
    Name = "Terraform_Managed_Custom_AMI_Instance"
  }
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
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
      },
      {
        "Sid" : "AssumeAutoScalingRole",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "autoscaling.amazonaws.com"
        },
        "Action" : "sts:AssumeRole",
        "Condition" : {}
      }
    ]
  })

  tags = {
    Name = "EC2-CSYE6225-Role"
  }
}

data "aws_region" "current" {}

resource "aws_iam_role_policy_attachment" "webapp_s3_policy_attachment" {
  policy_arn = aws_iam_policy.webapp_s3_policy.arn
  role       = aws_iam_role.ec2_csye6225_role.name
}


resource "aws_iam_role_policy_attachment" "cloudwatch_agent_policy_attachment" {
  //  name       = "cloudwatch_policy_attachment"
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.ec2_csye6225_role.name
}



resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "EC2-CSYE6225-Instance-Profile"

  role = aws_iam_role.ec2_csye6225_role.name
}


data "aws_route53_zone" "zone" {
  name = "${var.profile}.abhinavpalem.me"
}

resource "aws_route53_record" "main" {
  zone_id = data.aws_route53_zone.zone.id
  name    = "${var.profile}.abhinavpalem.me"
  type    = "A"

  alias {
    name                   = aws_lb.load_balancer.dns_name
    zone_id                = aws_lb.load_balancer.zone_id
    evaluate_target_health = true

  }

  # Ensure the A record is created before the EC2 instance
}

resource "aws_cloudwatch_log_group" "csye6225" {
  name = "csye6225"
  
}