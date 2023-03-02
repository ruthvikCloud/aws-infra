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
    description = "TLS from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

  ingress {
    description = "TLS from VPC"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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


resource "aws_instance" "webapp" {
  ami                         = data.aws_ami.amzLinux.id #"ami-0dfcb1ef8550277af"
  instance_type               = "t2.micro"
  disable_api_termination     = true
  associate_public_ip_address = true
  key_name                    = "ec2-ssh"
  security_groups = [
    aws_security_group.application.id
  ]

  source_dest_check = true

  subnet_id = aws_subnet.public_subnet[0].id
  tags = {
    "Name" = "MyWebappServer"
  }

  tenancy = "default"

  vpc_security_group_ids = [
    aws_security_group.application.id
  ]

  lifecycle {
    prevent_destroy = false
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "optional"
  }

  root_block_device {
    delete_on_termination = true
    volume_size           = 50
    volume_type           = "gp2"
  }
  iam_instance_profile = aws_iam_instance_profile.web_instance_profile.id
  user_data            = templatefile("user_data.sh", { db_host = aws_db_instance.mydb1.address, db_port = aws_db_instance.mydb1.port, db_user = aws_db_instance.mydb1.username, db_pwd = var.db_password, db = aws_db_instance.mydb1.db_name, db_engine = aws_db_instance.mydb1.engine, s3_bucket = aws_s3_bucket.apps_bucket.bucket, s3_region = aws_s3_bucket.apps_bucket.region })

}

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
  identifier              = "mydb1"
  instance_class          = "db.t3.micro"
  multi_az                = false
  db_name                 = var.db_name
  password                = var.db_password
  port                    = 5432
  publicly_accessible     = false
  storage_encrypted       = true # you should always do this
  storage_type            = "gp2"
  username                = var.db_username
  skip_final_snapshot     = true
  apply_immediately       = true
  vpc_security_group_ids  = [aws_security_group.mydb1.id]
  db_subnet_group_name    = aws_db_subnet_group.postgresql_subnet_group.name
}




resource "aws_db_subnet_group" "postgresql_subnet_group" {
  name       = "postgresubgroup"
  subnet_ids = [aws_subnet.private_subnet[0].id, aws_subnet.private_subnet[1].id, aws_subnet.private_subnet[2].id]

  tags = {
    Name = "PostgreSQL subnet group"
  }
}


resource "aws_iam_role" "web_iam_role" {
  name               = "web_iam_role"
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
  role = aws_iam_role.web_iam_role.name
}

resource "aws_iam_role_policy" "web_iam_role_policy" {
  name   = "web_iam_role_policy"
  role   = aws_iam_role.web_iam_role.id
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