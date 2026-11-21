# 005 - Simulação: alerta de ponta a ponta (banco inacessível → e-mail)

- **Data:** 2026-11-20
- **Tipo:** simulação (*game day*), falha provocada de propósito
- **Ambiente:** AWS (efêmero), com Prometheus, Alertmanager e regras do encurtador
- **Impacto observado:** página fora do ar (HTTP 503) por ~2 minutos
- **Detecção:** e-mail de alerta ~2 min 20 s após o início da falha; e-mail de resolução ~5 min após a recuperação

## Objetivo

Validar a cadeia completa de alerta, da falha até a notificação:

```
banco inacessível → readiness falha → 0 pods prontos
  → regra EncurtadorForaDoAr: pending → firing
  → Alertmanager agrupa e envia o e-mail → recuperação → e-mail de resolução
```

## Pré-condições verificadas

- Alertmanager com a configuração de e-mail carregada (SMTP do Gmail, destinos
  `nulo` e `email`, rotas `servico="encurtador"` e `severity="critical"`).
- Prometheus com as 3 regras do grupo `encurtador` avaliadas (`inactive`).
- Nenhum alerta do encurtador ativo antes do teste.

## Como a falha foi provocada

A mesma técnica da [simulação 004](004-simulacao-banco-inacessivel.md): NetworkPolicy
bloqueando a entrada no pod do banco e `pg_terminate_backend` derrubando as conexões
já abertas do pool da aplicação (o filtro de rede é *stateful* e não as interromperia).

## Linha do tempo

Registrada a cada ~15 s. "E-mails" é o contador `alertmanager_notifications_total`
(integração `email`) do próprio Alertmanager; o contador de falhas ficou em 0.

| Hora | Pods prontos | Regra | E-mails | Evento |
|---|---|---|---|---|
| 20:42:24 | 1 | inactive | 0 | Estado inicial |
| 20:42:30 | 1 | inactive | 0 | Banco bloqueado e conexões do pool derrubadas |
| 20:42:58 | **0** | inactive | 0 | Readiness falhou 3 vezes: pod fora do tráfego |
| 20:43:15 | 0 | **pending** | 0 | Condição verdadeira; aguardando o `for: 1m` |
| 20:44:21 | 0 | **firing** | 0 | 1 minuto com 0 pods prontos |
| 20:44:53 | 0 | firing | **1** | E-mail `[FIRING] EncurtadorForaDoAr` enviado |
| 20:44:58 | 0 | firing | 1 | Bloqueio removido |
| 20:45:09 | **1** | firing | 1 | Pod pronto de novo (~10 s) |
| 20:45:59 | 1 | **inactive** | 1 | Regra deixa de disparar |
| 20:49:46 | 1 | inactive | **2** | E-mail `[RESOLVED] EncurtadorForaDoAr` enviado |

Os dois e-mails chegaram ao endereço de destino.

## Conclusões

- **A cadeia de alerta funciona de ponta a ponta**, com 0 falhas de envio.
- **Tempo até a notificação (~2 min 20 s), e de onde ele vem:**
  - ~30 s: readiness (`periodSeconds` 10 × 3 falhas);
  - 1 min: `for: 1m` da regra, que evita alarme falso em falhas passageiras;
  - ~30 s: `group_wait` do Alertmanager, que junta alertas relacionados num e-mail;
  - mais alguns segundos do intervalo de avaliação das regras.
- **A resolução chegou ~4 min depois da recuperação** por causa do
  `group_interval: 5m`: o Alertmanager só envia atualizações de um grupo a cada 5
  minutos. Reduzir esse valor deixaria o aviso de recuperação mais rápido.
- **O alerta mede o que o usuário sente:** `EncurtadorForaDoAr` usa as réplicas
  disponíveis (kube-state-metrics), não só a métrica `up`. Durante a falha a
  aplicação seguia viva e o `/metrics` respondia; um alerta baseado apenas em `up`
  não teria disparado, embora o site estivesse fora do ar.
- **Sem spam:** os alertas genéricos do kube-prometheus-stack foram para o destino
  `nulo`; só o alerta do encurtador gerou e-mail.

## Achado operacional durante a execução

Ao final, o `tofu destroy` falhou porque a sessão do `aws login` (credenciais
temporárias) expirou depois de horas de trabalho. O `make aws-status` exibiu
`Recursos no state: 0` mesmo assim, porque o erro de leitura do state virou zero.
A VM continuou ligada até um novo `aws login`.

**Corrigido:** o `make aws-status` agora falha com uma mensagem clara
("Login expirado? Rode: aws login ...") quando não consegue ler o state ou
consultar a AWS, em vez de mostrar 0. Também passou a contar só os recursos
gerenciados, sem os data sources. Lição: um painel de status que mostra um valor
falso quando a consulta falha é pior do que nenhum painel.
