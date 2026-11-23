# 007 - Ambiente efêmero esquecido ligado por ~42 horas

- **Data:** 2026-11-21 a 2026-11-23
- **Tipo:** real (custo)
- **Ambiente:** AWS (efêmero)
- **Impacto:** ~42 horas de VM, disco e IP público ligados sem uso. Estimativa
  de US$ 4 a 5, pagos com os créditos da conta. Nenhuma cobrança real, nenhum
  dado perdido.

## Resumo

O ambiente é efêmero por decisão de projeto
([ADR 0001](../decisoes/0001-provisionamento-na-aws-como-ambiente-efemero.md)):
ele sobe no começo da sessão e é destruído no fim, com `make aws-down`. Numa
sessão para testar os traces (OpenTelemetry + Tempo), a subida foi interrompida
enquanto o Argo CD terminava de sincronizar. A sessão só foi retomada dois dias
depois, e o ambiente continuava ligado.

## Linha do tempo

| Quando | O que aconteceu |
|---|---|
| 21/11 | `tofu apply` (17 recursos), bootstrap, k3s e Argo CD concluídos sem falhas |
| 21/11 | Sessão interrompida durante a espera pelo sync das Applications. Nenhum `destroy` foi feito |
| 23/11 | Sessão retomada. `make aws-status` falhou com login expirado, então o estado da AWS não podia ser lido |
| 23/11 | `kubectl get nodes` (que não depende do login da AWS) mostrou o nó `Ready` com **42h** de idade |
| 23/11 | O ambiente ligado foi usado para validar os traces e depois destruído (`Destroy complete! Resources: 17 destroyed`) |
| 23/11 | Conferência direta na AWS: 0 instâncias, 0 volumes EBS, 0 IPs elásticos |

## Por que nada avisou

- **O alerta de orçamento não dispara com créditos.** O budget `alerta-gasto-zero`
  (US$ 1) exclui os créditos de propósito: ele existe para avisar sobre cobrança
  real no cartão. Como os créditos cobriram tudo, o custo líquido continuou zero.
- **O login expirado escondeu o estado.** Ao retomar, a primeira consulta à AWS
  falhou. Graças à correção do `aws-status` (que falha com mensagem clara em vez
  de mostrar "0 instâncias"), o erro não passou despercebido como "nada ligado".
- **O desligamento depende de uma pessoa lembrar.** Nada no ambiente se desliga
  sozinho.

## Causa raiz

O ciclo do ambiente efêmero dependia só de disciplina: o `destroy` é um passo
manual no fim da sessão, e uma sessão interrompida pula esse passo. Não havia
nenhuma proteção automática por tempo nem por uso dos créditos.

## Correção

Ambiente destruído e conferido diretamente na AWS. Custo verificado no Cost
Explorer: US$ 3,28 de uso bruto até 23/11, de US$ 120 em créditos (o Cost
Explorer atualiza com até 24h de atraso, então o total final fica um pouco acima).

## Prevenção e aprendizados

- **Feito:** ao retomar qualquer sessão, o primeiro passo é conferir o ambiente
  (`make aws-status`; se o login expirou, `kubectl get nodes` com o kubeconfig da
  AWS) e destruí-lo se não estiver em uso.
- **Proposto:** desligamento automático da VM depois de algumas horas (ex.:
  `shutdown -h +240` agendado na inicialização, com
  `instance_initiated_shutdown_behavior = "stop"`). Uma VM parada não cobra CPU
  nem IP público; só o disco continua sendo cobrado, em centavos.
- **Proposto:** um segundo budget que conte o uso **bruto** (antes dos créditos),
  com aviso por e-mail a partir de ~US$ 10 no mês. Assim o consumo dos créditos
  também fica visível.
- **Aprendizado:** um alerta que exclui créditos protege o cartão, mas não os
  créditos. Cada alerta responde a uma pergunta diferente, e "quanto estou
  consumindo?" precisava do seu próprio alerta.
