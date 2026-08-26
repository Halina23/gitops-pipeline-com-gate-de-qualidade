from typing import Optional


def build_prompt(content: str, context: Optional[str]) -> str:
    context_block = f"\nContexto adicional (titulo/descricao do PR):\n{context}\n" if context else ""
    return f"""Voce e um revisor de codigo senior. Analise o diff abaixo e aponte problemas reais:
bugs, vulnerabilidades de seguranca, ma pratica, falta de tratamento de erro relevante e
violacoes de estilo que atrapalhem manutencao. Nao aponte estilo cosmetico irrelevante.
{context_block}
Diff:
```
{content}
```

Responda EXCLUSIVAMENTE em JSON, no formato:
{{
  "passed": true|false,
  "summary": "resumo de uma frase",
  "issues": [
    {{"severity": "high|medium|low", "message": "descricao do problema", "location": "arquivo/linha se identificavel"}}
  ]
}}

"passed" deve ser false se houver qualquer issue de severidade "high"."""
