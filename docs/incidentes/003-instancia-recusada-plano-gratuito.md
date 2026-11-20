# 003 - Instância EC2 recusada pelo plano gratuito

- **Data:** 2026-11-20
- **Ambiente:** AWS, primeiro `tofu apply` do ambiente
- **Impacto:** `apply` parcial (12 de 13 recursos criados; a VM falhou)
- **Duração:** ~10 minutos

## Resumo

A instância `t3.large` foi recusada pela AWS porque a conta está no plano
gratuito, que só permite tipos de instância elegíveis. Um dry-run feito antes
havia indicado que a criação seria aceita.

## Linha do tempo

*Horários aproximados, reconstruídos a partir dos registros da sessão.*

| Hora | Evento |
|---|---|
| (antes) | `aws ec2 run-instances --dry-run --instance-type t3.large` → `DryRunOperation` (aceito) |
| 09:35 | `tofu apply`: rede, security group e key pair criados; a instância falha |
| 09:36 | Consulta dos tipos elegíveis no plano gratuito |
| 09:44 | Troca para `m7i-flex.large` (commit `feac752`); `plan` mostra `1 to add` |
| 09:46 | `apply` conclui; VM criada em 17 segundos |

## Sintomas

```
InvalidParameterCombination: The specified instance type is not eligible for Free Tier.
```

## Diagnóstico

```bash
aws ec2 describe-instance-types --region us-east-1 \
  --filters Name=free-tier-eligible,Values=true \
  --query 'InstanceTypes[].[InstanceType, MemoryInfo.SizeInMiB]' --output text
```

O único tipo elegível com 8 GB de RAM é o `m7i-flex.large` (2 vCPU, 8 GB, x86).

## Causa raiz

O plano gratuito da conta restringe os tipos de instância. O dry-run do
`RunInstances` valida permissões e parâmetros, mas **não** aplica a restrição
do plano gratuito, que só é avaliada na criação real.

## Correção

`instance_type = "m7i-flex.large"` em `infra/opentofu/aws/variables.tf`. Os 12
recursos já criados estavam registrados no state, e o `apply` seguinte criou
apenas a instância.

## Prevenção e aprendizados

- Um teste que passa não cobre necessariamente todas as condições do ambiente
  real: o dry-run não substitui a consulta das regras da conta.
- "Free tier eligible" significa permitido no plano gratuito, não gratuito: o
  uso é descontado dos créditos.
- O state do OpenTofu tornou o apply parcial seguro: nada ficou perdido.
- Registrado no ADR 0001.
