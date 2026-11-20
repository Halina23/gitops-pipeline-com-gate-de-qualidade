# As credenciais vêm do perfil do AWS CLI: export AWS_PROFILE=lab
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "gitops-pipeline"
      ManagedBy   = "opentofu"
      Environment = "aws-efemero"
    }
  }
}
