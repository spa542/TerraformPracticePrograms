output "public_ip" {
  description = "IP Addres of server built with Server Module"
  value       = aws_instance.web.public_ip
}

output "public_dns" {
  description = "DNS of server build with Server Module"
  value       = aws_instance.web.public_dns
}

output "size" {
  description = "Size of server built with Server Module"
  value       = aws_instance.web.instance_type
}