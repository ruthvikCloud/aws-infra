output "rds_hostname" {
  description = "RDS instance hostname"
  value       = aws_db_instance.mydb1.address
  sensitive   = false
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.mydb1.port
  sensitive   = false
}

output "rds_username" {
  description = "RDS instance root username"
  value       = aws_db_instance.mydb1.username
  sensitive   = false
}

output "ec2_web_public_ip" {
  description = "The Public IP address of the web server"
  value       = aws_eip.ec2_elastic_ip.public_ip
  depends_on  = [aws_eip.ec2_elastic_ip]
}