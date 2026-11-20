# 001 - Deploy travado nas migrations

- **Data:** 2026-11-20
- **Ambiente:** AWS (efêmero), primeiro deploy do encurtador via Argo CD
- **Impacto:** a aplicação não subiu; o banco subiu, mas as migrations nunca rodaram
- **Duração:** ~20 minutos (do primeiro sync à correção aplicada)

## Resumo

O Job de migrations ficou parado em `Init:0/1`. O init container que espera o
banco (`pg_isready`) nunca terminava porque, rodando com o UID 1000, não
conseguia determinar um usuário padrão e respondia `no attempt` sem sequer
tentar conectar. Depois da correção no Git, o Argo CD continuou preso à
operação antiga, que esperava pelo hook, até a operação ser encerrada.

## Linha do tempo

*Horários aproximados, reconstruídos a partir dos registros da sessão.*

| Hora | Evento |
|---|---|
| 11:29 | Playbook `03-argocd.yml` conclui; Argo CD inicia o sync do encurtador (commit `b1f056d`) |
| 11:30 | Banco (`encurtador-db-0`) Running; Job `encurtador-migrate` em `Init:0/1` |
| 11:35 | Application `OutOfSync`, Job ainda em `Init:0/1`; início da investigação |
| 11:37 | Causa raiz identificada (`no attempt` no log do init container) |
| 11:41 | Correção publicada via PR #3 (`-U encurtador` no `pg_isready`) e mergeada (`c35a70b`) |
| 11:42 | Job travado apagado; Argo CD ainda preso à operação antiga |
| 11:48 | Operação antiga encerrada; novo sync com `c35a70b` |
| 11:49 | Migrations `Completed`, aplicação `Running`, Application `Synced/Healthy` |

## Sintomas

- `kubectl get pods`: Job de migrations em `Init:0/1` por vários minutos.
- Deployment da aplicação nem foi criado (sync waves: a onda 2 espera a onda 1).
- Argo CD: `OutOfSync` / operação `Running`.

## Diagnóstico

| Comando | Resultado | Conclusão |
|---|---|---|
| `kubectl logs <pod> -c espera-banco` | `encurtador-db:5432 - no attempt` | O `pg_isready` nem tentou conectar |
| `kubectl exec encurtador-db-0 -- pg_isready -h 127.0.0.1` | `accepting connections` | O banco está saudável |
| `getent hosts encurtador-db` e `pg_isready -h encurtador-db` (de dentro do banco) | DNS ok e `accepting connections` | Rede e DNS funcionam |
| Comparação entre os dois pods | O banco roda como `postgres`; o init container herda `runAsUser: 1000` do pod | Diferença de usuário |

## Causa raiz

O `securityContext` do pod (`runAsUser: 1000`) vale para todos os containers,
inclusive o init container baseado na imagem do Postgres. Sem `-U`, o
`pg_isready` usa o nome do usuário do sistema como usuário padrão. O UID 1000
existe na imagem da aplicação, mas não na do Postgres; sem conseguir resolver o
nome, o `pg_isready` desiste com `no attempt`. O laço `until pg_isready ...`
nunca termina.

### Causa secundária (bloqueio no Argo CD)

O Job é um hook de sync. Ao apagá-lo, o finalizer
`argocd.argoproj.io/hook-finalizer` o manteve em estado de exclusão, e a
operação de sync antiga (no commit `b1f056d`) continuou esperando por ele. O
Argo CD não inicia uma nova operação enquanto outra está em andamento, então o
commit corrigido não era aplicado.

## Correção

1. PR #3: `pg_isready -h encurtador-db -p 5432 -U encurtador`, com comentário no
   manifesto explicando o motivo.
2. Encerramento da operação travada (equivalente ao `argocd app terminate-op`):

   ```bash
   kubectl -n argocd patch application encurtador --type merge \
     -p '{"status":{"operationState":{"phase":"Terminating"}}}'
   ```

   O Argo CD liberou o finalizer e iniciou um sync novo com o commit corrigido.

## Prevenção e aprendizados

- `securityContext` no nível do pod afeta todos os containers; imagens de
  terceiros podem não ter o UID esperado.
- Ferramentas de linha de comando com "usuário padrão" devem receber o usuário
  explicitamente.
- **Pendente:** adicionar `activeDeadlineSeconds` ao Job de migrations, para
  ele falhar após um tempo máximo em vez de travar o sync indefinidamente.
- Mesmo a correção de um bug passa pelo Git (commit, PR, merge); editar o
  cluster à mão seria desfeito pelo `selfHeal`.
