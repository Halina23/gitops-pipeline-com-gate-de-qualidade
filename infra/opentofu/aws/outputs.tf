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

output "auto_desligar_minutos" {
  description = "Minutos, a partir do boot, até a VM se encerrar sozinha"
  value       = local.auto_desligar_minutos
}

output "admin_cidr" {
  description = "IP atual de quem rodou o tofu"
  value       = local.admin_cidr
}

output "admin_cidrs" {
  description = "Todas as faixas liberadas para SSH e para a API do Kubernetes"
  value       = sort(tolist(local.admin_cidrs))
}
