output "state_bucket" {
  description = "Bucket S3 do state (usado no backend do ambiente AWS)"
  value       = aws_s3_bucket.tfstate.bucket
}

output "region" {
  description = "Região do bucket"
  value       = var.region
}
