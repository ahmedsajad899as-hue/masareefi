# مصاريفي — Masareefi

**تطبيق تتبع المصاريف اليومية بالذكاء الاصطناعي والإدخال الصوتي**

---

## هيكل المشروع

```
daily routine/
├── backend/                    ← Python + FastAPI
│   ├── app/
│   │   ├── main.py             ← نقطة الدخول
│   │   ├── config.py           ← إعدادات البيئة
│   │   ├── database.py         ← SQLAlchemy async
│   │   ├── models/             ← نماذج قاعدة البيانات
│   │   ├── schemas/            ← Pydantic schemas
│   │   ├── routers/            ← API endpoints
│   │   ├── services/           ← منطق الأعمال (AI + Stats)
│   │   └── utils/              ← JWT, hashing, dependencies
│   ├── alembic/                ← Database migrations
│   ├── requirements.txt
│   ├── Dockerfile
│   └── .env.example
└── docker-compose.yml
```

---

## إعداد البيئة (Backend)

### 1. نسخ ملف البيئة
```bash
cd backend
cp .env.example .env
```

ثم عدّل `.env` بقيمك الحقيقية:
- `DATABASE_URL` — رابط PostgreSQL
- `SECRET_KEY` — مفتاح JWT (أي سلسلة عشوائية طويلة)
- `OPENAI_API_KEY` — مفتاح OpenAI

### 2. تثبيت المتطلبات
```bash
pip install -r requirements.txt
```

### 3. تشغيل قاعدة البيانات (Docker)
```bash
docker-compose up db -d
```

### 4. تطبيق Migrations
```bash
cd backend
alembic upgrade head
```

### 5. تشغيل السيرفر
```bash
uvicorn app.main:app --reload
```

السيرفر سيعمل على: `http://localhost:8000`
توثيق API التلقائي: `http://localhost:8000/docs`

---

## API Endpoints

### المصادقة `/api/v1/auth`
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/register` | تسجيل مستخدم جديد |
| POST | `/login` | تسجيل الدخول |
| POST | `/refresh` | تجديد التوكن |
| POST | `/logout` | تسجيل الخروج |
| GET | `/me` | بيانات المستخدم الحالي |
| PATCH | `/me` | تحديث الملف الشخصي |
| POST | `/change-password` | تغيير كلمة المرور |

### المصاريف `/api/v1/expenses`
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `` | قائمة المصاريف (مع فلترة وصفحات) |
| POST | `` | إضافة مصروف |
| POST | `/bulk` | إضافة مصاريف متعددة دفعة واحدة |
| GET | `/{id}` | تفاصيل مصروف |
| PATCH | `/{id}` | تعديل مصروف |
| DELETE | `/{id}` | حذف مصروف |

### التصنيفات `/api/v1/categories`
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `` | كل التصنيفات |
| POST | `` | إنشاء تصنيف مخصص |
| PATCH | `/{id}` | تعديل تصنيف |
| DELETE | `/{id}` | حذف تصنيف |

### الإحصائيات `/api/v1/statistics`
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/daily` | ملخص يوم محدد |
| GET | `/monthly` | ملخص شهر محدد |
| GET | `/categories` | تفصيل حسب التصنيف (للرسوم البيانية) |
| GET | `/trend` | الاتجاه اليومي للشهر |
| GET | `/comparison` | مقارنة آخر N شهور |
| GET | `/insights` | نصائح ذكية من GPT |

### الميزانيات `/api/v1/budgets`
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `` | ميزانيات الشهر مع نسب الإنفاق |
| POST | `` | إنشاء ميزانية |
| PATCH | `/{id}` | تعديل ميزانية |
| DELETE | `/{id}` | حذف ميزانية |
| GET | `/goals` | الأهداف المالية |
| POST | `/goals` | إنشاء هدف |
| PATCH | `/goals/{id}` | تعديل هدف |
| DELETE | `/goals/{id}` | حذف هدف |

### الصوت الذكي `/api/v1/voice`
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/parse-expense` | رفع ملف صوتي → تحليل المصاريف |

---

## تدفق الإدخال الصوتي

```
المستخدم يتكلم
        ↓
Flutter يسجل الصوت (m4a/wav)
        ↓
POST /api/v1/voice/parse-expense
        ↓
OpenAI Whisper → تحويل الصوت لنص
        ↓
GPT-4o → استخراج المصاريف من النص
        ↓
{ transcript, parsed_expenses: [{amount, category, description, date}] }
        ↓
Flutter يعرض للمستخدم للمراجعة والتأكيد
        ↓
POST /api/v1/expenses/bulk → حفظ نهائي
```

---

## التصنيفات الافتراضية
كل مستخدم جديد يحصل تلقائياً على:

| أيقونة | عربي | إنجليزي |
|--------|------|---------|
| 🍔 | طعام | Food |
| 🚗 | مواصلات | Transport |
| 🛍️ | تسوق | Shopping |
| 🏥 | صحة | Health |
| 🎮 | ترفيه | Entertainment |
| 📚 | تعليم | Education |
| 💡 | فواتير | Bills |
| 🏠 | سكن | Housing |
| ➕ | أخرى | Other |

---

## الخطوة التالية: تطبيق Flutter

بعد رفع Backend، يتم بناء تطبيق Flutter المتصل به يشمل:
- شاشات التسجيل والدخول
- الصفحة الرئيسية مع ملخص اليوم
- إضافة مصاريف نصياً أو صوتياً
- الرسوم البيانية والإحصائيات
- إدارة الميزانيات والأهداف
- إعدادات اللغة والعملة والثيم
