#!/usr/bin/env bash
# Converte um arquivo de faixas de IP (uma por linha, "#" para comentários) numa
# lista JSON, para a variável admin_cidrs_extras do OpenTofu.
# Se o arquivo não existir, devolve uma lista vazia.
set -euo pipefail

ARQUIVO="${1:-}"

if [ -z "$ARQUIVO" ] || [ ! -f "$ARQUIVO" ]; then
  echo "[]"
  exit 0
fi

python3 - "$ARQUIVO" <<'EOF'
import json, sys

faixas = []
with open(sys.argv[1]) as f:
    for linha in f:
        linha = linha.split("#", 1)[0].strip()
        if linha:
            faixas.append(linha)
print(json.dumps(faixas))
EOF
