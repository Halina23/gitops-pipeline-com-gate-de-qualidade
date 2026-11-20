variable "region" {
  description = "Região da AWS onde fica o bucket do state"
  type        = string
  default     = "us-east-1"
}

variable "noncurrent_version_retention_days" {
  description = "Por quantos dias guardar as versões antigas do state"
  type        = number
  default     = 90
}
