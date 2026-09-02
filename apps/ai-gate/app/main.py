import logging

from fastapi import FastAPI, HTTPException

from app.audits import code_review, seo_review
from app.config import load_gemini_api_key
from app.gemini_client import GeminiClient
from app.schemas import AuditRequest, AuditResponse

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ai-gate")

app = FastAPI(title="AI Quality Gate", version="0.1.1")

_gemini_client: GeminiClient | None = None
_startup_error: str | None = None

PROMPT_BUILDERS = {
    "code": code_review.build_prompt,
    "seo": seo_review.build_prompt,
}


@app.on_event("startup")
def startup() -> None:
    global _gemini_client, _startup_error
    try:
        api_key = load_gemini_api_key()
        _gemini_client = GeminiClient(api_key)
        logger.info("Gemini API key carregada com sucesso")
    except Exception as exc:
        _startup_error = str(exc)
        logger.error("Falha ao carregar a Gemini API key: %s", exc)


@app.get("/healthz")
def healthz():
    if _gemini_client is None:
        raise HTTPException(status_code=503, detail=_startup_error or "gemini client not initialized")
    return {"status": "ok"}


@app.post("/audit", response_model=AuditResponse)
def audit(req: AuditRequest):
    if _gemini_client is None:
        raise HTTPException(status_code=503, detail=_startup_error or "gemini client not initialized")

    build_prompt = PROMPT_BUILDERS[req.audit_type]
    prompt = build_prompt(req.content, req.context)
    result = _gemini_client.run_audit(prompt)

    return AuditResponse(
        audit_type=req.audit_type,
        passed=result.get("passed", False),
        summary=result.get("summary", ""),
        issues=result.get("issues", []),
        raw_model_response=result.get("raw_model_response"),
    )
