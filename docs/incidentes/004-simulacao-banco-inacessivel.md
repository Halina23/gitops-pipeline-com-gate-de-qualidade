# 004 - Simulação: banco de dados inacessível

- **Data:** 2026-11-20
- **Tipo:** simulação (*game day*), falha provocada de propósito
- **Ambiente:** AWS (efêmero)
- **Impacto observado:** página fora do ar (HTTP 503) por ~70 segundos
- **Recuperação:** automática, em menos de 10 segundos após o fim da falha

## Objetivo

Validar o comportamento esperado das probes quando o banco fica inacessível:

- **readiness** (`/ready`, testa o banco) deve tirar o pod do tráfego;
- **liveness** (`/health`, não depende do banco) deve manter o pod vivo, sem
  reinícios em série;
- a recuperação deve ser automática quando o banco voltar.

## Como a falha foi provocada

Uma NetworkPolicy que bloqueia toda entrada no pod do banco. O Postgres segue
rodando, mas fica inacessível. Como a política não está no Git, o Argo CD não a
gerencia e não a remove (diferente de apagar o banco, que o `selfHeal` restauraria).

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: simulacao-bloqueia-banco
  namespace: encurtador
spec:
  podSelector:
    matchLabels:
      app: encurtador-db
  policyTypes: ["Ingress"]
  ingress: []
```

## Rodada 1: resultado inesperado

Com o bloqueio aplicado por 3 minutos, **nada mudou**: a página respondeu 200
o tempo todo e o `/ready` de dentro do pod informava `database: ok`.

**Hipótese:** o filtro de rede do k3s é *stateful* (iptables com conntrack):
bloqueia conexões novas, mas mantém as já estabelecidas. A aplicação usa um
pool de conexões e continuou reaproveitando conexões abertas antes do bloqueio.

## Rodada 2: validação da hipótese e da simulação

| Hora | Evento |
|---|---|
| antes | Conexão TCP **nova** da aplicação até o banco: OK |
| 19:16:20 | Bloqueio aplicado; conexão **nova**: `ConnectionRefusedError` (o bloqueio funciona) |
| 19:16:25 | `pg_terminate_backend` derruba as 2 conexões do pool da aplicação |
| 19:16:35–49 | Página ainda 200 (a readiness precisa falhar 3 vezes seguidas, a cada 10 s) |
| 19:16:56 | Página **503**; pod `ready=false`; endpoint removido do Service |
| 19:18:05 | De dentro do pod: `/health` → 200, `/ready` → 503; **0 reinícios** |
| 19:18:09 | Bloqueio removido |
| 19:18:18 | Página **200**; pod `ready=true`; endpoint de volta ao Service |

Evento registrado pelo Kubernetes:

```
Warning  Unhealthy  pod/encurtador-...  Readiness probe failed: HTTP probe failed with statuscode: 503
```

## Conclusões

- **Readiness e liveness separadas funcionaram como projetado:** o pod saiu do
  tráfego sem ser reiniciado. Reiniciar não resolveria um problema no banco e
  só causaria reinícios em série.
- **Recuperação automática** em menos de 10 segundos, sem intervenção.
- O tempo até tirar o pod do tráfego (~30 s) é `periodSeconds` (10) ×
  `failureThreshold` (3, o padrão). Dá para reduzir, ao custo de reagir a
  falhas passageiras.
- **Descoberta:** uma NetworkPolicy nova não interrompe conexões já
  estabelecidas. Isso dá resiliência a falhas curtas, mas, do ponto de vista de
  segurança, aplicar uma política não corta imediatamente um acesso em andamento.
- A página fica totalmente fora do ar quando o banco cai (não há modo
  degradado). Uma evolução possível: uma página de manutenção servida pelo
  Ingress quando não houver pods prontos.
