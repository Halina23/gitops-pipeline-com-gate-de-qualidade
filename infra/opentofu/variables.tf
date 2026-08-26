variable "vm_name" {
  description = "Nome da VM no VirtualBox"
  type        = string
  default     = "gitops-k3s-node"
}

variable "vm_cpus" {
  description = "Quantidade de vCPUs"
  type        = number
  default     = 2
}

variable "vm_memory_mb" {
  description = "Memória RAM alocada, em MB"
  type        = number
  default     = 4096
}

variable "vagrant_box_url" {
  description = "URL direta da Vagrant box (bento/ubuntu-24.04, provider virtualbox)"
  type        = string
  default     = "https://vagrantcloud.com/bento/boxes/ubuntu-24.04/versions/202510.26.0/providers/virtualbox/amd64/vagrant.box"
}

variable "hostonly_adapter_name" {
  description = "Nome do adaptador host-only já existente no VirtualBox"
  type        = string
  default     = "VirtualBox Host-Only Ethernet Adapter"
}

variable "vm_static_ip" {
  description = "IP fixo da VM na rede host-only"
  type        = string
  default     = "192.168.56.102"
}