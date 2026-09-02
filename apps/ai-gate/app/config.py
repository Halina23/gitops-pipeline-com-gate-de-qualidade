import os
from pathlib import Path

GEMINI_API_KEY_FILE = os.environ.get("GEMINI_API_KEY_FILE", "/vault/secrets/gemini-api-key")

# Confirme o model id atual em https://ai.google.dev/gemini-api/docs/models antes do deploy -
# nomes de modelo mudam com frequencia e o valor abaixo e apenas um default de fallback.
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-3.6-flash")


def load_gemini_api_key() -> str:
    env_key = os.environ.get("GEMINI_API_KEY")
    if env_key:
        return env_key.strip()

    path = Path(GEMINI_API_KEY_FILE)
    if not path.exists():
        raise RuntimeError(
            f"Gemini API key nao encontrada: variavel GEMINI_API_KEY ausente e "
            f"arquivo {path} nao existe"
        )
    return path.read_text().strip()
