# Alerta de consumo dos créditos (incidente 007).
#
# O budget "alerta-gasto-zero" (criado no console) mede o custo LÍQUIDO: uso menos
# créditos. Ele avisa se alguma cobrança vai para o cartão, mas fica em zero
# enquanto os créditos cobrem tudo, e por isso não avisou do ambiente esquecido
# ligado. Este mede o uso BRUTO (só RECORD_TYPE = Usage, antes dos créditos):
# quanto dos créditos está sendo consumido.
#
# Criado primeiro pela AWS CLI (aws budgets create-budget) e trazido para o código
# com o bloco "import" abaixo. Fica no bootstrap porque é da conta e permanente:
# o "make aws-down" não o afeta.

locals {
  # O e-mail vem do arquivo local dos alertas (fora do Git), o mesmo do Alertmanager.
  alertas            = yamldecode(file(pathexpand("~/.config/gitops-lab/alertas.yml")))
  email_destinatario = local.alertas.email_destinatario

  # Avisos: metade do teto, teto atingido e previsão de passar do teto no mês.
  avisos_budget = [
    { tipo = "ACTUAL", percentual = 50 },
    { tipo = "ACTUAL", percentual = 100 },
    { tipo = "FORECASTED", percentual = 100 },
  ]
}

resource "aws_budgets_budget" "uso_dos_creditos" {
  name         = "uso-dos-creditos"
  budget_type  = "COST"
  time_unit    = "MONTHLY"
  limit_amount = var.budget_uso_mensal_usd
  limit_unit   = "USD"

  # Custo pelo preço normal de cada uso (o padrão dos budgets de custo). O provedor
  # exige que ele seja explícito quando há filter_expression.
  metrics = ["UnblendedCost"]

  # Só as linhas de uso da fatura (sem Credit, Refund etc.): o valor bruto.
  filter_expression {
    dimensions {
      key    = "RECORD_TYPE"
      values = ["Usage"]
    }
  }

  dynamic "notification" {
    for_each = local.avisos_budget
    content {
      notification_type          = notification.value.tipo
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value.percentual
      threshold_type             = "PERCENTAGE"
      subscriber_email_addresses = [local.email_destinatario]
    }
  }
}

# Adota o budget que já existe na AWS em vez de criar outro. Formato do ID:
# <conta>:<nome>. Depois do primeiro apply este bloco não faz mais nada.
import {
  to = aws_budgets_budget.uso_dos_creditos
  id = "${data.aws_caller_identity.current.account_id}:uso-dos-creditos"
}
