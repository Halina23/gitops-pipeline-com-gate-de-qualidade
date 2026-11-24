variable "region" {
  description = "Região da AWS onde fica o bucket do state"
  type        = string
  default     = "us-east-1"
}

variable "budget_uso_mensal_usd" {
  description = "Teto mensal de uso bruto (antes dos créditos), em dólares, do budget uso-dos-creditos"
  type        = string
  default     = "10.0"
}

variable "noncurrent_version_retention_days" {
  description = "Por quantos dias guardar as versões antigas do state"
  type        = number
  default     = 90
}
