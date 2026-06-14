import sys, re, types, unittest.mock as mock

for mod_name in ["openai","pydantic_settings","pydantic","sqlalchemy","aiosqlite","fastapi","jose","passlib","multipart"]:
    sys.modules[mod_name] = mock.MagicMock()

amounts_seen = []

class FakeSale:
    def __init__(self, **kw):
        self.__dict__.update(kw)
        amounts_seen.append(kw.get("amount"))

app_mod = types.ModuleType("app")
app_schemas = types.ModuleType("app.schemas")
app_schemas_mv = mock.MagicMock()
app_schemas_mv.ParsedMarketSale = FakeSale
app_config = mock.MagicMock()
app_config.settings = mock.MagicMock(OPENAI_API_KEY="sk-x")
sys.modules["app"] = app_mod
sys.modules["app.config"] = app_config
sys.modules["app.schemas"] = app_schemas
sys.modules["app.schemas.voice"] = mock.MagicMock()
sys.modules["app.schemas.market_voice"] = app_schemas_mv

import importlib.util
spec = importlib.util.spec_from_file_location("ai_service", "app/services/ai_service.py")
ai_mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ai_mod)

class C:
    def __init__(self, n):
        self.name = n
        self.id = None
        self.phone_number = None

TESTS = [
    ("احمد خمسميه", [C("احمد")], 500),
    ("علي سته ونص", [C("علي")], 6500),
    ("احمد اشترى روبه ب 5000 ولبن اربعه ونص وزيت بثلاثه", [C("احمد")], 12500),
    ("خالد ارز خمصطعش ونص", [C("خالد")], 15500),
    ("محمد الف ونص", [C("محمد")], 1500),
    ("احمد ربع", [C("احمد")], 250),
    ("محمد بثلاثه", [C("محمد")], 3000),
    ("سعد اشترى زيت بالف ونص", [C("سعد")], 1500),
    ("علي اشترى لحم ب 10000 وخضار اربعه", [C("علي")], 14000),
]

print("=" * 60)
for text, custs, expected in TESTS:
    amounts_seen.clear()
    try:
        results = ai_mod._parse_market_local(text, custs)
        got = results[0].amount if results else None
        status = "PASS" if got == expected else "FAIL"
        print(f"{status} | expected={expected} got={got} | {text!r}")
        if got != expected:
            print(f"       amounts_seen during call: {amounts_seen}")
    except Exception as e:
        import traceback
        print(f"ERROR | {text!r}: {e}")
        traceback.print_exc()
print("=" * 60)
