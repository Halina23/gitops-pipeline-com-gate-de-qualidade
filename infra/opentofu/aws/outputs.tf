output "public_ip" {
  description = "IP público da VM"
  value       = aws_instance.k3s_node.public_ip
}

output "instance_id" {
  description = "ID da instância EC2"
  value       = aws_instance.k3s_node.id
}

output "ssh_command" {
  description = "Comando para entrar na VM"
  value       = "ssh -i ~/.ssh/id_ed25519_aws_lab ubuntu@${aws_instance.k3s_node.public_ip}"
}

output "admin_cidr" {
  description = "IP liberado para SSH e para a API do Kubernetes"
  value       = local.admin_cidr
}
