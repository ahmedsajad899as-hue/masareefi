"""
AI Service — Whisper (speech-to-text) + GPT-4o (expense extraction) + local fallback parser.
"""
import json
import re
from datetime import date, datetime, timezone

from openai import AsyncOpenAI

from app.config import settings
from app.schemas.voice import ParsedExpenseItem

client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)

# ─── Arabic number words ─────────────────────────────────────
_AR_NUMS = {
    "صفر": 0, "واحد": 1, "وحدة": 1, "اثنين": 2, "ثنتين": 2, "ثلاث": 3, "ثلاثة": 3,
    "أربع": 4, "أربعة": 4, "خمس": 5, "خمسة": 5, "ست": 6, "ستة": 6,
    "سبع": 7, "سبعة": 7, "ثمان": 8, "ثمانية": 8, "تسع": 9, "تسعة": 9,
    "عشر": 10, "عشرة": 10, "عشرين": 20, "ثلاثين": 30, "أربعين": 40,
    "خمسين": 50, "ستين": 60, "سبعين": 70, "ثمانين": 80, "تسعين": 90,
    # Iraqi dialect teens (11-19)
    "حدعش": 11, "احدعش": 11, "إحدعش": 11, "حادعش": 11,
    "ثنتعش": 12, "اثنتعش": 12, "اثنعش": 12,
    "ثلطعش": 13, "تلطعش": 13, "ثلثطعش": 13, "ثلاثطعش": 13,
    "أربعطعش": 14, "اربعطعش": 14, "أربعتعش": 14, "اربعتعش": 14,
    "خمصطعش": 15, "خمستعش": 15, "خمسطعش": 15, "خمستاعش": 15,
    "ستطعش": 16, "ستاعش": 16, "ستتعش": 16,
    "سبعطعش": 17, "سبعتعش": 17,
    "ثمنطعش": 18, "ثمانطعش": 18, "ثمانتعش": 18,
    "تسعطعش": 19, "تسعتعش": 19,
    # hundreds (with dialect forms)
    "مية": 100, "مئة": 100, "ميه": 100, "مئه": 100, "ميتين": 200, "مئتين": 200,
    "خمسمية": 500, "خمسمئة": 500, "خمسميه": 500,
    "ستمية": 600, "ستمئة": 600, "ستميه": 600,
    "سبعمية": 700, "سبعمئة": 700, "سبعميه": 700,
    "ثمانمية": 800, "ثمنمية": 800, "ثمنميه": 800,
    "تسعمية": 900, "تسعمئة": 900, "تسعميه": 900,
    # thousands
    "ألف": 1000, "الف": 1000, "ألفين": 2000, "الفين": 2000,
    "ثلاث آلاف": 3000, "ثلاثة آلاف": 3000, "أربع آلاف": 4000, "أربعة آلاف": 4000,
    "خمس آلاف": 5000, "خمسة آلاف": 5000, "ست آلاف": 6000, "ستة آلاف": 6000,
    "سبع آلاف": 7000, "سبعة آلاف": 7000, "ثمان آلاف": 8000, "ثمانية آلاف": 8000,
    "تسع آلاف": 9000, "تسعة آلاف": 9000, "عشر آلاف": 10000, "عشرة آلاف": 10000,
    "مليون": 1000000,
}

_CATEGORY_MAP = {
    # ── طعام ومطاعم ──
    "أكل": "طعام", "طعام": "طعام", "غداء": "طعام", "عشاء": "طعام", "فطور": "طعام",
    "مطعم": "طعام", "أكلة": "طعام", "اكل": "طعام", "خبز": "طعام", "لحم": "طعام",
    "دجاج": "طعام", "رز": "طعام", "سمك": "طعام", "فلافل": "طعام", "شاورما": "طعام",
    "بيتزا": "طعام", "برغر": "طعام", "كباب": "طعام", "مشاوي": "طعام", "سندويش": "طعام",
    "مقهى": "طعام", "قهوة": "طعام", "شاي": "طعام", "عصير": "طعام", "ماي": "طعام",
    "حلويات": "طعام", "كيك": "طعام", "بقلاوة": "طعام", "ايسكريم": "طعام",
    "خضار": "طعام", "فواكه": "طعام", "بقالة": "طعام", "سوبرماركت": "طعام", "ماركت": "طعام",
    "منيو": "طعام", "طلبية": "طعام", "دليفري": "طعام", "توصيل اكل": "طعام",
    "food": "طعام", "lunch": "طعام", "dinner": "طعام", "breakfast": "طعام",
    "restaurant": "طعام", "coffee": "طعام", "pizza": "طعام",
    # ── سيارة ونقل (مواصلات) ──
    "تاكسي": "مواصلات", "تكسي": "مواصلات", "مواصلات": "مواصلات", "بنزين": "مواصلات", "وقود": "مواصلات",
    "سيارة": "مواصلات", "سياره": "مواصلات", "باص": "مواصلات",
    "تصليح": "مواصلات", "تصليح سيارة": "مواصلات", "تصليح سياره": "مواصلات",
    "صيانة": "مواصلات", "صيانة سيارة": "مواصلات", "صيانه": "مواصلات",
    "دهن": "مواصلات", "دهان": "مواصلات", "دهن سيارة": "مواصلات", "دهن سياره": "مواصلات",
    "تبديل": "مواصلات", "اطارات": "مواصلات", "تاير": "مواصلات", "تايرات": "مواصلات",
    "زيت": "مواصلات", "زيت سيارة": "مواصلات", "فلتر": "مواصلات",
    "غسل سيارة": "مواصلات", "غسل سياره": "مواصلات", "غسيل": "مواصلات",
    "كراج": "مواصلات", "ميكانيكي": "مواصلات", "كهربائي سيارة": "مواصلات",
    "موقف": "مواصلات", "مواقف": "مواصلات", "باركنغ": "مواصلات",
    "ترخيص": "مواصلات", "تأمين سيارة": "مواصلات", "رخصة": "مواصلات",
    "کریم": "مواصلات", "كريم": "مواصلات", "بولت": "مواصلات",
    "transport": "مواصلات", "taxi": "مواصلات", "gas": "مواصلات", "fuel": "مواصلات",
    "car": "مواصلات", "parking": "مواصلات",
    # ── تسوق ──
    "تسوق": "تسوق", "بضاعة": "تسوق", "ملابس": "تسوق", "أحذية": "تسوق", "حذاء": "تسوق",
    "عطر": "تسوق", "ساعة": "تسوق", "نظارة": "تسوق", "شنطة": "تسوق", "حقيبة": "تسوق",
    "هدية": "تسوق", "هدايا": "تسوق", "مجوهرات": "تسوق", "ذهب": "تسوق",
    "أثاث": "تسوق", "أجهزة": "تسوق", "جهاز": "تسوق", "موبايل": "تسوق", "لابتوب": "تسوق",
    "shopping": "تسوق", "clothes": "تسوق",
    # ── صحة ──
    "صحة": "صحة", "دكتور": "صحة", "طبيب": "صحة", "دواء": "صحة", "مستشفى": "صحة",
    "صيدلية": "صحة", "علاج": "صحة", "عملية": "صحة", "تحاليل": "صحة", "أشعة": "صحة",
    "اسنان": "صحة", "عيون": "صحة", "عيادة": "صحة",
    "health": "صحة", "doctor": "صحة", "medicine": "صحة",
    # ── ترفيه ──
    "ترفيه": "ترفيه", "سينما": "ترفيه", "لعب": "ترفيه", "ألعاب": "ترفيه", "بلايستيشن": "ترفيه",
    "سفر": "ترفيه", "فندق": "ترفيه", "رحلة": "ترفيه", "سياحة": "ترفيه",
    "حفلة": "ترفيه", "حفل": "ترفيه", "مسبح": "ترفيه", "نادي": "ترفيه", "جم": "ترفيه",
    "entertainment": "ترفيه", "games": "ترفيه", "travel": "ترفيه",
    # ── تعليم ──
    "تعليم": "تعليم", "مدرسة": "تعليم", "جامعة": "تعليم", "كتب": "تعليم",
    "دورة": "تعليم", "كورس": "تعليم", "دروس": "تعليم", "قرطاسية": "تعليم",
    "education": "تعليم", "school": "تعليم", "books": "تعليم",
    # ── فواتير ──
    "فاتورة": "فواتير", "فواتير": "فواتير", "كهرباء": "فواتير", "ماء": "فواتير",
    "انترنت": "فواتير", "نت": "فواتير", "هاتف": "فواتير", "موبايل": "فواتير",
    "اشتراك": "فواتير", "تعبئة": "فواتير", "خط": "فواتير", "رصيد": "فواتير",
    "bills": "فواتير", "internet": "فواتير", "electricity": "فواتير",
    # ── سكن ──
    "إيجار": "سكن", "ايجار": "سكن", "سكن": "سكن", "بيت": "سكن",
    "صيانة بيت": "سكن", "نظافة": "سكن", "حارس": "سكن",
    "rent": "سكن", "housing": "سكن",
    # ── شخصي / عائلية (personal transfers) ──
    "اخوي": "شخصي", "أخوي": "شخصي", "أخي": "شخصي", "اخي": "شخصي",
    "أخوك": "شخصي", "اخوك": "شخصي", "اخوه": "شخصي", "أخوه": "شخصي",
    "أمي": "شخصي", "امي": "شخصي", "أبوي": "شخصي", "ابوي": "شخصي",
    "قريب": "شخصي", "قريبي": "شخصي", "عمي": "شخصي", "خالي": "شخصي",
    "صديق": "شخصي", "صديقي": "شخصي", "رفيقي": "شخصي", "زميل": "شخصي",
    "سلفة": "شخصي", "قرض": "شخصي", "اعطيت": "شخصي", "أعطيت": "شخصي",
    "عطيت": "شخصي",
    "personal": "شخصي", "family": "شخصي",
    # ── إيراد / راتب ──
    "راتبي": "إيراد", "راتب": "إيراد", "معاشي": "إيراد", "معاش": "إيراد",
    "مدخول": "إيراد", "ايراد": "إيراد", "إيراد": "إيراد", "ربح": "إيراد",
}

# ── Wallet hint detection from speech ──
_WALLET_HINTS = {
    "من الراتب": "salary", "من راتبي": "salary", "راتبي": "salary",
    "الراتب": "salary", "راتب": "salary", "معاش": "salary",
    "حساب بنكي": "bank", "من البنك": "bank", "البنك": "bank", "بنك": "bank",
    "تحت اليد": "cash", "فلوس تحت": "cash", "من الجيب": "cash", "من جيبي": "cash",
    "نقدي": "cash", "نقد": "cash", "فلوس": "cash", "كاش": "cash",
    "زين كاش": "zaincash", "من زين كاش": "zaincash", "من الزين": "zaincash",
    "ماستر كارت": "mastercard", "ماستركارت": "mastercard",
    "من الماستر": "mastercard", "من الكارت": "mastercard", "من البطاقة": "mastercard",
    "ماستر": "mastercard", "فيزا": "mastercard", "بطاقة": "mastercard",
}


def _detect_wallet_hint(text: str) -> str | None:
    """Detect wallet type from text, returning wallet_type string or None."""
    text_lower = text.lower()
    for keyword, wtype in sorted(_WALLET_HINTS.items(), key=lambda x: -len(x[0])):
        # Use regex word boundary to avoid false matches like "بنزين" matching "زين"
        pattern = r'(?:^|\s)' + re.escape(keyword) + r'(?:\s|$)'
        if re.search(pattern, text_lower):
            return wtype
    return None


def _parse_arabic_number(text: str) -> float | None:
    """Try to extract a number from Arabic text like 'ألفين' or 'خمس آلاف'."""
    text = text.strip()
    # Direct numeric
    try:
        return float(text.replace(",", ""))
    except ValueError:
        pass
    # Known Arabic word
    for phrase, val in sorted(_AR_NUMS.items(), key=lambda x: -len(x[0])):
        if phrase in text:
            return float(val)
    return None


def _detect_category(text: str) -> str:
    """Detect expense category from text."""
    text_lower = text.lower()
    for keyword, cat in _CATEGORY_MAP.items():
        if keyword in text_lower:
            return cat
    return "أخرى"


_INCOME_VERBS = re.compile(
    r'(?:استحصلت|استلمت|وصلني|حصلت على|حصلت\s+على|دخل|راتب|مدخول|ربحت|استلام|وردلي|نزل راتب|نزل\s+الراتب|ايراد|إيراد|مبلغ وارد)',
    re.UNICODE
)

# ── Multi-pass global patterns for expense parsing ──────────────
_VERB = (
    r'(?:تم\s+(?:صرف|دفع)|صرفت|دفعت|حسبت|شريت|اشتريت|'
    r'اعطيت|أعطيت|عطيت|سلفت|دفعنا|حولت|حجزت|استحصلت|استلمت)'
)
_AMT        = r'([\d,٫٬.]+)'
_CURR_NOISE = r'(?:\s*(?:دينار|دنانير|دن|دين|IQD|USD|دولار|elf|الف|ألف))?'
_PREP       = r'(?:لل|على|ل|في|الى|إلى|لـ|لِ|ال)?'
_W2         = r'([\u0600-\u06FFa-zA-Z]+)'

# Pass 1: verb → [مبلغ] → amount → [currency] → [prep] → 1-2 word desc
_P1 = re.compile(
    _VERB + r'\s*(?:مبلغ\s+|قيمة\s+)?' + _AMT + _CURR_NOISE + r'\s*' + _PREP + r'\s*' + _W2,
    re.UNICODE
)
# Pass 2: amount → [currency] → prep (required) → 1-2 word desc
_P2 = re.compile(
    _AMT + _CURR_NOISE + r'\s+(?:لل|على|ل|في|الى|إلى|لـ|لِ)\s*' + _W2,
    re.UNICODE
)


def parse_expenses_local(text: str) -> list[ParsedExpenseItem]:
    """
    Smart multi-expense parser using multi-pass global regex.
    Handles Arabic sentences with multiple expenses in one recording:
      "تم صرف مبلغ 5000 للتكسي وصرفت 3500 للغداء واعطيت 11000 دين لاخوي علي"
    Also handles:
      "صرفت 5000 على الأكل" | "تاكسي 2000 وأكل 3000" | "50,000 فاتورة كهرباء"
      "استلمت راتبي 500000 من البنك" (income)
    """
    global_wallet_hint = _detect_wallet_hint(text)
    global_entry_type = "income" if _INCOME_VERBS.search(text) else "expense"

    items: list[ParsedExpenseItem] = []
    seen: set[tuple[int, str]] = set()  # (rounded_amount, category) dedup

    def add(amount: float, cat: str, desc: str, match_ctx: str = "", conf: float = 0.8) -> None:
        key = (round(amount), cat)
        if key in seen or amount <= 0:
            return
        seen.add(key)
        ctx = match_ctx or text
        entry_type = "income" if _INCOME_VERBS.search(ctx) else "expense"
        wallet_hint = _detect_wallet_hint(ctx) or global_wallet_hint
        items.append(ParsedExpenseItem(
            amount=amount, currency="IQD", category_hint=cat,
            description=(desc or text)[:60],
            expense_date=date.today(), confidence=conf,
            wallet_hint=wallet_hint, entry_type=entry_type,
        ))

    # ─ Pass 1: verb + [مبلغ] + amount + [currency noise] + [prep] + 1-2 word desc ─
    # Works even when verb is attached to "و" (e.g., "وصرفت", "واعطيت") — no \b needed
    for m in _P1.finditer(text):
        amount = _parse_arabic_number(m.group(1))
        if not amount:
            continue
        desc = m.group(2).strip()
        cat = _detect_category(desc) if desc else "أخرى"
        if cat == "أخرى":
            cat = _detect_category(m.group(0))
        add(amount, cat, desc, m.group(0), 0.9)

    # ─ Pass 2: amount + prep (required) + 1-2 word desc ─
    for m in _P2.finditer(text):
        amount = _parse_arabic_number(m.group(1))
        if not amount:
            continue
        desc = m.group(2).strip()
        cat = _detect_category(desc) if desc else "أخرى"
        if cat == "أخرى":
            cat = _detect_category(m.group(0))
        add(amount, cat, desc, m.group(0), 0.8)

    # ─ Pass 3: category keyword ↔ digit amount (both orders) ─
    for keyword, cat in _CATEGORY_MAP.items():
        if keyword not in text.lower() and keyword not in text:
            continue
        # keyword then amount
        m = re.search(re.escape(keyword) + r'\s+([\d,٫٬.]+)', text, re.IGNORECASE | re.UNICODE)
        if m:
            amount = _parse_arabic_number(m.group(1))
            if amount:
                add(amount, cat, keyword, m.group(0), 0.75)
            continue
        # amount then keyword
        m = re.search(r'([\d,٫٬.]+)\s+' + re.escape(keyword), text, re.IGNORECASE | re.UNICODE)
        if m:
            amount = _parse_arabic_number(m.group(1))
            if amount:
                add(amount, cat, keyword, m.group(0), 0.75)

    # ─ Pass 4: Arabic number words + category keyword (whole-word match only) ─
    for keyword, cat in _CATEGORY_MAP.items():
        if keyword not in text:
            continue
        for num_word, num_val in sorted(_AR_NUMS.items(), key=lambda x: -len(x[0])):
            pat = r'(?:^|\s)' + re.escape(num_word) + r'(?:\s|$)'
            if re.search(pat, text, re.UNICODE):
                add(float(num_val), cat, keyword, "", 0.6)
                break

    # ─ Fallback: any digit number + full text as description ─
    if not items:
        for n in re.findall(r'[\d,٫٬.]+', text):
            amount = _parse_arabic_number(n)
            if amount and amount > 0:
                cat = _detect_category(text)
                add(amount, cat, text[:60], text, 0.5)

    return items

SYSTEM_PROMPT = """
You are an intelligent expense/income extraction assistant.
The user will provide text (in Arabic or English) describing their finances for the day.
Your job is to extract ALL mentioned transactions and return them as a JSON array.

Each object must have:
- "amount": number (positive float)
- "currency": string (use "IQD" if not mentioned)
- "category_hint": string (describe the category in the user's language — e.g., "أكل", "تاكسي", "صحة", "راتب", "شخصي")
- "description": string (short description in the original language)
- "expense_date": string in "YYYY-MM-DD" format (use today's date if not specified: {today})
- "confidence": float between 0 and 1
- "entry_type": "expense" or "income" — "income" only if the user received money (راتب, استلم, وصلني, ربح, ايراد); otherwise "expense"
- "wallet_hint": null or one of: "cash", "bank", "salary", "zaincash", "mastercard"
  Detect from: نقدي/كاش→cash, بنك/بطاقة→bank, راتب→salary, زين كاش→zaincash, ماستر→mastercard

Rules:
- Extract EACH distinct transaction as a separate object. "صرفت 5000 تاكسي وصرفت 3000 أكل" → 2 objects.
- "أعطيت X لـ Y" or "سلفت X لـ Y" → entry_type=expense, category_hint="شخصي"
- Amounts with دين/دينار after them are in IQD — strip that word before parsing.
- Always return a valid JSON array, even if empty: []
- Do NOT include markdown or explanation outside the JSON array.
- Handle mixed Arabic/English input naturally.
- Common Arabic words: أكل/طعام=food, تاكسي/مواصلات=transport, تسوق=shopping, صحة/دكتور=health, ترفيه=entertainment, فواتير/كهرباء=bills, إيجار=housing, تعليم=education, شخصي/أهل/أخ/صديق=personal
"""


async def transcribe_audio(audio_bytes: bytes, filename: str) -> str:
    """Convert audio bytes to text using Whisper."""
    import io
    audio_file = io.BytesIO(audio_bytes)
    audio_file.name = filename

    response = await client.audio.transcriptions.create(
        model="whisper-1",
        file=audio_file,
        language=None,  # Auto-detect Arabic/English
    )
    return response.text


async def parse_expenses_from_text(text: str) -> tuple[list[ParsedExpenseItem], str]:
    """
    Use GPT-4o to extract structured expenses from transcript.
    Returns (parsed_items, raw_gpt_response).
    """
    today_str = date.today().isoformat()
    system = SYSTEM_PROMPT.format(today=today_str)

    response = await client.chat.completions.create(
        model="gpt-4o",
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": text},
        ],
        temperature=0.1,
        max_tokens=1000,
    )

    raw = response.choices[0].message.content or "[]"

    try:
        data = json.loads(raw)
        items = []
        for item in data:
            amt = float(item.get("amount", 0))
            if amt <= 0:
                continue
            items.append(
                ParsedExpenseItem(
                    amount=amt,
                    currency=item.get("currency", "IQD"),
                    category_hint=item.get("category_hint", ""),
                    description=item.get("description", ""),
                    expense_date=date.fromisoformat(item.get("expense_date", today_str)),
                    confidence=float(item.get("confidence", 1.0)),
                    wallet_hint=item.get("wallet_hint"),
                    entry_type=item.get("entry_type", "expense"),
                )
            )
        return items, raw
    except (json.JSONDecodeError, KeyError, ValueError):
        return [], raw


# ═════════════════════════════════════════════════════════════════════════════
# ── Market Owner Voice Parsing ──────────────────────────────────────────────
# ═════════════════════════════════════════════════════════════════════════════

MARKET_SYSTEM_PROMPT = """
You are an intelligent assistant for a small grocery/market shop owner in Iraq.
The shop owner speaks Arabic (Iraqi colloquial — العامية العراقية — or Modern Standard Arabic),
and dictates credit-sale entries for their customers. Your job is to extract structured
sale records from the spoken text and return them as a JSON array.

Each object must have:
- "customer_name": string — the customer's name as the owner pronounced it (clean it: no titles like "السيد", no extra connectors). If the owner says only a nickname (e.g., "أبو علي", "أم محمد") keep it as said.
- "notes": string or null — VERY IMPORTANT: this is where ALL purchased products / items / goods go.
  Format the notes as a CLEAN multi-line list, one item per line. If a per-item price was spoken,
  include it after the product name with a colon. If no per-item price was given, just list the item.
  Examples of the EXACT format you must produce:
      "- زيت: 10000\n- تمن: 5000\n- ماي: 3000"
      "- خبز\n- حليب\n- بيض"
      "- بيبسي: 1500\n- عصير"
  Also include any extra context the owner mentioned on its own line (e.g., "- بضاعة", "- نسيئة لأسبوع").
  Use null ONLY if nothing besides the name and total amount was said.
- "amount": number — the sale total in IQD (Iraqi Dinar). Always positive.
    • If the owner spoke ONE single total (e.g., "ب 20 الف") use it directly.
    • If the owner spoke a price for EACH item separately (e.g., "زيت ب 10 الاف وتمن ب 5 الاف وماي ب 3 الاف"),
      SUM those per-item prices and put the SUM as "amount" (here: 18000). Always include the per-item
      prices in "notes" as shown above.
- "confidence": float between 0 and 1.

Rules:
- The owner may dictate MULTIPLE customers in one recording. Return one object per customer.
- The product list can appear BEFORE or AFTER the amount — capture it either way and put it in "notes":
  • "محمد اشترى زيت و تمن و ماي ب 20 الف"           → name=محمد, amount=20000, notes="- زيت\n- تمن\n- ماي"
  • "محمد اشترى ب 15 الف زين و ببسي و عصير"         → name=محمد, amount=15000, notes="- زين\n- ببسي\n- عصير"
  • "احمد اخذ خبز و حليب ب 8 الاف"                  → name=احمد, amount=8000, notes="- خبز\n- حليب"
  • "اكتبلي على علي 10 الاف سكر و شاي و رز"          → name=علي, amount=10000, notes="- سكر\n- شاي\n- رز"
  • "محمد اخذ زيت ب 10 الاف وتمن ب 5 الاف وماي ب 3 الاف" → name=محمد, amount=18000, notes="- زيت: 10000\n- تمن: 5000\n- ماي: 3000"
- Other Iraqi colloquial wording examples you MUST understand:
  • "اكتبلي على محمد عشرين الف خبز وحليب"
  • "احمد ابو علي اخذ بضاعة ب 25000"
  • "أم زينب جيرانه ديهنها 10 الاف"
  • "كتبلي على ابو سيف خمسين الف"
  • "محمد جابر علي 30 الف ومحمود علي 15 الف"
- Treat "الف" / "الاف" / "آلاف" / "elf" as thousands. "خمسين الف" = 50000. "عشر آلاف" = 10000. "ب 20 الف" = 20000.
- Treat "مية" / "ميه" / "مئة" as 100. "ميتين" = 200.
- "ونص" / "ون" = 0.5 → "الف ونص" = 1500, "بالف ونص" = 1500 (ب is the price marker), "خمسة الاف ونص" = 5500.
- "7:30" is a speech-recognition artifact for "سبعة ونص" → treat as 7500.
- "بالف" = ب (price marker) + الف (1000) → price = 1000. "بالف ونص" → 1500.
- "ديهنه" / "ديهنها" / "عليه" / "على" / "اخذ" / "اشترى" / "اشتره" / "كتبلي" / "حاسبلي" all indicate the customer owes the shop.
- The connector "ب" / "بـ" before a number means "for" (price). Treat as a separator, not part of a name.
- DO NOT put products into customer_name. Products are NEVER part of the customer name — they go in notes.
- If the owner says a customer paid (e.g., "دفع", "سدد", "ما عليه شي") — DO NOT return that as a sale. Skip it.
- Always return a valid JSON array, even if empty: []
- Do NOT include markdown or explanation outside the JSON array.
- Be tolerant of stutters, pauses, repetitions in the transcript. Extract intent, not literal text.
"""


def _normalize_arabic(s: str) -> str:
    """Strip diacritics and unify alef/yaa forms for matching."""
    if not s:
        return ""
    table = str.maketrans({
        "أ": "ا", "إ": "ا", "آ": "ا", "ى": "ي", "ة": "ه",
        "\u064b": "", "\u064c": "", "\u064d": "", "\u064e": "",
        "\u064f": "", "\u0650": "", "\u0651": "", "\u0652": "",
    })
    return s.translate(table).strip().lower()


def _match_existing_customer(name: str, customers: list) -> "tuple[uuid.UUID | None, bool]":
    """
    Try to match a parsed customer name against the shop's existing customer list.
    Returns (customer_id, is_new). Match is fuzzy: normalized substring in either direction.
    Exact normalized match wins over partial matches even if multiple partials exist.
    """
    import uuid as _uuid
    if not name or not customers:
        return None, True
    target = _normalize_arabic(name)
    if not target:
        return None, True
    # Exact normalized match first
    for c in customers:
        if _normalize_arabic(c.name) == target:
            return c.id, False
    # Otherwise: collect all partial matches
    partials = []
    for c in customers:
        cn = _normalize_arabic(c.name)
        if cn and (cn in target or target in cn):
            partials.append(c)
    if len(partials) == 1:
        return partials[0].id, False
    # >1 → ambiguous; let the UI ask the owner which one. Treat as "new" for now
    # so a fallback "create new customer" still works if the UI doesn't disambiguate.
    return None, True


def _find_candidates(name: str, customers: list) -> list:
    """Return the list of existing customers whose normalized name matches the
    spoken name as a substring in either direction. Used to disambiguate when
    the owner says just "علي" but multiple customers contain "علي"."""
    if not name or not customers:
        return []
    target = _normalize_arabic(name)
    if not target:
        return []
    # If exactly one is an exact match, no disambiguation needed.
    exact = [c for c in customers if _normalize_arabic(c.name) == target]
    if len(exact) == 1:
        return []
    partials = []
    for c in customers:
        cn = _normalize_arabic(c.name)
        if cn and (cn in target or target in cn):
            partials.append(c)
    return partials if len(partials) > 1 else []


def _parse_market_local(text: str, customers: list) -> list:
    """
    Improved fallback regex/heuristic parser for Iraqi market sales dictation.
    Handles:
      - Single total:     "محمد اشترى زيت ولبن ب 20 الف"
      - Per-item prices:  "محمد زيت ب 5000 ولبن بالف ونص ولحم ب 10,000"
                          → total = 16500, notes = "- زيت: 5000\n- لبن: 1500\n- لحم: 10000"
      - Multiple customers separated by ، / ثم / "و اسم فعل"
    """
    from app.schemas.market_voice import ParsedMarketSale

    PURCHASE_VERBS_RE = r'(?:اشترى|اشتره|اشترت|اشترا|اخذ|أخذ|اخذت|كتبلي|حاسبلي|ديهنه|ديهنها|اكتبلي|اكتب)'
    PAID_RE = r'\b(?:دفع|سدد|سددها|ما\s+عليه|خلص)\b'
    STOP_NAME = {
        'على', 'عليه', 'عليها', 'اكتبلي', 'كتبلي', 'حاسبلي',
        'اليوم', 'ب', 'بـ', 'من', 'في', 'ل', 'لـ',
    }

    # ── Numbers that represent fractions of 1000 (never get ×1000 in market context) ──
    _FRAC_WORDS = frozenset(['ربع', 'ربعه', 'ربعة', 'نص', 'نصف'])
    # ── Hundreds markers (words containing مية/مئة → already IQD hundreds, no ×1000) ──
    _MIA_RE = re.compile(r'(?:مية|مئة|ميه|مئه|مئتين|ميتين)')
    # ── Thousands markers ──
    _ALF_RE = re.compile(r'\b(?:الف|ألف|آلاف|الاف|الفين|ألفين|elf)\b', re.IGNORECASE)
    # ── Build a set of word numbers (value < 1000, no الف entries) for price matching ──
    _PRICE_WORDS = {k: v for k, v in _AR_NUMS.items() if 0 < v < 1000}

    def _price(s: str) -> "float | None":
        """Parse a price string in Iraqi market context.
        Bare word numbers 1-99 (without الف/مية qualifier) are treated as × 1000.
        Special: ربع=250, نص/نصف=500, ونص=+500, وربع=+250.
        All matching is done on normalized Arabic (ة→ه, أإآ→ا).
        """
        s = s.strip()
        if not s:
            return None
        # Strip leading price connector "ب" / "بـ" (attached or with space)
        s = re.sub(r'^بـ?\s*', '', s).strip()
        if not s:
            return None

        # Normalize once for all comparison operations
        sn = _normalize_arabic(s)

        # 1. Speech-recognition artifact: "7:30" → سبعة ونص → 7500
        m = re.fullmatch(r'(\d+):(\d{2})', s)
        if m:
            major, minor = int(m.group(1)), int(m.group(2))
            return float(major * 1000 + (500 if minor in (30, 50) else minor * 10))

        # 2. Digits + optional الف + optional ونص/وربع
        m = re.match(
            r'^([\d,٫٬]+(?:\.\d+)?)\s*'
            r'(الف|الف|الاف|الاف|elf)?'
            r'(\s*ونص|\s*وربع)?$', sn, re.IGNORECASE)
        if m:
            try:
                val = float(m.group(1).replace(',', '').replace('٫', '').replace('٬', ''))
                if m.group(2):
                    val *= 1000
                if m.group(3):
                    val += 500 if 'ونص' in (m.group(3) or '') else 250
                return val if val > 0 else None
            except ValueError:
                pass

        # 3. Fraction shortcuts: ربع=250, نص/نصف=500
        sn0 = sn.split()[0] if sn.split() else ''
        if sn0 in ('ربع', 'ربعه', 'ربعة'):
            return 250.0
        if sn0 in ('نص', 'نصف'):
            return 500.0

        # 4. Pure thousands prefix: الف, الفين, الاف alone (match normalized)
        if re.match(r'^(?:الف|الفين|الاف)(?:\s+ونص|\s+وربع)?$', sn, re.IGNORECASE):
            base = 2000.0 if sn.startswith('الفين') else 1000.0
            if 'ونص' in sn: base += 500
            if 'وربع' in sn: base += 250
            return base

        # 5. Word-number parsing (normalize both key and input for matching)
        val = 0.0
        found = False
        for word, num in sorted(_PRICE_WORDS.items(), key=lambda x: -len(x[0])):
            word_n = _normalize_arabic(word)
            if re.search(r'(?:^|\s)' + re.escape(word_n) + r'(?:\s|$)', sn, re.IGNORECASE):
                val += float(num)
                found = True

        has_alf = bool(re.search(r'\b(?:الف|الاف|الفين)\b', sn, re.IGNORECASE))
        has_mia = bool(_MIA_RE.search(sn))
        is_frac = sn0 in _FRAC_WORDS

        if has_alf:
            if sn.startswith('الفين'):
                val = 2000.0
            else:
                val = val * 1000 if found else 1000.0
            found = True
        elif found and not has_mia and not is_frac and 1 <= val <= 99:
            # Bare word number in Iraqi market context → implied thousands
            # (e.g., ثلاثه=3 → 3000, عشرين=20 → 20000, خمصطعش=15 → 15000)
            val *= 1000
        # val stays as-is if has_mia (hundreds: ميه=100, خمسميه=500, etc.)
        # or if it's a fraction word (ربع=250, نص=500)

        # Apply ونص (+500) and وربع (+250) suffixes
        if 'ونص' in sn:
            val += 500
            found = True
        if 'وربع' in sn:
            val += 250
            found = True

        return val if found and val > 0 else None

    # ── helper: build a regex that matches a price token at end of string ──────
    # Use NORMALIZED keys so dialect input (ثلاثه, اربعه, سته) matches correctly
    _PRICE_WORD_NORM_ALT = '|'.join(
        re.escape(_normalize_arabic(w)) for w in sorted(_AR_NUMS, key=len, reverse=True)
        if _AR_NUMS[w] >= 1
    )
    _END_PRICE_RE = re.compile(
        r'\s+('
        # digits + optional الف + optional ونص/وربع
        r'[\d,٫٬]+(?:[:.]\d+)?(?:\s*(?:الف|الاف|الفين))?(?:\s*ونص|\s*وربع)?'
        r'|'
        # pure الف/الفين alone + optional ونص
        r'(?:الف|الفين|الاف)(?:\s+ونص|\s+وربع)?'
        r'|'
        # normalized word number + optional الف + optional ونص/وربع
        r'(?:' + _PRICE_WORD_NORM_ALT + r')(?:\s+(?:الف|الاف|الفين))?(?:\s+ونص|\s+وربع)?'
        r')$',
        re.IGNORECASE
    )

    # ── helper: parse "item_name ب price" segment ────────────────────────────
    def _item_price(seg: str) -> "tuple[str, float | None]":
        """Return (item_name, price_or_None) for one item segment.
        Tries in order:
          1. name + \" ب \" + price  (explicit ب with spaces)
          2. name + \" بWORD\"        (ب attached to word: بثلاثه, بالف, بخمسه ونص)
          3. name + PRICE_AT_END     (price words at segment end, no ب marker)
        All matching done on normalized Arabic forms.
        """
        seg = seg.strip()
        seg_n = _normalize_arabic(seg)  # normalized version for matching

        # 1. Explicit "name ب price" — space on both sides of ب
        m = re.match(r'^(.+?)\s+ب\s+(.+)$', seg)
        if m:
            p = _price(m.group(2))
            if p:
                return m.group(1).strip(), p

        # 2. "name بWORD" — ب attached directly to an Arabic word price
        # Handles: "بثلاثه", "بالف", "بخمسه ونص", "بالف ونص"
        m = re.match(
            r'^(.+?)\s+(ب[\u0600-\u06FF][\u0600-\u06FF\s]*?(?:ونص|وربع)?)$',
            seg)
        if m:
            price_str = m.group(2)[1:]  # strip leading ب
            p = _price(price_str)
            if p:
                return m.group(1).strip(), p

        # 3. Price at END of segment (no ب marker) — search on normalized form
        # Handles: "لبن اربعه ونص" → لبن: 4500, "زيت عشرين الف" → زيت: 20000
        m = _END_PRICE_RE.search(seg_n)
        if m and m.start() > 0:
            p = _price(seg_n[m.start() + 1:])  # pass normalized price string
            if p:
                item_name = seg[:m.start()].strip()  # return original item name
                if item_name:
                    return item_name, p

        return seg, None

    # ── Split text into per-customer chunks ──────────────────────────────────
    CUST_SEP = re.compile(
        r'\s*ثم\s*'
        r'|[،,]'
        r'|\.\s+'
        r'|\s+و\s+(?=[ا-ي]{2,5}\s+(?:' + PURCHASE_VERBS_RE[3:-1] + r'))'  # و احمد اشترى
        r'|\s+و\s+(?=[ا-ي]{2,5}\s+\d)'                                       # و احمد 5000
        r'|\s+و\s+(?=[ا-ي]{2,5}\s+(?:الف|ألف|خمس|عشر|ميه|مية|ميتين))'      # و احمد عشرين الف
    )
    chunks = CUST_SEP.split(text)

    items: list[ParsedMarketSale] = []

    for chunk in chunks:
        chunk = chunk.strip()
        if not chunk or re.search(PAID_RE, chunk):
            continue

        # ── Extract customer name ─────────────────────────────────────────────
        verb_m = re.search(r'^((?:[ا-ي]+(?:\s+[ا-ي]+){0,2})\s+)(?:' + PURCHASE_VERBS_RE[3:-1] + r')\s*', chunk)
        if verb_m:
            name_raw = verb_m.group(1).strip()
            rest = chunk[verb_m.end():].strip()
        else:
            # First 1-3 Arabic words before a digit or price word
            m_n = re.match(
                r'^((?:[ا-ي]+(?:\s+[ا-ي]+){0,2})?)\s*'
                r'(?=[\d,٫٬]|الف|ألف|خمس|عشر|ميه|مية|ميتين|ب\s*[\d])',
                chunk)
            if m_n and m_n.group(1).strip():
                name_raw = m_n.group(1).strip()
                rest = chunk[len(m_n.group(0)):].strip()
            else:
                words = chunk.split()
                name_raw = words[0] if words else ''
                rest = ' '.join(words[1:])

        # Clean name
        name_words = [
            w for w in name_raw.split()
            if _normalize_arabic(w) not in {_normalize_arabic(x) for x in STOP_NAME}
        ]
        # Handle "ابو علي", "أم زينب" (keep 2 words for these prefixes)
        if name_words and name_words[0] in {'ابو', 'أبو', 'ام', 'أم'}:
            name = ' '.join(name_words[:2])
        else:
            name = ' '.join(name_words[:2]).strip()

        if not name:
            continue

        # ── Try per-item price mode ───────────────────────────────────────────
        # Split rest on " و " separators
        segs = re.split(r'\s+و\s+', rest) if rest else []

        # Remove leading price connector from entire rest if no items at all
        # (pattern: "ب 20 الف" with no item name)
        if len(segs) == 1 and re.match(r'^(?:ب\s*|على\s*)', segs[0]):
            segs[0] = re.sub(r'^(?:ب\s*|على\s*)', '', segs[0])

        pair_list: "list[tuple[str, float | None]]" = []
        for seg in segs:
            seg = seg.strip()
            if not seg:
                continue
            item_n, item_p = _item_price(seg)
            pair_list.append((item_n, item_p))

        priced = [(n, p) for n, p in pair_list if p is not None and p > 0]
        unpriced = [(n, p) for n, p in pair_list if p is None or p <= 0]

        if len(priced) > 1:
            # ── Multiple items with individual prices → sum ───────────────────
            total = sum(p for _, p in priced)
            note_lines = [f"- {n}: {int(p)}" for n, p in priced]
            for n, _ in unpriced:
                if n and len(n) > 1:
                    note_lines.append(f"- {n}")
            notes: "str | None" = '\n'.join(note_lines)

        elif len(priced) == 1 and not unpriced:
            # Single item = its price is the total; no notes needed
            total = priced[0][1]
            notes = None

        else:
            # ── Single total mode (no per-item prices or ambiguous) ───────────
            total = None

            # First: try treating the whole rest as a price expression
            # Handles: "ربع", "سته ونص", "خمسميه", "الف ونص", etc.
            total = _price(rest or '')

            # Second: look for a digit-based amount in rest
            if not total:
                amt_m = re.search(
                    r'(?:ب\s*)?([\d,٫٬]+(?:[:.]\d+)?)\s*'
                    r'(الف|ألف|آلاف|الاف|elf)?(?:\s*ونص)?',
                    rest or '', re.IGNORECASE)
                if amt_m:
                    total = _price(
                        (amt_m.group(1) or '') + (' ' + (amt_m.group(2) or '') if amt_m.group(2) else '') +
                        (' ونص' if 'ونص' in (rest or '') else ''))
            if not total:
                for word, num in sorted(_AR_NUMS.items(), key=lambda x: -len(x[0])):
                    m_w = re.search(
                        r'(?:^|\s)' + re.escape(_normalize_arabic(word)) + r'(?:\s+(?:الف|الاف|الفين))?',
                        _normalize_arabic(rest or ''))
                    if m_w:
                        total = float(num) * (1000 if m_w.group(1) else 1)
                        if 'ونص' in (rest or ''):
                            total += 500
                        break
            if not total or total <= 0:
                continue

            # Build notes from all item segments (excluding price tokens)
            PRICE_STOP = {
                'الف', 'ألف', 'آلاف', 'الاف', 'elf', 'دينار', 'ب', 'بـ',
                'ل', 'لـ', 'من', 'في', 'الى', 'إلى', 'هذا', 'هذه',
                'هاي', 'هاد', 'اليوم', 'ونص',
            }
            # Rebuild rest without digits / الف forms
            clean = re.sub(r'[\d,٫٬.:]+', ' ', rest or '')
            clean = re.sub(r'\b(?:الف|ألف|آلاف|الاف|elf)\b', ' ', clean, re.IGNORECASE)
            clean = re.sub(r'(?:^|\s)بـ?(?=\s|$)', ' ', clean)
            for word in sorted(_AR_NUMS.keys(), key=len, reverse=True):
                clean = re.sub(r'(?:^|\s)' + re.escape(word) + r'(?:\s|$)', ' ', clean)
            toks: list[str] = []
            seen: set[str] = set()
            for t in re.split(r'\s+', clean):
                if len(t) < 2:
                    continue
                k = _normalize_arabic(t)
                if k in seen or k in {_normalize_arabic(s) for s in PRICE_STOP}:
                    continue
                seen.add(k)
                toks.append(t)
            notes = '\n'.join(f'- {t}' for t in toks) if toks else None

        cust_id, is_new = _match_existing_customer(name, customers)
        cands = _find_candidates(name, customers)
        cand_list = [{"id": c.id, "name": c.name} for c in cands]
        items.append(ParsedMarketSale(
            customer_name=name,
            customer_id=cust_id,
            is_new_customer=is_new,
            amount=float(total),
            notes=notes,
            confidence=0.65,
            candidates=cand_list,
        ))
    return items


async def parse_market_sales_from_text(text: str, customers: list) -> "tuple[list, str]":
    """
    Use GPT-4o to extract structured market sales from a dictation transcript.
    `customers` is a list of MarketCustomer ORM objects for the current owner — used
    to match parsed names to existing customer IDs.
    Returns (parsed_sales, raw_response).
    """
    from app.schemas.market_voice import ParsedMarketSale

    # Local fallback when OpenAI key missing
    if not settings.OPENAI_API_KEY or settings.OPENAI_API_KEY.startswith("sk-placeholder"):
        return _parse_market_local(text, customers), "local"

    try:
        response = await client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {"role": "system", "content": MARKET_SYSTEM_PROMPT},
                {"role": "user", "content": text},
            ],
            temperature=0.1,
            max_tokens=800,
        )
        raw = response.choices[0].message.content or "[]"
    except Exception:
        return _parse_market_local(text, customers), "fallback"

    # Strip code fences if model wrapped output
    cleaned = raw.strip()
    if cleaned.startswith("```"):
        cleaned = re.sub(r'^```(?:json)?\s*', '', cleaned)
        cleaned = re.sub(r'\s*```$', '', cleaned)

    try:
        data = json.loads(cleaned)
        if not isinstance(data, list):
            return [], raw
        items: list[ParsedMarketSale] = []
        for item in data:
            try:
                amt = float(item.get("amount", 0))
            except (TypeError, ValueError):
                continue
            if amt <= 0:
                continue
            name = (item.get("customer_name") or "").strip()
            if not name:
                continue
            cust_id, is_new = _match_existing_customer(name, customers)
            cands = _find_candidates(name, customers)
            cand_list = [{"id": c.id, "name": c.name} for c in cands]
            items.append(ParsedMarketSale(
                customer_name=name,
                customer_id=cust_id,
                is_new_customer=is_new,
                amount=amt,
                notes=(item.get("notes") or None) or None,
                confidence=float(item.get("confidence", 0.9)),
                candidates=cand_list,
            ))
        return items, raw
    except (json.JSONDecodeError, KeyError, ValueError):
        # Fall back to local on parse failure
        return _parse_market_local(text, customers), raw


async def transcribe_audio_for_market(audio_bytes: bytes, filename: str) -> str:
    """
    Whisper transcription tuned for Iraqi market dictation.
    Uses an Arabic prompt to bias the model towards common shop-keeping vocabulary,
    which improves recognition of customer names and amounts spoken in dialect.
    """
    import io
    audio_file = io.BytesIO(audio_bytes)
    audio_file.name = filename
    response = await client.audio.transcriptions.create(
        model="whisper-1",
        file=audio_file,
        language="ar",
        prompt=(
            "تسجيل لصاحب محل بقالة عراقي يملي ديون زبائنه. "
            "أسماء أشخاص (محمد، أحمد، علي، حسين، فاطمة، أم زينب، أبو علي) ومبالغ بالدينار العراقي. "
            "الف، آلاف، خمسين الف، عشرة الاف، ميتين الف، مليون."
        ),
        temperature=0.0,
    )
    return response.text


# ═════════════════════════════════════════════════════════════════════════════
# ── Market Vision (Image Analysis) ──────────────────────────────────────────
# ═════════════════════════════════════════════════════════════════════════════

VISION_SYSTEM_PROMPT = """
You are an expert product-recognition assistant for an Iraqi grocery / supermarket
shop owner. You will receive a photo from the shop. The photo may contain:
  - one or more physical products on a counter, shelf, or in a bag
  - a handwritten note listing products
  - a printed receipt
  - a screenshot of a shopping list

Your job: identify EVERY product visible (even if only ONE item is in the photo)
and return a JSON array. NEVER return an empty array if any product, package, brand,
or written word is visible — always extract at least the visible item.

═══════════════════════════════════════════════════════════════════════════
  ⚠ IMPORTANT: There are THOUSANDS of products in an Iraqi market. The
  list below is JUST EXAMPLES, NOT a closed catalog. You MUST also
  recognize ANY product even if it is not in the list — including unknown
  brands, niche items, imported items, regional brands, and new releases.
  For unfamiliar packaging:
    • Read the brand from the label (Arabic, English, Turkish, Persian).
    • Read the product type from icons / pictures on the package.
    • Read the size, weight, volume, or piece-count from the front label.
    • Build a clear Arabic product_name like
        "<brand> <product-type> <size>"  (e.g. "هاي بسكويت 50غرام").
    • If brand is unreadable but type is clear → name by category + size
        (e.g. "شامبو 400مل", "بسكويت سادة", "كيس أرز 5كغ").
    • Estimate a reasonable Iraqi retail price for unknown items.
═══════════════════════════════════════════════════════════════════════════

PRODUCT CATEGORIES YOU MUST RECOGNIZE WELL (Iraqi market staples — examples only):
• Soft drinks / juices: بيبسي, كوكا كولا, سبايت, ميريندا, 7 Up, رواني, برتقال, تفاح, عصير راني, عصير سنتوب …
• Water bottles: جبل صافي, صفا, سباركل … (ماء 250مل / 500مل / 1.5ل / 5ل / جالون)
• Energy drinks: ريد بول, بول شارك, تايغر, تين بوي …
• Dairy / eggs: حليب نيدو, حليب لاكتيل, لبن, جبن كيري, زبدة, بيض …
• Snacks / chips: لايز, چيتوس, دوريتوس, برينجلز, مرتديلا, بوب كورن …
• Chocolate & sweets: كدبري, سنيكرز, مارس, بونجو, كت كات, توفف, بسكوت, حلوى …
• Tea & coffee: شاي الغزالين, شاي لبتون, نسكافيه, قهوة تركية, نس كافي جولد …
• Bakery & grains: خبز, صمون, ارز بسمتي, رز العروس, طحين, برغل, عدس, حمص, فول …
• Oils & condiments: زيت صافية, زيت دوار الشمس, سكر, ملح, فلفل, كاتشاب حينز, مايونيز, خل …
• Canned goods: تونة, رب طماطة, فول مدمس, حمص بصلصة …
• Hygiene / personal care: صابون, شامبو, فرشاة أسنان, معجون أسنان (سيغنال, كولغيت), فوط صحية, حفاضات …
• Tissues / paper: مناديل لورد, كلينكس, فاين, بيبي فاين, ورق تواليت …
• Cleaning / detergents: تايد سائل, أريال, داوني, فيري, ليزول, جلادي, كلوروكس, مبيضات …
• Plastic bags / disposables: أكياس, صحون بلاستك, كوب بلاستك, سفرة …
• Cigarettes / tobacco: مارلبورو, غروين, وينستون, سبتر …
• Fresh produce: طماطة, بصل, بطاطا, خيار, باذنجان, تفاح, موز, برتقال …
• Meat / proteins (if visible): دجاج, لحم, أسماك …
• Stationery / school: دفتر, قلم, مسطرة, براية …

Each object MUST have:
- "product_name": string — Arabic name preferred by Iraqi shop customers.
  • Read brand names and product type from the packaging in ANY language
    visible on the label (Arabic, English, Turkish, Persian, Kurdish).
  • ALWAYS try to read and INCLUDE the packaging detail in the name:
        size (250مل / 500مل / 1لتر / 5لتر),
        weight (50غرام / 250غرام / 1كغ / 5كغ),
        piece count (10 قطع / علبة 24 / كرتون 12),
        flavor / variant (شوكلاتة, فراولة, دايت, لايت).
  • Example formats:
        "مناديل لورد 150 منديل", "شاي الغزالين 450غرام",
        "بيبسي 1 لتر", "حليب نيدو 400غرام", "زيت صافية 1.8 لتر",
        "بسكويت اوريو 60غرام", "كاتشاب حينز 460غرام".
  • If the brand is unreadable but the type is clear, name by category + size:
        "بسكويت سادة 50غ", "شامبو 400مل", "كيس أرز 5كغ".
  • If even the type is unclear, describe what you see honestly:
        "علبة كرتون بنية اللون 250غ", "قنينة بلاستك 1لتر سائل أزرق".
- "quantity": number — how many UNITS of that product are visible. Default 1.
- "unit_price": number — estimated price in Iraqi Dinar (IQD).
  • If a price tag is visible, read it.
  • If the owner has previously sold the same product (provided to you), use
    THE OWNER'S OWN PRICE (sent as "سعر سابق"). This is the most important rule:
    the owner's learned price ALWAYS overrides any market estimate.
  • Otherwise estimate a reasonable Iraqi retail price.
  • If unsure, use 0 — the shop owner will edit it.

Rules:
- Return ONLY a valid JSON array. No markdown fences, no explanation, no leading/trailing text.
- Do NOT return an empty array unless the image is completely blank/blurry beyond recognition.
- Be concrete: a clearly-visible packet of tissues is "مناديل + brand", not "غرض غير معروف".
- Prefer the EXACT product_name from "المنتجات المعروفة" when there is a clear match —
  this keeps the owner's records consistent for statistics.
"""


def _normalize_product_key(name: str) -> str:
    """Loose normalization used to match a vision-returned product to a learned one."""
    if not name:
        return ""
    s = name.strip().lower()
    # Arabic letter variants → canonical
    table = str.maketrans({
        "أ": "ا", "إ": "ا", "آ": "ا",
        "ى": "ي", "ئ": "ي",
        "ؤ": "و",
        "ة": "ه",
    })
    s = s.translate(table)
    # Strip Arabic diacritics + tatweel
    s = re.sub(r"[\u064b-\u0652\u0670\u0640]", "", s)
    # Collapse whitespace and drop non-alnum
    s = re.sub(r"[\s\-_/\\.\,]+", " ", s).strip()
    return s


async def analyze_image_for_market_items(
    image_bytes: bytes,
    mime_type: str,
    known_products: "list[str] | list[dict] | None" = None,
) -> "tuple[list[dict], str]":
    """
    Use GPT-4o vision (preferred) or Gemini 1.5 Flash (fallback) to identify products.

    `known_products` may be either:
      - a list of strings (legacy)  — just product names previously sold, OR
      - a list of dicts             — {name, last_price, avg_price, count}.

    When the dict form is supplied, the function will:
      1. Tell the model the owner's previously-charged price (so it learns).
      2. Post-process the model output: if a returned product matches a known one
         (loose Arabic normalization), override `unit_price` with the owner's
         most recent price for that product.
    Returns (items_list, raw_response).
    """
    import base64

    has_openai = settings.OPENAI_API_KEY and not settings.OPENAI_API_KEY.startswith("sk-placeholder")
    gemini_key = (
        getattr(settings, "GEMINI_API_KEY", None)
        or getattr(settings, "GOOGLE_API_KEY", None)
    )
    has_gemini = bool(gemini_key)

    if not has_openai and not has_gemini:
        return [], "no-api-key"

    b64 = base64.b64encode(image_bytes).decode("utf-8")

    # Build the learned-products section + lookup table for override
    learned_lookup: dict[str, dict] = {}
    known_section_lines: list[str] = []
    if known_products:
        for entry in known_products[:80]:
            if isinstance(entry, str):
                key = _normalize_product_key(entry)
                if key and key not in learned_lookup:
                    learned_lookup[key] = {"name": entry.strip(), "last_price": None}
                    known_section_lines.append(f"- {entry.strip()}")
            elif isinstance(entry, dict):
                name = (entry.get("name") or "").strip()
                if not name:
                    continue
                key = _normalize_product_key(name)
                if not key or key in learned_lookup:
                    continue
                last_price = entry.get("last_price")
                learned_lookup[key] = {"name": name, "last_price": last_price}
                if last_price:
                    known_section_lines.append(f"- {name}  | سعر سابق: {last_price:g} د.ع")
                else:
                    known_section_lines.append(f"- {name}")

    user_text = "حلل الصورة واستخرج قائمة المنتجات بالتنسيق المطلوب (JSON array فقط)."
    if known_section_lines:
        user_text += (
            "\n\nالمنتجات المعروفة (باعها صاحب المحل سابقاً — إذا طابقت استخدم نفس الاسم ونفس السعر):\n"
            + "\n".join(known_section_lines)
        )

    raw = ""
    # ── Try OpenAI first ──
    if has_openai:
        data_url = f"data:{mime_type};base64,{b64}"
        try:
            response = await client.chat.completions.create(
                model="gpt-4o",
                messages=[
                    {"role": "system", "content": VISION_SYSTEM_PROMPT},
                    {
                        "role": "user",
                        "content": [
                            {"type": "image_url", "image_url": {"url": data_url, "detail": "high"}},
                            {"type": "text", "text": user_text},
                        ],
                    },
                ],
                temperature=0.2,
                max_tokens=900,
            )
            raw = response.choices[0].message.content or "[]"
        except Exception as e:
            raw = f"openai-error: {str(e)[:200]}"
            if not has_gemini:
                return [], raw

    # ── Fallback to Gemini if OpenAI failed or absent ──
    if (not raw or raw.startswith("openai-error")) and has_gemini:
        import httpx
        # Try multiple model names — Google rotates availability.
        gemini_models = [
            "gemini-2.5-flash",
            "gemini-2.0-flash",
            "gemini-2.0-flash-001",
            "gemini-1.5-flash-latest",
            "gemini-1.5-flash",
            "gemini-flash-latest",
        ]
        payload = {
            "systemInstruction": {"parts": [{"text": VISION_SYSTEM_PROMPT}]},
            "contents": [
                {
                    "parts": [
                        {"inline_data": {"mime_type": mime_type, "data": b64}},
                        {"text": user_text},
                    ]
                }
            ],
            "generationConfig": {
                "temperature": 0.2,
                "maxOutputTokens": 900,
                "responseMimeType": "application/json",
            },
        }
        last_err = ""
        gem_data = None
        async with httpx.AsyncClient(timeout=60.0) as http:
            for model in gemini_models:
                url = (
                    f"https://generativelanguage.googleapis.com/v1beta/models/"
                    f"{model}:generateContent?key={gemini_key}"
                )
                try:
                    r = await http.post(url, json=payload)
                    if r.status_code == 404:
                        last_err = f"404 on {model}"
                        continue
                    r.raise_for_status()
                    gem_data = r.json()
                    break
                except Exception as e:
                    last_err = f"{model}: {str(e)[:100]}"
                    continue
        if gem_data is None:
            return [], f"gemini-error: {last_err or 'all models failed'}"
        try:
            parts = (
                gem_data.get("candidates", [{}])[0]
                .get("content", {})
                .get("parts", [])
            )
            raw = "".join(p.get("text", "") for p in parts) or "[]"
        except Exception as e:
            return [], f"gemini-parse-error: {str(e)[:200]}"

    cleaned = raw.strip()
    if cleaned.startswith("```"):
        cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned)
        cleaned = re.sub(r"\s*```$", "", cleaned)

    try:
        data = json.loads(cleaned)
        if not isinstance(data, list):
            return [], raw
        items = []
        for item in data:
            name = (item.get("product_name") or "").strip()
            if not name:
                continue
            try:
                qty = float(item.get("quantity", 1) or 1)
                price = float(item.get("unit_price", 0) or 0)
            except (TypeError, ValueError):
                qty, price = 1.0, 0.0

            # ── Price-learning override ─────────────────────────────────
            # If this product matches one the owner sold before, prefer
            # their most recently charged price + their canonical name.
            key = _normalize_product_key(name)
            learned = learned_lookup.get(key) if key else None
            if learned is None and key:
                # Loose substring match (covers "بيبسي 1 لتر" vs "بيبسي")
                for lk, lv in learned_lookup.items():
                    if lk and (lk in key or key in lk) and min(len(lk), len(key)) >= 3:
                        learned = lv
                        break
            if learned:
                name = learned.get("name") or name
                lp = learned.get("last_price")
                if lp and lp > 0:
                    price = float(lp)

            items.append({"product_name": name, "quantity": qty, "unit_price": price})
        return items, raw
    except (json.JSONDecodeError, KeyError, ValueError):
        return [], raw


def _local_insights(monthly_summary: dict) -> str:
    """Generate simple local insights without OpenAI."""
    total = monthly_summary.get("total", 0)
    categories = monthly_summary.get("categories", [])
    count = monthly_summary.get("count", 0)

    tips = []

    if total == 0:
        return "لا توجد مصاريف مسجلة لهذا الشهر. ابدأ بتسجيل مصاريفك لمتابعة إنفاقك!"

    tips.append(f"• إجمالي إنفاقك هذا الشهر: {total:,.0f} عبر {count} عملية.")

    if categories:
        top = categories[0]
        tips.append(f"• أعلى فئة إنفاق: {top['name']} بمبلغ {top['total']:,.0f} ({top['percentage']}% من الإجمالي).")

        if len(categories) >= 2:
            second = categories[1]
            tips.append(f"• ثاني أعلى فئة: {second['name']} بمبلغ {second['total']:,.0f} ({second['percentage']}%).")

        if top["percentage"] > 50:
            tips.append(f"• تنبيه: فئة \"{top['name']}\" تستهلك أكثر من نصف ميزانيتك. حاول تقليلها.")

    if count > 0:
        avg = total / count
        tips.append(f"• متوسط المصروف الواحد: {avg:,.0f}.")

    tips.append("• نصيحة: حدد ميزانية شهرية لكل فئة لتتحكم بإنفاقك بشكل أفضل.")

    return "\n".join(tips)


async def generate_spending_insights(monthly_summary: dict) -> str:
    """
    Generate Arabic spending tips based on the user's monthly summary.
    Falls back to local analysis if OpenAI key is not configured.
    """
    # Use local insights if no real API key
    if not settings.OPENAI_API_KEY or settings.OPENAI_API_KEY.startswith("sk-placeholder"):
        return _local_insights(monthly_summary)

    prompt = f"""
    Based on this user's monthly spending summary, provide 3-5 concise and practical financial tips in Arabic.
    Be friendly, encouraging, and specific to the actual spending patterns.
    
    Monthly summary:
    {json.dumps(monthly_summary, ensure_ascii=False, indent=2)}
    
    Reply in Arabic only. Use short bullet points. Be supportive not judgmental.
    """

    try:
        response = await client.chat.completions.create(
            model="gpt-4o",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.7,
            max_tokens=500,
        )
        return response.choices[0].message.content or ""
    except Exception:
        return _local_insights(monthly_summary)
