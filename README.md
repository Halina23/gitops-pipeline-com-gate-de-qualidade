# GitOps Pipeline com Gate de Qualidade por IA

Pipeline de infraestrutura on-premises (OpenTofu → Ansible → OpenBao → Argo CD) rodando localmente via k3s, com um diferencial: um **gate de qualidade de código com IA** (FastAPI + Gemini) que audita código automaticamente antes de qualquer deploy ser sincronizado pelo GitOps.

## Ideia do projeto

O projeto nasce de dois objetivos concretos:

1. **Portfólio técnico** — é a prova prática de uma análise de sizing/governança de infraestrutura já apresentada profissionalmente, mostrando a stack funcionando de ponta a ponta, provisionada e documentada do zero.
2. **Ferramenta de uso real** — o gate de IA automatiza uma auditoria de código e SEO que hoje é feita manualmente em um projeto de cliente. Ou seja, além de vitrine técnica, é algo que resolve um problema real do dia a dia.

A construção é feita **passo a passo**, com o porquê de cada decisão registrado (não é um tutorial seguido às cegas). O objetivo final: qualquer alteração de código enviada ao repositório passa por uma auditoria automática de IA antes do Argo CD sincronizar o deploy no cluster — um gate de qualidade que roda antes da entrega, não depois.

## Arquitetura

```
Dev push → Git → CI (GitHub Actions) → Gate de IA (FastAPI + Gemini) → OPA/Conftest → Argo CD → k3s
                                              ↑
                                         OpenBao (segredos)
```

- **OpenTofu**: provisiona a VM do cluster.
- **Ansible**: configura o SO e instala o k3s na VM.
- **k3s**: cluster Kubernetes single-node onde tudo roda.
- **OpenBao**: cofre de segredos (chaves de API, credenciais), acessado via auth Kubernetes.
- **Argo CD**: sincroniza o estado do cluster com o que está declarado neste repositório (GitOps).
- **Gate de IA**: serviço FastAPI que usa o Gemini para revisar código/PRs antes do deploy ser liberado.
- **OPA/Conftest**: validação de políticas complementar ao gate de IA.
- **GitHub Actions**: dispara o pipeline de CI a partir de cada push/PR.

## Stack e status

| Camada | Ferramenta | Status |
|---|---|---|
| Provisionamento | OpenTofu (VM via `null_resource` + `VBoxManage` direto) | ✅ Completo |
| Configuração | Ansible (rodando do WSL2) | ✅ Completo |
| Orquestração | k3s (single-node) | ✅ Completo, `Ready` |
| Segredos | OpenBao (KV v2 + auth Kubernetes configurados) | ✅ Completo |
| GitOps/CD | Argo CD | ✅ Instalado, `Application` do ai-gate com sync automático (`prune`+`selfHeal`) |
| Gate de IA | FastAPI + Gemini | ✅ Buildado, deployado e saudável (`/healthz` OK) |
| Política | OPA/Conftest | ✅ Políticas em `policy/kubernetes.rego`, rodando no CI |
| CI | GitHub Actions | ✅ `.github/workflows/quality-gate.yml`, runner self-hosted na própria VM do k3s |

### Detalhes do que já está pronto

- **OpenTofu**: VM `gitops-k3s-node` criada a partir de Vagrant box (`bento/ubuntu-24.04`), rede dupla (hostonly `192.168.56.102` fixo + NAT para internet), 100% reproduzível via `tofu apply`.
- **Ansible**: usuário `halina` com chave SSH própria, SSH endurecido (sem root, sem senha), configuração de rede codificada nos playbooks.
- **k3s**: instalado e operacional, certificado TLS com SAN correto para acesso externo, `kubectl` funcional do WSL via `KUBECONFIG=~/.kube/config-gitops`.
- **OpenBao**: instalado via Helm chart oficial (repo `openbao/openbao`) no namespace `openbao`, inicializado e destravado (unseal com 3 de 5 chaves). Secrets engine KV v2 habilitado em `secret/`, auth method Kubernetes configurado, policy de leitura `app-read` e role `ai-gate` (vinculado à service account `ai-gate`/namespace `ai-gate`) criados. Segredo real do Gemini gravado em `secret/ai-gate/gemini`. Vault Agent Injector do próprio chart cuida da injeção em `/vault/secrets/gemini-api-key`.
- **Argo CD**: instalado via Helm chart oficial no namespace `argocd`, todos os pods rodando. `Application` `ai-gate` criada (`manifests/argocd/ai-gate-application.yaml`) com `syncPolicy.automated` (`prune: true`, `selfHeal: true`) — push em `manifests/ai-gate/` dispara deploy sozinho, e mudanças manuais no cluster são revertidas automaticamente.
- **Gate de IA (ai-gate)**: imagem buildada localmente na própria VM do k3s e importada pro containerd via `k3s ctr -n k8s.io images import` (**atenção**: sem o `-n k8s.io` a imagem vai pro namespace errado do containerd e o kubelet não a enxerga — dá `ErrImageNeverPull`). Deployment com `imagePullPolicy: Never`, 1 réplica, rodando no namespace `ai-gate`. Chamada real ao Gemini com retry/backoff (`tenacity`) pra absorver erros 503 transitórios de sobrecarga da API. Versão atual: `0.1.2`.
- **CI (GitHub Actions)**: workflow `.github/workflows/quality-gate.yml` roda em push/PR pra `master`, em um **runner self-hosted instalado na própria VM do k3s** (não há endpoint público pro ai-gate — sem isso, o runner hospedado na nuvem do GitHub não teria como chamá-lo). Dois jobs: `policy` (Conftest contra `manifests/*/*.yaml`) e `ai-audit` (calcula o diff de `apps/` e envia pro `/audit` real do ai-gate, reprovando o job se `passed: false`). O runner acessa o ai-gate direto pelo `ClusterIP` do Service — funciona sem port-forward porque, num cluster single-node, o próprio host já tem as regras de rede do `kube-proxy`. Runner registrado como serviço systemd (`~/actions-runner`, `sudo ./svc.sh status` pra checar).

## Ambiente de desenvolvimento

- Windows host + WSL2 (Ubuntu 24.04) como control node do Ansible + VirtualBox rodando a VM do cluster.
- Repositório: `D:\Projetos\gitops-ai-pipeline` (Windows) / `/mnt/d/Projetos/gitops-ai-pipeline` (WSL).

### Ligar/desligar a VM do cluster

```powershell
VBoxManage startvm gitops-k3s-node --type headless
VBoxManage controlvm gitops-k3s-node poweroff
```

> Evite manter duas VMs ligadas ao mesmo tempo (`gitops-k3s-node` + outra VM de desenvolvimento) — já causou lentidão por disputa de recursos.

### Segredos

Credenciais geradas (unseal keys do OpenBao, root token, senha do Argo CD) ficam em um arquivo `.env` na raiz do projeto, **fora do controle de versão** (`.gitignore`). Nunca commitar esse arquivo.

## Estrutura do repositório

```
infra/
  opentofu/     # provisionamento da VM
  ansible/      # configuração do SO e instalação do k3s
apps/
  ai-gate/      # codigo do gate de IA (FastAPI + Gemini) e seu Dockerfile
manifests/
  ai-gate/      # Deployment/Service/Namespace/ServiceAccount do ai-gate
  argocd/       # Application do Argo CD que sincroniza manifests/ai-gate
policy/
  kubernetes.rego  # politicas Conftest/OPA que validam os manifests Kubernetes
.github/
  workflows/quality-gate.yml  # CI: conftest + auditoria de IA real
```

### Rodando as políticas do Conftest localmente

```bash
conftest test manifests/*/*.yaml -p policy
```

Valida boas práticas que o gate de IA não teria como pegar sozinho (ele revisa diffs de código, não o YAML final aplicado no cluster): resources.requests/limits definidos, readinessProbe/livenessProbe presentes, imagem com tag explícita (nunca `:latest`), e `metadata.namespace` definido em recursos namespaced. Isso é o mesmo comando que o job `policy` do CI roda automaticamente a cada push/PR.

## Notas e pendências conhecidas

- Hostname do node aparece como `vagrant`/`halina-virtualbox` em vez de algo mais descritivo (cosmético, não bloqueante).
- Relógio interno da VM fica dessincronizado após longos períodos desligada (`timedatectl` mostra `System clock synchronized: no`, NTP inativo) — já causou resultados incoerentes em `ping` durante diagnóstico de rede. Não bloqueante até agora, mas considerar habilitar NTP.
- Senha inicial do admin do Argo CD ainda não foi trocada nem o secret `argocd-initial-admin-secret` apagado, como recomendado pela documentação oficial.
- ~~`argocd-applicationset-controller` em `CrashLoopBackOff`~~ — corrigido: faltava o CRD `applicationsets.argoproj.io` no cluster (só `applications` e `appprojects` existiam). Reaplicado a partir do manifest oficial da versão instalada (`v3.4.4`).
- O namespace `openbao` já sumiu do cluster uma vez sem explicação registrada (o cluster em si não foi recriado — nó com 52+ dias de uptime acumulado). OpenBao foi reinstalado do zero em 2026-08-26; novas chaves de unseal e root token foram geradas e estão no `.env` local.
- Helm e o CLI do Argo CD não vêm instalados na VM do k3s por padrão — foram baixados como binários avulsos em `~/.local/bin` (sem `apt`/root) durante a configuração do ai-gate.
- **OpenBao sela de novo toda vez que a VM é reiniciada** (comportamento normal do Shamir seal, não é bug). Quando isso acontecer: destravar com 3 das chaves no `.env` (`bao operator unseal`) e depois recriar o pod do `ai-gate` (`kubectl delete pod -n ai-gate -l app=ai-gate`) em vez de esperar o backoff do `vault-agent-init` expirar.
- **CoreDNS não relê `/etc/resolv.conf` em execução** — se a rede da VM mudar (ex.: troca de rede NAT do VirtualBox), o CoreDNS pode continuar apontando para um DNS upstream antigo e todo tráfego de saída dos pods (incluindo chamadas ao Gemini) passa a falhar com erro de resolução de nome. Sintoma: `httpx.ConnectError: Temporary failure in name resolution` nos logs do ai-gate. Fix: `kubectl delete pod -n kube-system -l k8s-app=kube-dns`.
- **Nomes de modelo do Gemini mudam com frequência** — `gemini-2.0-flash` foi descontinuado e teve que ser trocado por `gemini-3.6-flash` em `apps/ai-gate/app/config.py`. Se `/audit` retornar 500, checar os logs do pod por um `ClientError 404` antes de suspeitar de outra coisa.
- **A própria API do Gemini falha de forma transitória sob alta demanda** (`503 UNAVAILABLE`) — já aconteceu num run real do CI. Mitigado com retry/backoff em `gemini_client.py` (3 tentativas), mas se voltar a acontecer com mais frequência, considerar aumentar o número de tentativas.
- **O CI depende de um único runner self-hosted** rodando na própria VM do k3s (`~/actions-runner`, serviço systemd `actions.runner.Halina23-*`). Se a VM estiver desligada, nenhum push/PR consegue rodar o Quality Gate — os jobs ficam na fila do GitHub até o runner voltar a ficar online. É uma limitação aceita pelo desenho atual (ai-gate não tem endpoint público), não um bug.
- **O gate de IA pode reprovar mudanças corretas por causa da data de corte do conhecimento do modelo** — ex.: já reprovou uma correção real do próprio `GEMINI_MODEL` alegando que o novo model id "não existe", quando na verdade ele já tinha sido validado ao vivo. Uma reprovação do CI não deve ser tratada como automaticamente correta sem checar o motivo.
