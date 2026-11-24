<div align="center">📚 StudyFlow
A Flutter study planner with a Supabase-backed schedule, an Express API, and optional AI assistance.





Overview · Getting started · API · AI · Migration
</div>✨ Overview
StudyFlow is a student-planning project combining a Flutter client, a Node.js / Express backend, and Supabase for authentication and data storage. The client can work against the API-backed schedule or fall back to locally seeded schedule data when the backend is unavailable.

The backend also provides AI chat and agent endpoints, with a configurable LLM provider and an offline mock mode for reproducible demonstrations.
Main capabilities
- Study scheduling: schedule retrieval and updates via backend API.
- Authentication: backend signup/signin and Supabase integration.
- AI support: chat and agent endpoints, including streaming variants.
- Development flexibility: browser runs, Android emulator support, and deterministic offline AI demo.
- Data migration: tooling for moving legacy SQLite records into Supabase.
Project status: Features listed here reflect the existing project documentation. Some capabilities require a configured backend, Supabase project, and provider credentials.

🧱 Architecture
┌───────────────────────────┐
│ Flutter / Dart client     │
│ UI • schedule • AI chat   │
└────────────┬──────────────┘
             │ HTTP API
             ▼
┌───────────────────────────┐
│ Express backend           │
│ Auth • Schedule • AI      │
└──────────┬───────────┬────┘
           │           │
           ▼           ▼
    ┌────────────┐ ┌─────────────────┐
    │ Supabase   │ │ Optional Gemini │
    │ Auth/Data  │ │ LLM provider    │
    └────────────┘ └─────────────────┘
Layer	Technologies	Purpose
Mobile / web client	Flutter, Dart	User interface and client-side experience
API	Node.js, Express	Timetable, authentication and AI routes
Data & authentication	Supabase	Persistent records and authentication integration
Optional AI	Gemini via backend	Chat and agent requests


🚀 Getting started
Prerequisites
- Flutter SDK
- Node.js and npm
- A Supabase project if you want persistent backend data
- A compatible device, emulator, or Chrome for Flutter web
1. Install and check the Flutter app
From the project root:
flutter pub get
flutter test
flutter analyze
2. Configure and start the backend
cd backend
npm install
npm run dev
Environment-variable guidance is available in [`backend/.env.example`](backend/.env.example). Create backend/.env.local with your own credentials:
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_PUBLISHABLE_KEY=your-publishable-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
Apply the database schema in [`supabase/schema.sql`](supabase/schema.sql) before starting the app against Supabase.
🔐 Security: Keep SUPABASE_SERVICE_ROLE_KEY, GEMINI_API_KEY, and any backend tokens only on the server. Never commit .env.local files or embed secret keys in your Flutter app.

3. Run the Flutter client
Chrome (local backend):
flutter run -d chrome --dart-define=STUDYFLOW_API_BASE_URL=http://localhost:3000
Android emulator:
flutter run --dart-define=STUDYFLOW_API_BASE_URL=http://10.0.2.2:3000
Separate AI backend URL (optional):
flutter run -d chrome \
  --dart-define=STUDYFLOW_API_BASE_URL=http://localhost:3000 \
  --dart-define=STUDYFLOW_AI_BACKEND_URL=http://localhost:3000
Supabase client configuration:
flutter run \
  --dart-define=NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=your-publishable-key \
  --dart-define=STUDYFLOW_API_BASE_URL=http://localhost:3000
The schedule interface uses locally seeded data as a fallback when the backend is unavailable.
🔌 Backend API
The Express backend is located in [`backend/`](backend/).
Method	Endpoint	Purpose
GET	/health	Health check
GET	/api/schedule	Read schedule
POST	/api/schedule	Update schedule (requires Authorization: Bearer <ADMIN_TOKEN>)
POST	/api/auth/signup	User signup
POST	/api/auth/signin	User signin
GET	/api/auth/users/:id	User endpoint
POST	/api/ai/chat	AI chat request
POST	/api/ai/chat/stream	Streamed AI chat
POST	/api/ai/agent	AI agent request
POST	/api/ai/agent/stream	Streamed AI agent response


See the backend source for request/response schemas, authorization details, and error handling.
🤖 AI configuration
Offline / deterministic demonstration
Launch Flutter with mock AI responses:
flutter run -d chrome --dart-define=STUDYFLOW_USE_MOCK_AI=true
Gemini provider (server-side only)
Set the following in the backend environment:
LLM_PROVIDER=gemini
LLM_MODEL=gemini-3-flash-preview
GEMINI_API_KEY=your-google-ai-studio-key
The model name above comes from the project's existing configuration examples; use a model available to your provider account if it changes. The Flutter client receives only backend URLs through --dart-define; never place LLM API keys in client configuration.
🗃️ SQLite-to-Supabase migration
The backend now uses Supabase rather than SQLite. A one-time migration utility is included for older datasets.
cd backend
npm run migrate:sqlite-to-supabase -- --dry-run
npm run migrate:sqlite-to-supabase
Migration behavior and cautions:
- Reads legacy records from backend/data/studyflow.sqlite.
- Writes a migration report to backend/data/sqlite-to-supabase-report.json.
- Legacy password hashes use a custom SHA-256 format, so migrated authentication users may receive a temporary password unless --defaultPassword or MIGRATION_DEFAULT_PASSWORD is set.
- Invalid orphan rows, including tasks or AI sessions with non-UUID user_id values, are skipped and recorded in the report.
- Review the dry-run report before executing a live migration; protect generated reports and any temporary passwords.
🧪 Quality checks
flutter test
flutter analyze
These commands describe how to run checks; they do not imply that all tests have been verified as passing in every environment.
🖼️ Screenshots and demo
Screenshots and a short demo can be added here after capturing them from a working build. Avoid placeholder or invented UI images in a recruiter-facing README.
👤 Maintainer
Yassine Belhadj Ali — Computer Science Student, ISIMM


<div align="center"><sub>Built to explore better student planning, reliable backend integration, and AI-assisted workflows.</sub></div>
