#!/usr/bin/env bash
# Gera inventory/aws/hosts.ini com o IP da VM criada por infra/opentofu/aws.
# Rodar depois de cada "tofu apply" (cada VM efêmera tem um IP novo).
set -euo pipefail

ANSIBLE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOFU_DIR="$ANSIBLE_DIR/../opentofu/aws"
INVENTORY="$ANSIBLE_DIR/inventory/aws/hosts.ini"
KNOWN_HOSTS="$HOME/.ssh/known_hosts_aws_lab"

IP="$(tofu -chdir="$TOFU_DIR" output -raw public_ip)"

# Uma VM nova pode reaproveitar o IP de uma antiga, com outra impressão digital.
# Como o IP veio do state do nosso próprio OpenTofu, removemos a entrada antiga.
if [ -f "$KNOWN_HOSTS" ]; then
  ssh-keygen -R "$IP" -f "$KNOWN_HOSTS" >/dev/null 2>&1 || true
fi

cat > "$INVENTORY" <<EOF
# Gerado por scripts/gerar-inventario-aws.sh. Não editar à mão nem versionar.
[k3s_server]
gitops-k3s-node ansible_host=$IP

[k3s_agent]

[k3s_cluster:children]
k3s_server
k3s_agent
EOF

echo "Inventário gerado: $INVENTORY (VM em $IP)"
