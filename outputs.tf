output "rds_hostname" {
  description = "RDS instance hostname"
  value       = aws_db_instance.mydb1.address
  sensitive   = false
}

#output "aws_instance" {
#  description = "EC2 Public Ip"
#  value       = aws_instance.webapp.public_ip
#  sensitive   = false
#}

output "load_balancer_dns" {
  value     = aws_lb.webapp_lb.dns_name
  sensitive = false
}