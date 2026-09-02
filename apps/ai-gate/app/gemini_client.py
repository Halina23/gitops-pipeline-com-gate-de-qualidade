import json
import logging

from google import genai
from google.genai import errors as genai_errors
from tenacity import retry, retry_if_exception_type, stop_after_attempt, wait_exponential

from app.config import GEMINI_MODEL

logger = logging.getLogger("ai-gate.gemini")


class GeminiClient:
    def __init__(self, api_key: str):
        self._client = genai.Client(api_key=api_key)

    # A propria API do Gemini fica instavel sob alta demanda (503) de forma
    # transitoria; sem esse retry, um pico momentaneo derruba o gate inteiro
    # (ja aconteceu num run real do CI).
    @retry(
        retry=retry_if_exception_type(genai_errors.ServerError),
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=2, min=2, max=20),
        reraise=True,
    )
    def _generate(self, prompt: str):
        return self._client.models.generate_content(
            model=GEMINI_MODEL,
            contents=prompt,
            config={"response_mime_type": "application/json"},
        )

    def run_audit(self, prompt: str) -> dict:
        response = self._generate(prompt)
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
