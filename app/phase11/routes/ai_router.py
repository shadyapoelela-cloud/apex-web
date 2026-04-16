from fastapi import APIRouter
from pydantic import BaseModel

from app.services.claude_service import ClaudeService

router = APIRouter(
    prefix="/ai",
    tags=["AI"]
)


class AskRequest(BaseModel):
    prompt: str


class AskResponse(BaseModel):
    answer: str


@router.post("/ask", response_model=AskResponse)
def ask_ai(data: AskRequest):

    service = ClaudeService()

    result = service.ask(
        prompt=data.prompt,
        max_tokens=300
    )

    return AskResponse(answer=result)