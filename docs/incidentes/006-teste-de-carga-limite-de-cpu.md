# 006 - Teste de carga: o limite de CPU do pod como gargalo

- **Data:** 2026-11-21
- **Tipo:** simulação (*game day*): teste de carga com k6
- **Ambiente:** AWS (efêmero); k6 rodando da máquina de administração, no Brasil
- **Impacto observado:** p95 no servidor de ~10 ms para 422 ms no pico; nenhuma falha
- **Roteiro:** [`tests/carga/encurtador.js`](https://github.com/Halina23/encurtador-links/blob/main/tests/carga/encurtador.js) no repositório do encurtador

## Objetivo

Descobrir até que carga o encurtador responde bem, onde está o gargalo e como
os dashboards e alertas reagem.

O roteiro simula o uso típico de um encurtador: 80% abrindo links (307), 15%
criando links (201) e 5% acessando códigos inexistentes (404), com 0,5 a 1,5 s
de pausa entre as ações de cada usuário virtual (VU).

## Resultados do k6 (latência do usuário, inclui a rede)

| Teste | Usuários | Requisições | Falhas | p95 | Critérios |
|---|---|---|---|---|---|
| smoke | 1 por 30 s | 74 | 0% | 164 ms | aprovado |
| load | 20 por 3 min | 4.237 (13,5/s) | 0% | 159 ms | aprovado |
| stress | 20 → 50 → 100 → 150 | 28.300 (56,8/s em média) | 0% | 347 ms | aprovado |

A requisição mais rápida de todos os testes levou ~144 ms: é o custo fixo da
rede entre o Brasil e a região `us-east-1`.

## Linha do tempo do stress (visão do servidor, Prometheus)

Medida a cada ~30 s, com janelas de 1 minuto. "Throttling" é a fração dos
períodos de CPU em que o pod foi limitado pelo `limits.cpu` (500m).

| Hora | req/s | p95 | p99 | CPU do pod (núcleos) | Throttling |
|---|---|---|---|---|---|
| 11:21:11 | 14,6 | 9,4 ms | 17,7 ms | 0,05 | 0% |
| 11:22:18 | 27,6 | 9,6 ms | 18,8 ms | 0,10 | 0% |
| 11:23:25 | 40,1 | 9,8 ms | 20,5 ms | 0,16 | 0% |
| 11:24:32 | 59,0 | 17,0 ms | 23,8 ms | 0,17 | 0% |
| 11:25:05 | 69,5 | 18,5 ms | 39,7 ms | 0,21 | 1% |
| 11:25:39 | 89,6 | 36,6 ms | 347,2 ms | 0,28 | 2% |
| 11:26:12 | 99,6 | 94,4 ms | 245,1 ms | 0,24 | 8% |
| 11:26:46 | 109,9 | 146,6 ms | 372,9 ms | 0,37 | 16% |
| **11:27:19** | **112,8** | **422,3 ms** | **490,5 ms** | **0,43** | **47%** |
| 11:27:53 | 95,3 | 91,8 ms | 325,7 ms | 0,32 | 7% |
| 11:28:26 | 33,1 | 10,9 ms | 22,2 ms | 0,07 | 0% |

No pico, o painel "Requisições em andamento" chegou a 40 (normalmente 1 a 3):
a fila de requisições esperando CPU.

## Previsão antes do stress

No load test, 13,5 req/s usaram 0,07 núcleo (~0,005 núcleo por req/s). Com o
limite de 0,5 núcleo, a previsão era de saturação por volta de 100 a 120 req/s.
**Confirmada:** a latência começou a subir em ~90 req/s e o pod saturou em ~113 req/s.

## Conclusões

- **O gargalo foi uma configuração, não o hardware:** a VM tem 2 vCPUs, mas o
  pod estava limitado a 0,5 núcleo (`limits.cpu: 500m` em `manifests/encurtador/app.yaml`).
  No pico, o Kubernetes limitou a CPU do pod em quase metade dos períodos e as
  requisições passaram a esperar na fila.
- **Degradação graciosa:** sob carga acima do limite, o encurtador ficou mais
  lento, mas não falhou (0 de 28.300 requisições).
- **O p50 continuou baixo (< 8 ms) enquanto o p99 disparou:** só uma parte das
  requisições sofreu com a fila. Olhar a média ou a mediana esconderia o problema.
- **~94% da latência percebida no Brasil é rede** (~150 ms de ~160 ms no load test).
  Para usuários brasileiros, a região `sa-east-1` ou uma CDN trariam mais ganho
  do que otimizar o código.
- **O alerta `EncurtadorLento` não disparou, corretamente:** a regra exige p95
  acima de 500 ms por 5 minutos; o p95 chegou a 422 ms por cerca de 2 minutos.
- **A janela do `rate()` muda o que o gráfico mostra:** o dashboard (janela de
  5 minutos) mostrou pico de ~68 req/s numa só rota; a medição com janela de
  1 minuto mostrou o pico real de ~113 req/s no total.

## Próximos passos possíveis

- Escala horizontal: 2 réplicas (ou um HorizontalPodAutoscaler por CPU) para
  dobrar o teto, validando com o mesmo stress.
- Revisar o `limits.cpu` com base nesses números (ex.: 1 núcleo).
- Rodar o k6 de dentro da AWS (mesma região) para medir só a aplicação.

## Achado operacional durante a execução

O IP público da administração mudou de novo (recorrência do
[incidente 002](002-ssh-timeout-ip-mudou.md), agora no sentido inverso). Desta
vez o playbook `03-argocd.yml` não falhou: ficou **parado por mais de 40
minutos**, esperando uma conexão SSH que o security group passou a bloquear. A
VM ficou ligada todo esse tempo. Resolvido com `tofu apply` (2 regras
atualizadas) e nova execução do playbook.

**Pendente:**

- tempo limite nas conexões do Ansible (ex.: `ServerAliveInterval` no SSH), para
  falhar em vez de travar;
- liberar as duas faixas de IP observadas, ou usar o Session Manager, para não
  depender do IP de origem.
