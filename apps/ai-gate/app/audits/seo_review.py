from typing import Optional


def build_prompt(content: str, context: Optional[str]) -> str:
    context_block = f"\nContexto adicional (URL/pagina):\n{context}\n" if context else ""
    return f"""Voce e um especialista em SEO tecnico. Analise o HTML/conteudo abaixo e aponte
problemas de SEO: title ausente ou ruim, meta description ausente, hierarquia de headings
incorreta, imagens sem atributo alt, links quebrados aparentes, conteudo duplicado ou thin content.
{context_block}
Conteudo:
```
{content}
```

Responda EXCLUSIVAMENTE em JSON, no formato:
{{
  "passed": true|false,
  "summary": "resumo de uma frase",
  "issues": [
    {{"severity": "high|medium|low", "message": "descricao do problema", "location": "elemento/secao se identificavel"}}
  ]
}}

"passed" deve ser false se houver qualquer issue de severidade "high"."""
