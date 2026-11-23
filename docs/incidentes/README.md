# Incidentes e simulações

Registro dos problemas encontrados operando a plataforma, no formato de
**postmortem sem culpados**: o foco é o que falhou e como evitar que se repita,
não quem errou. As simulações (*game days*) são falhas provocadas de propósito
no ambiente efêmero da AWS para validar o comportamento da plataforma.

| # | Tipo | Título | Impacto | Duração |
|---|---|---|---|---|
| [001](001-deploy-travado-nas-migrations.md) | Real | Deploy travado nas migrations | Aplicação não subiu | ~20 min |
| [002](002-ssh-timeout-ip-mudou.md) | Real | Ansible sem acesso SSH após troca de IP | Provisionamento interrompido | ~5 min |
| [003](003-instancia-recusada-plano-gratuito.md) | Real | Instância EC2 recusada pelo plano gratuito | `tofu apply` parcial | ~10 min |
| [004](004-simulacao-banco-inacessivel.md) | Simulação | Banco de dados inacessível | Página fora do ar (503) | ~1 min |
| [005](005-simulacao-alerta-por-email.md) | Simulação | Alerta de ponta a ponta: banco inacessível → e-mail | Página fora do ar (503) | ~2 min |
| [006](006-teste-de-carga-limite-de-cpu.md) | Simulação | Teste de carga (k6): limite de CPU do pod como gargalo | Latência alta no pico, sem falhas | ~8 min |
| [007](007-ambiente-esquecido-ligado.md) | Real | Ambiente efêmero esquecido ligado | ~US$ 4–5 de créditos, sem cobrança real | ~42 h |

## Formato de cada registro

1. Resumo e impacto
2. Linha do tempo
3. Sintomas
4. Diagnóstico (comandos e o que cada um revelou)
5. Causa raiz
6. Correção
7. Prevenção e aprendizados
