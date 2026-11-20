# Atalhos da plataforma. Rode "make" para ver a lista.
.DEFAULT_GOAL := help
.PHONY: help aws-check aws-up aws-inventory aws-bootstrap aws-k3s aws-argocd aws-url aws-argocd-ui aws-grafana aws-all aws-ssh aws-nodes aws-status aws-down

export AWS_PROFILE ?= lab

TOFU_AWS   := infra/opentofu/aws
ANSIBLE    := infra/ansible
INV_AWS    := inventory/aws/hosts.ini
SSH_KEY    := ~/.ssh/id_ed25519_aws_lab
SSH_OPTS   := -i $(SSH_KEY) -o UserKnownHostsFile=~/.ssh/known_hosts_aws_lab -o StrictHostKeyChecking=accept-new
KUBECONFIG_AWS := ~/.kube/config-aws

help: ## Mostra esta ajuda
	@grep -E '^[a-zA-Z0-9_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  %-14s %s\n", $$1, $$2}'

# --- AWS (ambiente efêmero) ---

aws-check: ## Confere o login da AWS (se expirou: aws login --profile lab --remote)
	@aws sts get-caller-identity --query Arn --output text

aws-up: aws-check ## Cria rede e VM na AWS (mostra o plano e pede "yes")
	tofu -chdir=$(TOFU_AWS) apply

aws-inventory: ## Gera o inventário do Ansible com o IP da VM
	$(ANSIBLE)/scripts/gerar-inventario-aws.sh

aws-bootstrap: aws-inventory ## Cria o usuário definitivo e endurece o SSH
	@IP=$$(tofu -chdir=$(TOFU_AWS) output -raw public_ip); \
	echo "Esperando o SSH da VM..."; \
	for i in $$(seq 1 24); do ssh $(SSH_OPTS) -o ConnectTimeout=5 -o BatchMode=yes ubuntu@$$IP true 2>/dev/null && break; sleep 5; done
	cd $(ANSIBLE) && ansible-playbook -i $(INV_AWS) playbooks/01-bootstrap.yml

aws-k3s: ## Instala o k3s e traz o kubeconfig para ~/.kube/config-aws
	cd $(ANSIBLE) && ansible-playbook -i $(INV_AWS) playbooks/02-k3s-install.yml

aws-argocd: ## Instala o Argo CD e inicia o GitOps (deploy do encurtador)
	cd $(ANSIBLE) && ansible-playbook -i $(INV_AWS) playbooks/03-argocd.yml

aws-all: aws-up aws-bootstrap aws-k3s aws-argocd aws-nodes ## Tudo: VM + bootstrap + k3s + Argo CD

aws-url: ## Mostra o endereço público do encurtador
	@echo "http://$$(tofu -chdir=$(TOFU_AWS) output -raw public_ip)/"

aws-argocd-ui: ## Abre o painel do Argo CD em https://localhost:8080 (Ctrl+C encerra)
	@echo "Usuário: admin | Senha: $$(KUBECONFIG=$(KUBECONFIG_AWS) kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
	KUBECONFIG=$(KUBECONFIG_AWS) kubectl -n argocd port-forward svc/argocd-server 8080:443

aws-ssh: ## Entra na VM como halina
	ssh $(SSH_OPTS) halina@$$(tofu -chdir=$(TOFU_AWS) output -raw public_ip)

aws-nodes: ## Mostra os nós e os pods do cluster
	KUBECONFIG=$(KUBECONFIG_AWS) kubectl get nodes -o wide
	KUBECONFIG=$(KUBECONFIG_AWS) kubectl get pods -A

aws-grafana: ## Abre o Grafana em http://localhost:3000 (Ctrl+C encerra)
	@echo "Usuário: admin | Senha: $$(KUBECONFIG=$(KUBECONFIG_AWS) kubectl -n observabilidade get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d)"
	KUBECONFIG=$(KUBECONFIG_AWS) kubectl -n observabilidade port-forward svc/monitoramento-grafana 3000:80

aws-status: ## Mostra o que existe na AWS agora (o que está custando)
	@echo "Recursos no state: $$(tofu -chdir=$(TOFU_AWS) state list 2>/dev/null | wc -l)"
	@echo "Instâncias ligadas: $$(aws ec2 describe-instances --filters Name=tag:Project,Values=gitops-pipeline Name=instance-state-name,Values=pending,running,stopping,stopped --query 'length(Reservations[].Instances[])' --output text)"

aws-down: aws-check ## Destrói tudo na AWS (mostra a lista e pede "yes")
	tofu -chdir=$(TOFU_AWS) destroy
	@$(MAKE) --no-print-directory aws-status
