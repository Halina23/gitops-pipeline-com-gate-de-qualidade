# 002 - Ansible sem acesso SSH após troca de IP

- **Data:** 2026-11-20
- **Ambiente:** AWS (efêmero), recriação do ambiente
- **Impacto:** provisionamento interrompido no playbook do Argo CD
- **Duração:** ~5 minutos

## Resumo

No meio da recriação do ambiente, o playbook `03-argocd.yml` falhou com
`Connection timed out` ao conectar por SSH. O IP público da máquina de
administração mudou entre o `tofu apply` (que libera SSH só para o IP da
administração) e a execução do playbook.

## Linha do tempo

*Horários aproximados, reconstruídos a partir dos registros da sessão.*

| Hora | Evento |
|---|---|
| 11:57 | `tofu apply` cria a VM; security group libera SSH/6443 para o IP atual (`189.37.x.x/32`) |
| 11:58–12:00 | Playbooks 01 (bootstrap) e 02 (k3s) concluem com sucesso |
| 12:00 | Playbook 03 falha: `ssh: connect to host ... port 22: Connection timed out` |
| 12:01 | Comparação do IP liberado com o IP atual: mudou para `179.221.x.x` |
| 12:02 | `tofu apply`: `0 to add, 2 to change, 0 to destroy` (só as regras de SSH e 6443) |
| 12:03 | Playbook 03 reexecutado com sucesso |

## Sintomas

- `Connection timed out` (e não `Connection refused`): o pacote nem chegava à VM.
- Os playbooks anteriores, minutos antes, haviam funcionado.

## Diagnóstico

| Comando | Resultado |
|---|---|
| `tofu output -raw admin_cidr` | IP liberado no security group: `189.37.x.x/32` |
| `curl https://checkip.amazonaws.com` | IP atual: `179.221.x.x` |

*Timeout* indica bloqueio no caminho (firewall descartando o pacote); *refused*
indicaria que o pacote chegou e nada escutava na porta.

## Causa raiz

O security group restringe SSH (22) e a API do Kubernetes (6443) ao IP público
da administração, descoberto no momento do `plan`. A operadora trocou o IP
público durante a sessão, e o novo IP não estava liberado.

## Correção

```bash
tofu -chdir=infra/opentofu/aws apply
```

O data source `http` descobriu o IP novo e o OpenTofu atualizou apenas as duas
regras de entrada (*update in-place*), sem recriar a VM.

## Prevenção e aprendizados

- Restringir acesso administrativo por IP é correto, mas frágil com IP dinâmico.
- Alternativas avaliadas para o futuro:
  - liberar as faixas de IP que a operadora costuma usar;
  - **AWS Systems Manager Session Manager**: acesso à VM sem porta 22 aberta e
    sem depender do IP de origem.
- Procedimento documentado: se SSH ou `kubectl` pararem de responder, rodar
  `tofu apply` e repetir o comando.
