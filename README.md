# StudyFlow

Flutter study planner with Supabase auth/data, an API-backed schedule repository,
and a small Express backend for timetable and AI routes.

## Flutter App

Install dependencies and run checks:

```bash
flutter pub get
flutter test
flutter analyze
```

Run the Flutter app against the local backend:

```bash
flutter run -d chrome --dart-define=STUDYFLOW_API_BASE_URL=http://localhost:3000
```

AI chat and agent traffic use the same backend URL by default. If your AI
backend is on a different host, override it explicitly:

```bash
flutter run -d chrome \
	--dart-define=STUDYFLOW_API_BASE_URL=http://localhost:3000 \
	--dart-define=STUDYFLOW_AI_BACKEND_URL=http://localhost:3000
```

For an offline deterministic AI demo, run with:

```bash
flutter run -d chrome --dart-define=STUDYFLOW_USE_MOCK_AI=true
```

For an Android emulator, use:

```bash
flutter run --dart-define=STUDYFLOW_API_BASE_URL=http://10.0.2.2:3000
```

If the backend is not running, the app falls back to the local seeded schedule.

To use Supabase from Flutter, pass your project URL and publishable key:

```bash
flutter run \
	--dart-define=NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co \
	--dart-define=NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=your-publishable-key \
	--dart-define=STUDYFLOW_API_BASE_URL=http://localhost:3000
```

Apply the SQL in `supabase/schema.sql` before starting the app.

## Backend API

The backend lives in `backend/` and exposes:

- `GET /health`
- `GET /api/schedule`
- `POST /api/schedule` with `Authorization: Bearer <ADMIN_TOKEN>`
- `POST /api/auth/signup`
- `POST /api/auth/signin`
- `GET /api/auth/users/:id`
- `POST /api/ai/chat`
- `POST /api/ai/chat/stream`
- `POST /api/ai/agent`
- `POST /api/ai/agent/stream`

Start it locally:

```bash
cd backend
npm install
npm run dev
```

Environment variables are documented in `backend/.env.example`.

The backend now uses Supabase instead of SQLite. Set these in `backend/.env.local`:

```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_PUBLISHABLE_KEY=your-publishable-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

One-time migration from the old SQLite database:

```bash
cd backend
npm run migrate:sqlite-to-supabase -- --dry-run
npm run migrate:sqlite-to-supabase
```

Notes:
- The script reads `backend/data/studyflow.sqlite`.
- It writes a report to `backend/data/sqlite-to-supabase-report.json`.
- Legacy SQLite passwords in this project use a custom SHA-256 format, not a Supabase-supported import hash, so migrated auth users receive a temporary password unless you pass `--defaultPassword` or set `MIGRATION_DEFAULT_PASSWORD`.
- Existing invalid orphan rows such as tasks or AI sessions with non-UUID `user_id` values are skipped and listed in the report.

To use Gemini, put the API key only in the backend environment:

```bash
LLM_PROVIDER=gemini
LLM_MODEL=gemini-3-flash-preview
GEMINI_API_KEY=your-google-ai-studio-key
```

Frontend AI config is provided through `dart-define` values only. Do not put API
keys in the Flutter app. The backend reads LLM credentials from environment
variables only.
