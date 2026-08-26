output "vm_ip_address" {
  description = "IP fixo da VM na rede host-only"
  value       = var.vm_static_ip
}

output "vm_name" {
  description = "Nome da VM no VirtualBox"
  value       = var.vm_name
}