"""Market voice assistant schemas — parse spoken text into customer sales."""
import uuid

from pydantic import BaseModel


class ParsedMarketSale(BaseModel):
    """A single sale parsed from voice/text."""
    customer_name: str               # Customer name as extracted from speech
    customer_id: uuid.UUID | None = None  # Matched existing customer, or None if new
    is_new_customer: bool = True     # True when we'll need to create the customer first
    amount: float                    # Total sale amount
    notes: str | None = None         # Optional notes / item description
    confidence: float = 1.0          # 0-1 confidence from the parser


class MarketVoiceParseResponse(BaseModel):
    transcript: str
    parsed_sales: list[ParsedMarketSale]
    raw_response: str = ""
