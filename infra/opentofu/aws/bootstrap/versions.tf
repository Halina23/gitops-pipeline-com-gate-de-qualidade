terraform {
  # use_lockfile (trava do state no S3) exige OpenTofu 1.10 ou superior.
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.73"
    }
  }
}
