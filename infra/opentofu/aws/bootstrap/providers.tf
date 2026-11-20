# As credenciais NÃO ficam no código: vêm do perfil do AWS CLI.
# Antes de rodar: export AWS_PROFILE=lab  (e, se expirou, aws login --profile lab --remote)
provider "aws" {
  region = var.region

  # Tags aplicadas automaticamente em todos os recursos criados por esta configuração.
  default_tags {
    tags = {
      Project   = "gitops-pipeline"
      ManagedBy = "opentofu"
      Component = "tfstate-bootstrap"
    }
  }
}
