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
    "مية": 100, "مئة": 100, "ميتين": 200, "مئتين": 200,
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
