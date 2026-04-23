# StudyFlow

Flutter study planner with local auth, an API-ready schedule repository, and a
small Express/SQLite backend for the timetable.

## Flutter App

Install dependencies and run checks:

```bash
flutter pub get
flutter test
flutter analyze
```

Run against the local backend:

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

To store accounts in the backend SQLite database instead of local device storage,
set `STUDYFLOW_AUTH_BASE_URL` to the backend URL, for example:

```bash
flutter run \
	--dart-define=STUDYFLOW_API_BASE_URL=http://localhost:3000 \
	--dart-define=STUDYFLOW_AUTH_BASE_URL=http://localhost:3000
```

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

To use Gemini, put the API key only in the backend environment:

```bash
LLM_PROVIDER=gemini
LLM_MODEL=gemini-3-flash-preview
GEMINI_API_KEY=your-google-ai-studio-key
```

Frontend AI config is provided through `dart-define` values only. Do not put API
keys in the Flutter app. The backend reads LLM credentials from environment
variables only.
