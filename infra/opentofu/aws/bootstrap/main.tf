# Bootstrap: cria o bucket S3 que guarda o state do ambiente AWS.
# Roda uma única vez. O state DESTA configuração fica local (fora do Git).

data "aws_caller_identity" "current" {}

locals {
  # Nomes de bucket são únicos no mundo todo; o ID da conta garante a unicidade.
  bucket_name = "gitops-tfstate-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "tfstate" {
  bucket = local.bucket_name

  # Trava de segurança: um "tofu destroy" por engano não apaga o histórico do state.
  lifecycle {
    prevent_destroy = true
  }
}

# Cada escrita do state vira uma nova versão: dá para voltar a uma anterior.
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Criptografia no disco (o state pode conter IPs, IDs e dados sensíveis).
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# O bucket nunca pode ficar público, nem por engano.
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Apaga versões antigas depois de um tempo, para o bucket não crescer sem limite.
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "expira-versoes-antigas"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days           = var.noncurrent_version_retention_days
      newer_noncurrent_versions = 10
    }
  }

  depends_on = [aws_s3_bucket_versioning.tfstate]
}

# Recusa qualquer acesso que não use HTTPS.
data "aws_iam_policy_document" "tls_only" {
  statement {
    sid     = "NegaAcessoSemTLS"
    effect  = "Deny"
    actions = ["s3:*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = [
      aws_s3_bucket.tfstate.arn,
      "${aws_s3_bucket.tfstate.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "tls_only" {
  bucket = aws_s3_bucket.tfstate.id
  policy = data.aws_iam_policy_document.tls_only.json

  # Aplica o bloqueio de acesso público antes de qualquer política.
  depends_on = [aws_s3_bucket_public_access_block.tfstate]
}
