from datetime import date

from pydantic import BaseModel


class ParsedExpenseItem(BaseModel):
    amount: float
    currency: str
    category_hint: str        # category name extracted from speech (Arabic or English)
    description: str
    expense_date: date
    confidence: float = 1.0   # 0-1 confidence score from GPT
    wallet_hint: str | None = None  # wallet_type detected from speech (salary, bank, cash, zaincash, mastercard)


class VoiceParseResponse(BaseModel):
    transcript: str
    parsed_expenses: list[ParsedExpenseItem]
    raw_gpt_response: str


class VoiceConfirmRequest(BaseModel):
    """User reviews parsed items and sends confirmed list for bulk save."""
    items: list[ParsedExpenseItem]
