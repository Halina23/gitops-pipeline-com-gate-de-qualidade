import json
import logging

from google import genai

from app.config import GEMINI_MODEL

logger = logging.getLogger("ai-gate.gemini")


class GeminiClient:
    def __init__(self, api_key: str):
        self._client = genai.Client(api_key=api_key)

    def run_audit(self, prompt: str) -> dict:
        response = self._client.models.generate_content(
            model=GEMINI_MODEL,
            contents=prompt,
            config={"response_mime_type": "application/json"},
        )
        text = response.text or ""

        try:
            return json.loads(text)
        except (json.JSONDecodeError, TypeError):
            logger.warning("Falha ao parsear resposta JSON do Gemini, retornando fallback")
            return {
                "passed": False,
                "summary": "Nao foi possivel interpretar a resposta do modelo como JSON",
                "issues": [],
                "raw_model_response": text,
            }
