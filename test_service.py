from app.services.claude_service import ClaudeService

service = ClaudeService()
result = service.ask("اكتب لي جملة عربية قصيرة ترحب بالمستخدم.")
print(result)