import os
from anthropic import Anthropic


class ClaudeService:
    def __init__(self) -> None:
        api_key = os.getenv("ANTHROPIC_API_KEY")
        if not api_key:
            raise ValueError("ANTHROPIC_API_KEY is not set")

        self.client = Anthropic(api_key=api_key)
        self.model = "claude-sonnet-4-6"

    def ask(self, prompt: str, max_tokens: int = 300) -> str:
        response = self.client.messages.create(
            model=self.model,
            max_tokens=max_tokens,
            messages=[
                {"role": "user", "content": prompt}
            ],
        )

        texts = []
        for block in response.content:
            if getattr(block, "type", None) == "text":
                texts.append(block.text)

        return "\n".join(texts).strip()