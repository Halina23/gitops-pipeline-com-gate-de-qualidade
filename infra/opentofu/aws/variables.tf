variable "region" {
  description = "Região da AWS"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefixo dos nomes dos recursos"
  type        = string
  default     = "gitops"
}

variable "vpc_cidr" {
  description = "Faixa de IPs da VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Faixa de IPs da subnet pública"
  type        = string
  default     = "10.20.1.0/24"
}

variable "instance_type" {
  # Precisa ser elegível ao plano gratuito da conta (free-tier-eligible=true).
  description = "Tipo da instância EC2 (m7i-flex.large: 2 vCPU, 8 GB)"
  type        = string
  default     = "m7i-flex.large"
}

variable "root_volume_size_gb" {
  description = "Tamanho do disco da VM, em GB"
  type        = number
  default     = 30
}

variable "auto_desligar_horas" {
  description = <<-EOT
    Horas até a VM se encerrar sozinha (contadas a partir do boot). Proteção
    contra ambiente esquecido ligado (incidente 007). "make aws-prorrogar"
    recomeça a contagem. Aceita frações para testes (ex.: 0.17 = 10 minutos).
  EOT
  type        = number
  default     = 4

  validation {
    condition     = var.auto_desligar_horas >= 0.1 && var.auto_desligar_horas <= 24
    error_message = "auto_desligar_horas precisa estar entre 0.1 (6 minutos) e 24."
  }
}

variable "ssh_public_key_path" {
  description = "Chave SSH pública colocada na VM"
  type        = string
  default     = "~/.ssh/id_ed25519_aws_lab.pub"
}

variable "admin_cidr" {
  description = <<-EOT
    IP (em CIDR, ex.: 203.0.113.10/32) liberado para SSH e para a API do Kubernetes.
    Se ficar vazio, usa o IP público atual de quem roda o tofu.
  EOT
  type        = string
  default     = ""
}

variable "admin_cidrs_extras" {
  description = <<-EOT
    Faixas extras liberadas para SSH e para a API do Kubernetes (ex.: as faixas que a
    operadora alterna). Vêm de ~/.config/gitops-lab/admin-cidrs.txt pelo Makefile
    (TF_VAR_admin_cidrs_extras), fora do Git.
  EOT
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.admin_cidrs_extras : can(cidrhost(c, 0))])
    error_message = "Cada item de admin_cidrs_extras precisa ser um CIDR IPv4 válido (ex.: 203.0.113.0/24)."
  }
}
