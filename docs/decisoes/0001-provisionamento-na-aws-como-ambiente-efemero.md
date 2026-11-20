# 0001 - Provisionamento na AWS como ambiente efêmero

- **Status:** Aceita
- **Data:** 2026-11-16

## Contexto

O cluster k3s roda numa VM do VirtualBox no notebook de desenvolvimento,
criada pelo OpenTofu por meio de `null_resource` e comandos do PowerShell.
Esse arranjo tem limitações:

- o OpenTofu não conhece a VM de verdade (só executa comandos), então não
  detecta mudanças nem gerencia o ciclo de vida real do recurso;
- a VM disputa RAM e disco com o notebook, que tem poucos recursos;
- o ambiente não é acessível de fora, o que impede demonstrar a plataforma
  "em produção".

Há US$ 120 em créditos da AWS disponíveis até maio de 2027.

## Decisão

Adicionar um segundo ambiente, na AWS, mantendo o local:

- `infra/opentofu/virtualbox/`: a configuração atual, sem mudanças de comportamento.
- `infra/opentofu/aws/`: provider oficial `hashicorp/aws`, criando VPC, subnet
  pública, Internet Gateway, security group, key pair e uma instância EC2.

Escolhas do ambiente AWS:

- **Efêmero:** criado com `tofu apply` para trabalhar ou demonstrar, e apagado
  com `tofu destroy` no fim. Não fica ligado permanentemente.
- **State remoto no S3**, com versionamento, criptografia e trava por arquivo
  (`use_lockfile`). O bucket é criado por uma configuração separada de
  bootstrap (`infra/opentofu/aws/bootstrap/`), aplicada uma única vez.
- **EC2 `m7i-flex.large`** (2 vCPU, 8 GB, x86): roda as imagens amd64 já
  publicadas pelo CI e comporta k3s, Argo CD, OpenBao e as aplicações. A conta
  está no plano gratuito, que só permite tipos elegíveis
  (`free-tier-eligible=true`); o `t3.large`, escolhido inicialmente, foi
  recusado. O dry-run do `RunInstances` não detecta essa restrição: a consulta
  correta é `aws ec2 describe-instance-types --filters Name=free-tier-eligible,Values=true`.
- **Rede simples:** subnet pública, **sem NAT Gateway** (custo fixo alto mesmo
  ocioso). O security group libera SSH (22) e a API do Kubernetes (6443)
  apenas para o IP de quem administra, e HTTP/HTTPS (80/443) para todos.
- **Imagem do sistema** obtida do parâmetro público da Canonical no SSM
  (Ubuntu 24.04 mais recente), sem ID fixo no código.
- Região `us-east-1`, a de menor custo para uma demonstração.

## Consequências

- O OpenTofu passa a gerenciar recursos reais, com `plan` mostrando
  exatamente o que vai mudar.
- O notebook deixa de hospedar o cluster no fluxo principal.
- O ambiente pode ser recriado do zero em poucos minutos, o que também
  serve de teste da automação.
- Custo proporcional ao uso (cerca de US$ 0,08 por hora com a instância
  ligada). Um orçamento da AWS alerta sobre qualquer gasto real.
- Esquecer o `tofu destroy` gera custo: é o principal risco operacional.
- O runner self-hosted do CI continua dependendo da VM local; a mudança do
  CI fica para uma decisão futura.
