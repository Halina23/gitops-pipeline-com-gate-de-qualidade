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
| GitOps/CD | Argo CD | ✅ Instalado, `Application` do ai-gate sincronizada (sync manual) |
| Gate de IA | FastAPI + Gemini | ✅ Buildado, deployado e saudável (`/healthz` OK) |
| Política | OPA/Conftest | ⬜ Não iniciado |
| CI | GitHub Actions | ⬜ Não iniciado |

### Detalhes do que já está pronto

- **OpenTofu**: VM `gitops-k3s-node` criada a partir de Vagrant box (`bento/ubuntu-24.04`), rede dupla (hostonly `192.168.56.102` fixo + NAT para internet), 100% reproduzível via `tofu apply`.
- **Ansible**: usuário `halina` com chave SSH própria, SSH endurecido (sem root, sem senha), configuração de rede codificada nos playbooks.
- **k3s**: instalado e operacional, certificado TLS com SAN correto para acesso externo, `kubectl` funcional do WSL via `KUBECONFIG=~/.kube/config-gitops`.
- **OpenBao**: instalado via Helm chart oficial (repo `openbao/openbao`) no namespace `openbao`, inicializado e destravado (unseal com 3 de 5 chaves). Secrets engine KV v2 habilitado em `secret/`, auth method Kubernetes configurado, policy de leitura `app-read` e role `ai-gate` (vinculado à service account `ai-gate`/namespace `ai-gate`) criados. Segredo real do Gemini gravado em `secret/ai-gate/gemini`. Vault Agent Injector do próprio chart cuida da injeção em `/vault/secrets/gemini-api-key`.
- **Argo CD**: instalado via Helm chart oficial no namespace `argocd`, todos os pods rodando (exceto `argocd-applicationset-controller`, ver pendências). `Application` `ai-gate` criada (`manifests/argocd/ai-gate-application.yaml`), sincronizada manualmente (sem `syncPolicy.automated` ainda).
- **Gate de IA (ai-gate)**: imagem `ai-gate:0.1.0` buildada localmente na própria VM do k3s e importada pro containerd via `k3s ctr -n k8s.io images import` (**atenção**: sem o `-n k8s.io` a imagem vai pro namespace errado do containerd e o kubelet não a enxerga — dá `ErrImageNeverPull`). Deployment com `imagePullPolicy: Never`, 1 réplica, rodando no namespace `ai-gate`, `/healthz` respondendo OK.

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
```

## Notas e pendências conhecidas

- Hostname do node aparece como `vagrant`/`halina-virtualbox` em vez de algo mais descritivo (cosmético, não bloqueante).
- Relógio interno da VM fica dessincronizado após longos períodos desligada (`timedatectl` mostra `System clock synchronized: no`, NTP inativo) — já causou resultados incoerentes em `ping` durante diagnóstico de rede. Não bloqueante até agora, mas considerar habilitar NTP.
- Senha inicial do admin do Argo CD ainda não foi trocada nem o secret `argocd-initial-admin-secret` apagado, como recomendado pela documentação oficial.
- `argocd-applicationset-controller` está em `CrashLoopBackOff` (centenas de restarts) — não impede o uso do Argo CD para `Application`s manuais, mas precisa ser investigado.
- O namespace `openbao` já sumiu do cluster uma vez sem explicação registrada (o cluster em si não foi recriado — nó com 52+ dias de uptime acumulado). OpenBao foi reinstalado do zero em 2026-08-26; novas chaves de unseal e root token foram geradas e estão no `.env` local.
- `Application` do ai-gate no Argo CD ainda não tem `syncPolicy.automated` — mudanças no repositório exigem sync manual (`argocd app sync ai-gate` ou pela UI) por enquanto.
- Helm e o CLI do Argo CD não vêm instalados na VM do k3s por padrão — foram baixados como binários avulsos em `~/.local/bin` (sem `apt`/root) durante a configuração do ai-gate.
