# Configure the AWS Provider
provider "aws" {
  region  = var.region
  profile = var.aws_profile
}