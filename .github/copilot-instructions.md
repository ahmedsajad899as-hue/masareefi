# Masareefi (مصاريفي) — Copilot Instructions

Arabic-first personal expense tracker for the Iraqi market. Full-stack: Flutter frontend + FastAPI backend + PostgreSQL (Docker) or SQLite (local dev). Includes AI-powered voice expense input via OpenAI.

---

## Build & Run

### Backend

**Docker (recommended):**
```ps1
docker-compose up -d
```
Backend: `http://localhost:8000` | API docs: `http://localhost:8000/docs`

**Local (SQLite, no Docker):**
```ps1
cd backend
# One of the VS Code tasks handles all of the below automatically:
venv\Scripts\uvicorn.exe app.main:app --port 8000
# Required env vars: DATABASE_URL, SECRET_KEY, OPENAI_API_KEY
```

**Migrations:**
```ps1
cd backend
alembic upgrade head
```

### Flutter

```ps1
cd flutter_app
flutter pub get
flutter run -d chrome --web-port 8080
```

**After changing Riverpod providers or models:**
```ps1
flutter pub run build_runner build --delete-conflicting-outputs
```

### Both at once

Use the VS Code task **"🚀 Start Backend + Flutter Web"**.

---

## Architecture

### Backend (`backend/app/`)

| Layer | Directory | Purpose |
|-------|-----------|---------|
| Entry | `main.py` | FastAPI app, CORS, lifespan startup (DB seed) |
| Config | `config.py`, `database.py` | Pydantic settings, async SQLAlchemy engine |
| Models | `models/` | SQLAlchemy ORM: `User`, `Expense`, `Category`, `Wallet`, `Budget`, `Goal` |
| Schemas | `schemas/` | Pydantic request/response DTOs |
| Routers | `routers/` | REST endpoints, prefix `/api/v1/` |
| Services | `services/` | Business logic: `ai_service.py` (OpenAI), `stats_service.py` |
| Utils | `utils/` | JWT, bcrypt hashing, Depends() helpers |
| Migrations | `alembic/versions/` | Alembic migration scripts |

### Frontend (`flutter_app/lib/`)

| Layer | Directory | Purpose |
|-------|-----------|---------|
| Entry | `main.dart` | `ProviderScope` + `MaterialApp.router` + locale |
| Routing | `core/router/app_router.dart` | GoRouter, auth redirect guard |
| Constants | `core/constants/api_constants.dart` | Base URLs, all API path strings |
| Theme | `core/theme/app_theme.dart`, `core/constants/app_colors.dart` | Design tokens |
| State | `providers/` | Riverpod `StateNotifierProvider` per domain |
| HTTP | `services/api_service.dart` | Dio singleton with auto-attach JWT + 401 refresh interceptor |
| Audio | `services/audio_service.dart` | Mic recording → `.m4a` → backend `/voice/parse` |
| Models | `models/` | Plain Dart classes with `fromJson`/`toJson` |
| Screens | `screens/` | Feature folders: `auth/`, `home/`, `expenses/`, `statistics/`, `budgets/`, `settings/` |
| i18n | `l10n/` | `app_ar.arb` + `app_en.arb` — Arabic is the default |

---

## Key Conventions

- **Language**: UI defaults to Arabic (`ar`); Iraqi Dinar (IQD) is the default currency.
- **File naming**: snake_case for all files (both Dart and Python).
- **Class naming**: `UpperCamelCase` for both Dart and Python models/schemas.
- **API prefix**: All endpoints live under `/api/v1/`.
- **Auth**: JWT Bearer tokens. Access token auto-attached by Dio interceptor. Refresh is done automatically on 401; failure clears tokens and redirects to login.
- **Token security**: Refresh tokens are bcrypt-hashed before storage in DB. Old token is revoked on rotation.
- **Wallet balance**: Decremented automatically when an expense is created. No auto-replenishment — manual edits required.
- **System data**: 9 default categories and 5 default wallets are seeded on first run (Arabic + English labels + emojis).
- **Default dev user**: `admin@masareefi.com` / `123456789` (SQLite only — seeded in `main.py` lifespan).

---

## Platform-Specific Gotchas

| Issue | Detail |
|-------|--------|
| API base URL | Web → `http://localhost:8000/api/v1`; Android emulator → `http://10.0.2.2:8000/api/v1`. Handled in `api_constants.dart` via `kIsWeb`. |
| Database | Docker → PostgreSQL 16. Local dev → SQLite (`masareefi.db`). Set `DATABASE_URL` env var accordingly. |
| OpenAI fallback | If `OPENAI_API_KEY` is missing or `sk-placeholder`, the voice router falls back to a local regex-based parser. |
| CORS | Allowed origins hardcoded in `config.py`: ports 8000, 8080, 5000, 5500. Update if using a different port. |
| Riverpod codegen | `generate: true` in `pubspec.yaml`. Re-run `build_runner` after editing generator-annotated providers. |
| Postgres seeding | The lifespan seed runs only on SQLite. For Postgres, use Alembic or seed manually. |

---

## Adding Features — Standard Pattern

### New Backend endpoint
1. Add SQLAlchemy model in `models/` and import it in `models/__init__.py`.
2. Add Pydantic schemas in `schemas/`.
3. Create a router in `routers/`, register it in `main.py`.
4. Add business logic to `services/` if non-trivial.
5. Generate a new Alembic migration: `alembic revision --autogenerate -m "description"`.

### New Flutter screen
1. Add screen file in the appropriate `screens/<feature>/` folder.
2. Register route in `app_router.dart`.
3. Add a Riverpod provider in `providers/` (StateNotifier pattern).
4. Add any new API calls to `services/api_service.dart` and new path constants to `api_constants.dart`.
5. Add localization strings to both `app_ar.arb` and `app_en.arb`.
