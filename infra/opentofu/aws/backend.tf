# O state deste ambiente fica no bucket criado por ./bootstrap.
# Valores fixos: o bloco backend não aceita variáveis.
terraform {
  backend "s3" {
    bucket       = "gitops-tfstate-047616383265"
    key          = "aws/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # trava: impede dois apply ao mesmo tempo
  }
}
