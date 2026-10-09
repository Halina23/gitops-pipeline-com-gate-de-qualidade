from typing import Literal, Optional

from pydantic import BaseModel, Field


class AuditRequest(BaseModel):
    audit_type: Literal["code", "seo"]
    content: str = Field(min_length=1)
    context: Optional[str] = None


class Issue(BaseModel):
    # location e opcional porque nem todo problema apontado pelo modelo e
    # atribuivel a um arquivo/linha especifico (ex: falta de contexto geral do PR).
    severity: Literal["high", "medium", "low"]
    message: str
    location: Optional[str] = None


class AuditResponse(BaseModel):
    audit_type: Literal["code", "seo"]
    passed: bool
    summary: str
    issues: list[Issue]
    raw_model_response: Optional[str] = None
