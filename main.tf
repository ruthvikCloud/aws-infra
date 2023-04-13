# creating VPC
resource "aws_vpc" "vpc" {
  cidr_block = var.cidr_block

  tags = {
    Name = "VPC ${var.vpc_id}"
  }
}

data "aws_availability_zones" "all" {
  state = "available"
}

# Creating public subnet
resource "aws_subnet" "public_subnet" {
  count             = var.public_subnet
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(var.cidr_block, 8, count.index)
  availability_zone = element(data.aws_availability_zones.all.names, count.index % length(data.aws_availability_zones.all.names))

  tags = {
    Name = "Public subnet ${count.index + 1} - VPC ${var.vpc_id}"
  }
}

resource "aws_subnet" "private_subnet" {
  count             = var.private_subnet
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(var.cidr_block, 4, count.index + 1)
  availability_zone = element(data.aws_availability_zones.all.names, count.index % length(data.aws_availability_zones.all.names))

  tags = {
    Name = "Private subnet ${count.index + 1}"
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "Internet gateway"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name = "Public route table"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "Private route table"
  }
}

resource "aws_route_table_association" "aws_public_route_table_association" {
  count          = var.public_subnet
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "aws_private_route_table_association" {
  count          = var.private_subnet
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_security_group" "application" {
  name        = "application"
  description = "Allow TLS inbound/outbound traffic"
  vpc_id      = aws_vpc.vpc.id


  ingress {
    description     = "TLS from VPC"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.load_balancer_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

data "aws_ami" "amzLinux" {
  most_recent = true
  filter {
    name   = "name"
    values = ["csye6225*"]
  }
}


#resource "aws_instance" "webapp" {
#  ami                         = data.aws_ami.amzLinux.id #"ami-0dfcb1ef8550277af"
#  instance_type               = "t2.micro"
#  disable_api_termination     = true
#  associate_public_ip_address = true
#  key_name                    = "ec2-ssh"
#  security_groups = [
#    aws_security_group.application.id
#  ]
#
#  source_dest_check = true
#
#  subnet_id = aws_subnet.public_subnet[0].id
#  tags = {
#    "Name" = "MyWebappServer"
#  }
#
#  tenancy = "default"
#
#  vpc_security_group_ids = [
#    aws_security_group.application.id
#  ]
#
#  lifecycle {
#    prevent_destroy = false
#  }
#
#  metadata_options {
#    http_endpoint               = "enabled"
#    http_put_response_hop_limit = 1
#    http_tokens                 = "optional"
#  }
#
#  root_block_device {
#    delete_on_termination = true
#    volume_size           = 50
#    volume_type           = "gp2"
#  }
#  iam_instance_profile = aws_iam_instance_profile.web_instance_profile.id
#  user_data            = templatefile("user_data.sh", { db_host = aws_db_instance.mydb1.address, db_port = aws_db_instance.mydb1.port, db_user = aws_db_instance.mydb1.username, db_pwd = var.db_password, db = aws_db_instance.mydb1.db_name, db_engine = aws_db_instance.mydb1.engine, s3_bucket = aws_s3_bucket.apps_bucket.bucket, s3_region = aws_s3_bucket.apps_bucket.region })
#
#}

resource "aws_security_group" "mydb1" {
  name        = "mydb1"
  vpc_id      = aws_vpc.vpc.id
  description = "RDS postgres servers (terraform-managed)"


  # Only postgres in
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.application.id]
  }

  # Allow all outbound traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "mydb1" {
  allocated_storage       = 20 # gigabytes
  backup_retention_period = 0  # in days
  engine                  = "postgres"
  engine_version          = "14.6"
  identifier              = var.db_username

  instance_class         = "db.t3.micro"
  multi_az               = false
  db_name                = var.db_name
  password               = var.db_password
  port                   = 5432
  publicly_accessible    = false
  storage_encrypted      = true # you should always do this
  storage_type           = "gp2"
  username               = var.db_username
  skip_final_snapshot    = true
  apply_immediately      = true
  vpc_security_group_ids = [aws_security_group.mydb1.id]
  db_subnet_group_name   = aws_db_subnet_group.postgresql_subnet_group.name
  kms_key_id             = aws_kms_key.rdsKey.arn
}




resource "aws_db_subnet_group" "postgresql_subnet_group" {
  name       = "postgresubgroup"
  subnet_ids = [aws_subnet.private_subnet[0].id, aws_subnet.private_subnet[1].id, aws_subnet.private_subnet[2].id]

  tags = {
    Name = "PostgresSQL subnet group"
  }
}


resource "aws_iam_role" "EC2-CSYE6225" {
  name = "EC2-CSYE6225"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}


resource "aws_iam_instance_profile" "web_instance_profile" {
  name = "web_instance_profile"
  role = aws_iam_role.EC2-CSYE6225.name
}

resource "aws_iam_role_policy" "WebAppS3" {
  name   = "WebAppS3"
  role   = aws_iam_role.EC2-CSYE6225.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": ["${aws_s3_bucket.apps_bucket.arn}"]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": ["${aws_s3_bucket.apps_bucket.arn}/*"]
    }
  ]
}
EOF
}

resource "aws_s3_bucket" "apps_bucket" {
  bucket        = "bucket${formatdate("YYYYMMDDhhmmss", timestamp())}"
  force_destroy = true


  tags = {
    Name = "ruthviktestbucket"
  }
}
resource "aws_s3_bucket_lifecycle_configuration" "bucket_life_cycle" {
  bucket = aws_s3_bucket.apps_bucket.bucket
  rule {
    id     = "log"
    status = "Enabled"
    transition {
      storage_class = "STANDARD_IA"
      days          = 30
    }
  }
}

data "aws_route53_zone" "hosted_zone" {
  name = "prod.${var.domain_name}"
}

resource "aws_route53_record" "profile_record" {
  zone_id = data.aws_route53_zone.hosted_zone.id
  name    = "prod.${var.domain_name}"
  type    = "A"

  alias {
    evaluate_target_health = true
    name                   = aws_lb.webapp_lb.dns_name
    zone_id                = aws_lb.webapp_lb.zone_id
  }

}


resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.EC2-CSYE6225.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_security_group" "load_balancer_sg" {

  name        = "load_balancer_sg"
  description = "Allow TLS inbound/outbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "TLS from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "webapp_target" {
  name     = "webapptarget"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id
  health_check {
    path     = "/healthz"
    interval = 30
  }
}
#
#resource "aws_lb_target_group_attachment" "webapp_att1" {
#  target_group_arn = aws_lb_target_group.webapp_target.arn
#  target_id        = aws_instance.webapp.id
#  port             = 3000
#}
#
resource "aws_lb" "webapp_lb" {
  name                       = "webapplb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.load_balancer_sg.id]
  subnets                    = [aws_subnet.public_subnet[0].id, aws_subnet.public_subnet[1].id, aws_subnet.public_subnet[2].id]
  enable_deletion_protection = false
}
#
resource "aws_lb_listener" "webapp_listner" {
  load_balancer_arn = aws_lb.webapp_lb.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = data.aws_acm_certificate.ssl_certificate.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webapp_target.arn
  }
}


resource "aws_launch_template" "webapp_template" {
  name          = "webapp_launch_template"
  image_id      = data.aws_ami.amzLinux.id
  instance_type = "t2.micro"
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 8
      volume_type           = "gp2"
      delete_on_termination = true
      encrypted             = true
      kms_key_id            = aws_kms_key.ebsKey.arn
    }

  }
  #  vpc_security_group_ids = [aws_security_group.application.id]
  network_interfaces {
    associate_public_ip_address = true
    device_index                = 0
    security_groups             = [aws_security_group.application.id]
    subnet_id                   = aws_subnet.public_subnet[0].id
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.web_instance_profile.name
    #    arn  = aws_iam_instance_profile.web_instance_profile.arn
  }
  user_data = base64encode(templatefile("user_data.sh", { db_host = aws_db_instance.mydb1.address, db_port = aws_db_instance.mydb1.port, db_user = aws_db_instance.mydb1.username, db_pwd = var.db_password, db = aws_db_instance.mydb1.db_name, db_engine = aws_db_instance.mydb1.engine, s3_bucket = aws_s3_bucket.apps_bucket.bucket, s3_region = aws_s3_bucket.apps_bucket.region }))
  lifecycle {
    prevent_destroy = false
  }

}
resource "aws_autoscaling_group" "webapp_autoScaling_grp" {
  name             = "webapp_autoScaling_grp"
  min_size         = 1
  max_size         = 3
  default_cooldown = 60
  launch_template {
    version = "$Latest"
    #    id      = aws_launch_template.webapp_template.id
    name = aws_launch_template.webapp_template.name
  }
  target_group_arns = [aws_lb_target_group.webapp_target.arn]
  #  availability_zones =  [aws_subnet.public_subnet[0].availability_zone]
  vpc_zone_identifier = [aws_subnet.public_subnet[0].id]
}

resource "aws_autoscaling_attachment" "webapp_autoScaling_attachment" {
  autoscaling_group_name = aws_autoscaling_group.webapp_autoScaling_grp.name
  lb_target_group_arn    = aws_lb_target_group.webapp_target.arn
}

resource "aws_cloudwatch_metric_alarm" "high_cpu_alarm" {
  alarm_name          = "high-cpu-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 2.5
  alarm_description   = "This metric checks if CPU usage is higher than 2.5% for the past 2 minutes"
  alarm_actions       = [aws_autoscaling_policy.scale_up_policy.arn]
  actions_enabled     = true
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.webapp_autoScaling_grp.name
  }
}
resource "aws_cloudwatch_metric_alarm" "low_cpu_alarm" {
  alarm_name          = "low-cpu-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "This metric checks if CPU usage is lower than 1% for the past 2 minutes"
  alarm_actions       = [aws_autoscaling_policy.scale_down_policy.arn]
  actions_enabled     = true
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.webapp_autoScaling_grp.name
  }
}

resource "aws_autoscaling_policy" "scale_up_policy" {
  name                   = "scale-up-policy"
  policy_type            = "SimpleScaling"
  autoscaling_group_name = aws_autoscaling_group.webapp_autoScaling_grp.name
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
}
resource "aws_autoscaling_policy" "scale_down_policy" {
  name                   = "scale_down_policy"
  policy_type            = "SimpleScaling"
  autoscaling_group_name = aws_autoscaling_group.webapp_autoScaling_grp.name
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
}

resource "aws_cloudwatch_log_group" "csye6225_log_group" {
  name = "csye6225"
}

resource "aws_cloudwatch_log_stream" "csye6225_log_stream" {
  log_group_name = aws_cloudwatch_log_group.csye6225_log_group.name
  name           = "webapp"
}

data "aws_acm_certificate" "ssl_certificate" {
  domain   = "prod.${var.domain_name}"
  types    = ["IMPORTED"]
  statuses = ["ISSUED"]
}

resource "aws_kms_key" "ebsKey" {
  description             = "Symmetric customer-managed KMS key for EBS"
  deletion_window_in_days = 10
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Sid" : "Enable IAM User Permissions",
      "Effect" : "Allow",
      "Principal" : {
        "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      },
      "Action" : "kms:*",
      "Resource" : "*"
      },
      {
        "Sid" : "Allow service-linked role use of the customer managed key",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
          ]
        },
        "Action" : [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "Allow attachment of persistent resources",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
          ]
        },
        "Action" : [
          "kms:CreateGrant"
        ],
        "Resource" : "*",
        "Condition" : {
          "Bool" : {
            "kms:GrantIsForAWSResource" : true
          }
        }
      }
    ] }
  )
}

resource "aws_kms_key" "rdsKey" {
  description             = "Symmetric customer-managed KMS key for EBS"
  deletion_window_in_days = 10
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Sid" : "Enable IAM User Permissions",
      "Effect" : "Allow",
      "Principal" : {
        "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      },
      "Action" : "kms:*",
      "Resource" : "*"
      },
      {
        "Sid" : "Allow service-linked role use of the customer managed key",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
          ]
        },
        "Action" : [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "Allow attachment of persistent resources",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
          ]
        },
        "Action" : [
          "kms:CreateGrant"
        ],
        "Resource" : "*",
        "Condition" : {
          "Bool" : {
            "kms:GrantIsForAWSResource" : true
          }
        }
      }
    ] }
  )
}

data "aws_caller_identity" "current" {}


















