from typing import Literal, Optional

from pydantic import BaseModel


class AuditRequest(BaseModel):
    audit_type: Literal["code", "seo"]
    content: str
    context: Optional[str] = None


class Issue(BaseModel):
    severity: Literal["high", "medium", "low"]
    message: str
    location: Optional[str] = None


class AuditResponse(BaseModel):
    audit_type: Literal["code", "seo"]
    passed: bool
    summary: str
    issues: list[Issue]
    raw_model_response: Optional[str] = None
