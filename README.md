# Ceramic Showroom ERP with AI Assistant

Enterprise Resource Planning system for ceramic showrooms with integrated AI assistant powered by Claude Sonnet.

## Architecture

```
Flutter App (Web/Desktop/Mobile)
     ↓ REST + WebSocket + SSE
FastAPI Backend (v4.2.0)
     ↓
AI Orchestrator (Claude Sonnet)
     ↓
Tool Router (15 tools)
     ↓
Service Layer (business logic)
     ↓
Repositories (DB)
     ↓
PostgreSQL + Redis + pgvector
```

## Prerequisites

- **PostgreSQL** 15+ (with pgvector extension)
- **Redis** 7+
- **Python** 3.11+
- **Flutter** 3.2+ (Dart 3+)
- **Anthropic API Key** (for AI features)

---

## Step 1: Clone the Repository

```bash
git clone https://github.com/coder-contrib/ERP-With-AI-Assistant.git
cd ERP-With-AI-Assistant
```

---

## Step 2: Setup PostgreSQL Database

```bash
# Create database
sudo -u postgres psql -c "CREATE DATABASE ceramic_erp;"

# Run main schema
sudo -u postgres psql -d ceramic_erp -f database/schema.sql

# Run AI schema (pgvector)
sudo -u postgres psql -d ceramic_erp -f database/ai_schema.sql
```

> **Note:** If pgvector is not installed:
> ```bash
> # Ubuntu/Debian
> sudo apt install postgresql-15-pgvector
> # Or from source: https://github.com/pgvector/pgvector
> ```

---

## Step 3: Setup Redis

```bash
# Ubuntu/Debian
sudo apt install redis-server
sudo systemctl start redis

# Verify
redis-cli ping
# Should return: PONG
```

---

## Step 4: Setup Backend (FastAPI)

```bash
cd backend

# Create virtual environment
python -m venv venv
source venv/bin/activate  # Linux/Mac
# venv\Scripts\activate   # Windows

# Install dependencies
pip install -r requirements.txt

# Create .env file
cp .env.example .env
```

### Edit `.env` with your values:

```env
DATABASE_URL=postgresql://postgres:your_password@localhost:5432/ceramic_erp
REDIS_URL=redis://localhost:6379/0
CELERY_BROKER_URL=redis://localhost:6379/1
CELERY_RESULT_BACKEND=redis://localhost:6379/1
SECRET_KEY=generate-a-random-secret-key-here
ACCESS_TOKEN_EXPIRE_MINUTES=480
ANTHROPIC_API_KEY=sk-ant-api03-your-key-here
AI_MODEL=claude-sonnet-4-20250514
DEBUG=true
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173,http://localhost:8080
```

### Create admin user:

```bash
python -m app.seeds
# Output:
# Admin user created successfully.
# Username: admin
# Password: admin123
```

### Run the backend:

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

API docs available at: **http://localhost:8000/docs**

---

## Step 5: Run Celery Workers (Background Jobs)

Open a new terminal:

```bash
cd backend
source venv/bin/activate

# Run worker + beat scheduler together (development)
celery -A app.celery_app worker --beat --loglevel=info
```

Or separately (production):

```bash
# Terminal 1: Worker
celery -A app.celery_app worker --loglevel=info

# Terminal 2: Beat Scheduler
celery -A app.celery_app beat --loglevel=info
```

---

## Step 6: Setup Frontend (Flutter)

```bash
cd frontend

# Get dependencies
flutter pub get

# Run on Chrome (Web)
flutter run -d chrome

# Run on Desktop
flutter run -d windows   # Windows
flutter run -d macos     # macOS
flutter run -d linux     # Linux
```

### Configure API URL:

Edit `frontend/lib/core/network/api_client.dart`:
```dart
const _baseUrl = 'http://localhost:8000/api';  // Change if backend is elsewhere
```

Edit `frontend/lib/core/network/websocket_service.dart`:
```dart
const _wsBaseUrl = 'ws://localhost:8000';  // Change if backend is elsewhere
```

---

## Step 7: Verify Everything Works

1. **Health Check:** http://localhost:8000/health
   ```json
   {"status": "healthy", "redis": "connected", "websocket_connections": 0}
   ```

2. **Login:** Open Flutter app → Login with `admin` / `admin123`

3. **Dashboard:** Should show KPI cards (zeros initially)

4. **AI Assistant:** Navigate to AI page → Ask "What is my cash balance?"

5. **API Docs:** http://localhost:8000/docs (Swagger UI)

---

## Running in Production

```bash
# Backend (with Gunicorn)
pip install gunicorn
gunicorn app.main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000

# Frontend (build for web)
cd frontend
flutter build web
# Serve frontend/build/web/ with Nginx

# Celery (with systemd or supervisor)
celery -A app.celery_app worker --loglevel=warning --concurrency=4
celery -A app.celery_app beat --loglevel=warning
```

---

## Project Structure

```
ERP-With-AI-Assistant/
├── database/
│   ├── schema.sql              # Main ERP schema (27 tables)
│   └── ai_schema.sql           # pgvector + AI tables
│
├── backend/
│   ├── app/
│   │   ├── main.py             # FastAPI app
│   │   ├── config.py           # Settings
│   │   ├── database.py         # SQLAlchemy + transactions
│   │   ├── celery_app.py       # Background jobs
│   │   ├── models/             # SQLAlchemy models
│   │   ├── schemas/            # Pydantic DTOs
│   │   ├── routers/            # API endpoints (thin)
│   │   ├── services/           # Business logic
│   │   ├── repositories/       # DB operations
│   │   ├── core/               # Auth, permissions, validators
│   │   ├── events/             # Event bus + handlers
│   │   ├── tasks/              # Celery tasks
│   │   └── ai/                 # AI integration
│   │       ├── agents/         # Sales, Inventory, Accounting, Manager
│   │       ├── tools/          # ERP data access for AI
│   │       ├── prompts/        # System prompts
│   │       ├── memory/         # Conversation memory
│   │       ├── rag/            # Retrieval-augmented generation
│   │       ├── embeddings/     # pgvector service
│   │       ├── anomaly_detector.py
│   │       └── claude_client.py
│   └── requirements.txt
│
└── frontend/
    ├── lib/
    │   ├── main.dart
    │   ├── core/               # Theme, router, network, widgets
    │   ├── features/           # Feature modules
    │   │   ├── auth/
    │   │   ├── dashboard/
    │   │   ├── products/
    │   │   ├── customers/
    │   │   ├── sales/
    │   │   ├── ai_assistant/
    │   │   └── ...
    │   └── shared/             # Layouts
    └── pubspec.yaml
```

---

## Key Features

- JWT Authentication with role-based permissions
- Double-entry accounting (automatic ledger entries)
- Real-time WebSocket updates
- AI Assistant (Claude Sonnet with 15 ERP tools)
- Adaptive anomaly detection (z-score, rolling avg, seasonal)
- Demand forecasting and stock predictions
- 9 business reports
- Background job scheduling (Celery)
- Redis caching (stock, dashboard, sessions)
- pgvector semantic search
- Event-driven architecture

---

## API Endpoints Overview

| Category | Endpoints |
|----------|----------|
| Auth | `/api/auth/login`, `/api/auth/me`, `/api/auth/logout` |
| Dashboard | `/api/dashboard/summary` |
| AI | `/api/ai/chat`, `/api/ai/chat/stream`, `/api/ai/predict/*` |
| Insights | `/api/insights/`, `/api/insights/why-profit-dropped` |
| Anomalies | `/api/anomalies/scan`, `/api/anomalies/seasonal` |
| Products | `/api/products/` (CRUD) |
| Sales | `/api/sales/` (create with auto inventory+cash+ledger) |
| Reports | `/api/reports/daily-sales`, `/api/reports/monthly-profit`, etc. |
| WebSocket | `ws/dashboard`, `ws/notifications`, `ws/inventory`, `ws/ai` |

---

## Default Credentials

| Username | Password | Role |
|----------|----------|------|
| admin | admin123 | Admin (full access) |

**Change the password after first login!**
