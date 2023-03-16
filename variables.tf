
variable "aws_profile" {
  type = string
}

variable "region" {
  type = string
}

variable "cidr_block" {
  type = string
}

variable "public_subnet" {
  type = number
}

variable "private_subnet" {
  type = number
}

variable "public_availability_zones" {
  type = number
}

variable "private_availability_zones" {
  type = number
}

variable "vpc_id" {
  type = number
}

variable "db_password" {
  type      = string
  sensitive = true
}
variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "server_port" {
  type = string
}

variable "time_zone" {
  type = string
}
variable "domain_name" {
  type = string
}