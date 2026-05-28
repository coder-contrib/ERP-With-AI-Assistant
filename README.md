<p align="center">
  <img src="https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white" />
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Claude_AI-191919?style=for-the-badge&logo=anthropic&logoColor=white" />
  <img src="https://img.shields.io/badge/PostgreSQL-4169E1?style=for-the-badge&logo=postgresql&logoColor=white" />
  <img src="https://img.shields.io/badge/Redis-DC382D?style=for-the-badge&logo=redis&logoColor=white" />
  <img src="https://img.shields.io/badge/WhatsApp-25D366?style=for-the-badge&logo=whatsapp&logoColor=white" />
  <img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" />
</p>

<h1 align="center">Ceramic Showroom ERP with AI Assistant</h1>

<p align="center">
  <strong>A full-stack Enterprise Resource Planning system with an integrated AI assistant powered by Claude, real-time voice control, WhatsApp integration, and advanced business intelligence — purpose-built for ceramic and tile showrooms.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-4.2.0-blue?style=flat-square" />
  <img src="https://img.shields.io/badge/AI_Tools-70+-green?style=flat-square" />
  <img src="https://img.shields.io/badge/language-Arabic_&_English-orange?style=flat-square" />
  <img src="https://img.shields.io/badge/license-MIT-purple?style=flat-square" />
</p>

---

## Overview

This is not a typical ERP. It's an **AI-first business operating system** where every operation — from creating invoices to detecting anomalies — can be executed through natural language (typed or spoken in Arabic/English). The AI doesn't just answer questions; it directly operates the business through 70+ registered tools with full safety guardrails.

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Flutter App (Web/Desktop/Mobile)              │
│                    ┌──────────┐  ┌──────────┐  ┌──────────┐        │
│                    │ Dashboard│  │AI Voice  │  │ Modules  │        │
│                    │   + KPIs │  │Assistant │  │(Sales,..)│        │
│                    └────┬─────┘  └────┬─────┘  └────┬─────┘        │
└─────────────────────────┼─────────────┼─────────────┼───────────────┘
                          │ REST        │ WebSocket   │ SSE
┌─────────────────────────┼─────────────┼─────────────┼───────────────┐
│                     FastAPI Backend (Python 3.11+)                    │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    AI Orchestration Layer                      │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────┐  │   │
│  │  │ Manager  │  │  Voice   │  │Transaction│  │  Permission │  │   │
│  │  │  Agent   │  │Orchestr. │  │  Guard    │  │   Engine    │  │   │
│  │  └────┬─────┘  └────┬─────┘  └────┬──────┘  └─────┬──────┘  │   │
│  │       │              │              │               │          │   │
│  │  ┌────┴──────────────┴──────────────┴───────────────┴──────┐  │   │
│  │  │              Tool Executor (70+ tools)                   │  │   │
│  │  │  Sales | Inventory | Finance | CRM | WhatsApp | Workflow │  │   │
│  │  └─────────────────────────┬────────────────────────────────┘  │   │
│  └────────────────────────────┼───────────────────────────────────┘   │
│                               │                                       │
│  ┌────────────────────────────┼───────────────────────────────────┐   │
│  │                    Service Layer                                │   │
│  │  Sales | Inventory | Ledger | Payment | Report | Voice | Cache │   │
│  └────────────────────────────┼───────────────────────────────────┘   │
│                               │                                       │
│  ┌────────────────────────────┼───────────────────────────────────┐   │
│  │                  Data Layer                                     │   │
│  │  PostgreSQL (27 tables) + pgvector + Redis + Celery             │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────────┘
                               │
                    ┌──────────┴──────────┐
                    │  External Services   │
                    │  • Anthropic (Claude) │
                    │  • Deepgram (STT)    │
                    │  • Meta WhatsApp API │
                    └─────────────────────┘
```

---

## Key Features

### AI Assistant (Claude-Powered)

| Feature | Description |
|---------|-------------|
| **Natural Language Operations** | Execute any ERP action by describing it in Arabic or English |
| **70+ Registered Tools** | Full CRUD coverage across all business domains |
| **Multi-Agent Architecture** | Manager → Sales/Inventory/Accounting specialist agents |
| **Conversation Memory** | Remembers customer preferences, past transactions, context |
| **Semantic Search (RAG)** | pgvector-powered retrieval for business knowledge |
| **Transaction Safety** | Dry-run previews, confirmation flows, automatic rollback |
| **Idempotency Guards** | Prevents duplicate operations from repeated requests |
| **Role-Based AI Access** | Different tool access per user role (admin, manager, cashier, etc.) |

### Voice Control (Real-Time)

| Feature | Description |
|---------|-------------|
| **Live Streaming Transcription** | Real-time speech-to-text with partial results |
| **Barge-In Support** | Interrupt the AI mid-response to change direction |
| **Arabic Dialect Recognition** | Optimized for Egyptian Arabic informal speech |
| **Text-to-Speech Response** | AI speaks back results naturally |
| **Voice-First Tool Routing** | Short spoken commands map to complex operations |
| **Session Versioning** | Prevents stale responses after interruption |

### WhatsApp Integration (Meta Cloud API)

| Feature | Description |
|---------|-------------|
| **Direct Messaging** | Send messages to any customer via WhatsApp |
| **Bulk Overdue Reminders** | Auto-send payment reminders to all overdue customers |
| **Daily Sales Reports** | Send formatted daily summary to management |
| **Atomic Workflows** | Create invoice + send WhatsApp in one guaranteed operation |
| **Safety Controls** | Bulk operations require explicit confirmation |

### Business Intelligence & Analytics

| Feature | Description |
|---------|-------------|
| **Anomaly Detection** | Z-score + rolling average + seasonal pattern analysis |
| **Profit Drop Analysis** | Auto-identifies why profit decreased with recommendations |
| **Demand Forecasting** | Predicts stockout dates using historical movement data |
| **Risk Assessment** | Stock risks, credit risks, anomalies ranked by severity |
| **Business Insights** | AI-generated opportunities and warnings |

### Financial Management

| Feature | Description |
|---------|-------------|
| **Double-Entry Accounting** | Every transaction creates proper journal entries |
| **10 Ledger Accounts** | Cash, Receivables, Inventory, Payables, Equity, Revenue, Returns, COGS, Purchase Returns, Expenses |
| **Trial Balance** | Auto-generated, verifies books are balanced |
| **P&L Reports** | Monthly breakdown: revenue, COGS, gross profit, expenses, net |
| **Cash Flow** | Daily cash in/out with net flow visualization |
| **Opening Balances** | Full initial setup for customers, suppliers, cash, inventory |

### Inventory & Warehouse

| Feature | Description |
|---------|-------------|
| **Multi-Warehouse** | Track stock across multiple locations |
| **Auto-Deduction** | Stock deducted automatically on invoice creation |
| **Inter-Warehouse Transfers** | Move products between warehouses with audit trail |
| **Dead Stock Detection** | Identify products with no movement in N days |
| **Stock Valuation** | Per-warehouse inventory value calculation |
| **Low Stock Alerts** | Automatic notifications when stock falls below threshold |

### Sales & CRM

| Feature | Description |
|---------|-------------|
| **Invoice Management** | Create, cancel, apply discounts, track status |
| **Payment Recording** | Cash, credit, mixed payment types with ledger integration |
| **Customer Credit Limits** | Enforce credit policies with automatic warnings |
| **Customer History** | Full purchase history and balance tracking |
| **Sales Returns** | Process returns with stock restoration and refunds |
| **Walk-In Support** | Create invoices without customer record |

### Purchase Management

| Feature | Description |
|---------|-------------|
| **Purchase Invoices** | Create from suppliers with automatic stock addition |
| **Purchase Returns** | Return items to suppliers with ledger reversal |
| **Supplier Management** | Full CRUD with balance tracking |
| **Supplier Payment Terms** | Track what you owe and when |

### Real-Time Features

| Feature | Description |
|---------|-------------|
| **WebSocket Dashboard** | Live KPI updates without page refresh |
| **Inventory WebSocket** | Real-time stock change notifications |
| **Notification WebSocket** | Push alerts for low stock, credit limits, overdue payments |
| **AI Streaming** | Server-Sent Events for streaming AI responses |
| **Voice WebSocket** | Full-duplex audio streaming with tool event callbacks |

### Security & Permissions

| Feature | Description |
|---------|-------------|
| **JWT Authentication** | Secure token-based auth with configurable expiry |
| **5 User Roles** | Admin, Manager, Cashier, Warehouse Employee, Accountant |
| **Granular Permissions** | Each role has explicit allowed/blocked tool lists |
| **Transaction Guard** | High-value operations require confirmation |
| **Financial Limits** | Auto-flag transactions above configurable thresholds |
| **Sensitive Operations** | Bulk actions and workflows always need approval |

### Infrastructure

| Feature | Description |
|---------|-------------|
| **Docker Compose** | One-command deployment with PostgreSQL, Redis, Backend, Celery |
| **Celery Background Jobs** | Scheduled tasks: daily summaries, alert scanning, cleanups |
| **Redis Caching** | Stock levels, dashboard data, session state |
| **Event-Driven Architecture** | Internal event bus for cross-module communication |
| **Observability** | Structured logging with AI interaction tracking |
| **pgvector** | Vector embeddings for semantic search and memory |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | Flutter 3.2+ (Dart), Riverpod, GoRouter, FL Chart, Web/Desktop/Mobile |
| **Backend** | Python 3.11+, FastAPI, SQLAlchemy, Pydantic |
| **AI Engine** | Anthropic Claude (Sonnet), Custom Agent Framework |
| **Voice** | Deepgram (STT), Text-to-Speech, WebSocket streaming |
| **Messaging** | Meta WhatsApp Cloud API (v18.0) |
| **Database** | PostgreSQL 16 + pgvector extension |
| **Cache/Queue** | Redis 7, Celery (background tasks + scheduling) |
| **Deployment** | Docker, Docker Compose, Gunicorn + Uvicorn workers |

---

## AI Tool Inventory (70+ Tools)

<details>
<summary><strong>Sales & CRM (12 tools)</strong></summary>

- `create_invoice` — Create sales invoice with auto stock deduction + ledger
- `cancel_invoice` — Cancel invoice with full reversal
- `apply_discount` — Modify invoice discount
- `record_payment` — Record customer payment
- `refund_payment` — Process refund
- `create_sales_return` — Handle sales returns
- `list_sales_invoices` — List invoices with filters
- `get_sales_invoice` — Get invoice details
- `get_invoice_items` — Get line items
- `create_customer` — Add new customer
- `update_customer` — Modify customer info
- `search_customers` — Search by name/phone

</details>

<details>
<summary><strong>Inventory & Warehouse (10 tools)</strong></summary>

- `get_stock_level` — Check product stock per warehouse
- `get_low_stock_items` — Find items below threshold
- `get_stock_movement_history` — Recent movements log
- `get_warehouse_summary` — Warehouse overview
- `get_dead_stock` — No-movement products
- `get_stock_valuation` — Inventory value per warehouse
- `update_stock` — Receive goods
- `transfer_stock` — Inter-warehouse transfer
- `adjust_stock` — Manual correction
- `demand_forecast` — Predict stockout

</details>

<details>
<summary><strong>Finance & Accounting (12 tools)</strong></summary>

- `get_profit_and_loss` — P&L for date range
- `get_cash_balance` — Current cash position
- `get_receivables_summary` — A/R with top debtors
- `get_payables_summary` — A/P with top creditors
- `get_expense_breakdown` — Expenses by category
- `get_daily_revenue` — Revenue trend
- `get_monthly_profit` — Monthly P&L breakdown
- `get_cash_flow` — Daily cash in/out
- `get_ledger_entries` — Journal entries
- `get_account_balance` — Specific account balance
- `get_trial_balance` — Full trial balance verification
- `refresh_daily_summary` — Recalculate daily financials

</details>

<details>
<summary><strong>Purchases & Suppliers (8 tools)</strong></summary>

- `create_purchase_invoice` — Purchase with auto stock addition
- `create_purchase_return` — Return to supplier
- `list_purchase_invoices` — Recent purchases
- `get_purchase_invoice` — Purchase details
- `get_purchase_items` — Purchase line items
- `create_supplier` — Add supplier
- `update_supplier` — Modify supplier
- `search_suppliers` — Search suppliers

</details>

<details>
<summary><strong>Products & Categories (7 tools)</strong></summary>

- `create_product` — Add new product
- `update_product` — Modify product
- `get_product` — Product details + stock
- `search_products` — Search by name
- `list_categories` — All categories
- `create_category` — Add category
- `update_category` / `delete_category`

</details>

<details>
<summary><strong>Business Intelligence (7 tools)</strong></summary>

- `scan_anomalies` — Full anomaly scan
- `detect_revenue_anomaly` — Revenue anomaly check
- `detect_expense_anomaly` — Expense anomaly check
- `get_business_insights` — AI-generated insights
- `why_profit_dropped` — Profit drop analysis
- `get_top_risks` — Risk ranking
- `get_dashboard_summary` — Full KPI dashboard

</details>

<details>
<summary><strong>Alerts & Notifications (6 tools)</strong></summary>

- `check_low_stock_alerts` — Scan for low stock
- `check_credit_limit_alerts` — Credit limit breaches
- `check_overdue_supplier_alerts` — Overdue payables
- `get_notifications` — List notifications
- `mark_notification_read` — Mark single read
- `mark_all_notifications_read` — Clear all

</details>

<details>
<summary><strong>WhatsApp & Workflows (4 tools)</strong></summary>

- `send_whatsapp_message` — Send single message
- `send_overdue_reminders` — Bulk overdue reminders
- `send_daily_sales_report` — Send sales summary
- `create_invoice_and_notify` — Atomic: invoice + WhatsApp

</details>

<details>
<summary><strong>Admin & System (10 tools)</strong></summary>

- `list_users` / `create_user` / `deactivate_user` / `activate_user` / `reset_user_password`
- `set_customer_opening_balance` / `set_supplier_opening_balance` / `set_cash_opening_balance` / `set_opening_inventory`
- `get_opening_balances`

</details>

---

## Quick Start (Docker)

```bash
# Clone
git clone https://github.com/coder-contrib/ERP-With-AI-Assistant.git
cd ERP-With-AI-Assistant

# Set your Anthropic API key
export ANTHROPIC_API_KEY=sk-ant-api03-your-key

# Start everything
docker compose up -d

# Seed admin user
docker compose exec backend python -m app.seeds

# Access
# Backend API:  http://localhost:8000/docs
# Login:        admin / admin123
```

---

## Manual Setup

### Prerequisites

- **PostgreSQL** 16+ (with pgvector extension)
- **Redis** 7+
- **Python** 3.11+
- **Flutter** 3.2+ (Dart 3+)
- **Anthropic API Key**

### 1. Database

```bash
sudo -u postgres psql -c "CREATE DATABASE ceramic_erp;"
sudo -u postgres psql -d ceramic_erp -f database/schema.sql
sudo -u postgres psql -d ceramic_erp -f database/ai_schema.sql
```

### 2. Backend

```bash
cd backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env  # Edit with your values
python -m app.seeds
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 3. Celery Workers

```bash
cd backend && source venv/bin/activate
celery -A app.celery_app worker --beat --loglevel=info
```

### 4. Frontend

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

---

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `DATABASE_URL` | PostgreSQL connection string | Yes |
| `REDIS_URL` | Redis connection string | Yes |
| `SECRET_KEY` | JWT signing key | Yes |
| `ANTHROPIC_API_KEY` | Claude API key | Yes |
| `AI_MODEL` | Claude model ID (default: claude-sonnet-4-20250514) | No |
| `CELERY_BROKER_URL` | Celery broker (Redis) | Yes |
| `CELERY_RESULT_BACKEND` | Celery results (Redis) | Yes |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | JWT expiry (default: 480) | No |
| `ALLOWED_ORIGINS` | CORS origins | No |
| `WHATSAPP_API_TOKEN` | Meta WhatsApp API token | No |
| `WHATSAPP_PHONE_NUMBER_ID` | WhatsApp Business phone ID | No |
| `WHATSAPP_CAN_SEND` | Enable WhatsApp sending (true/false) | No |
| `WHATSAPP_CAN_BULK_MESSAGE` | Enable bulk WhatsApp (true/false) | No |
| `WHATSAPP_MAX_MESSAGES_PER_REQUEST` | Bulk limit (default: 50) | No |
| `DEBUG` | Enable debug mode | No |

---

## API Endpoints

| Category | Endpoints | Description |
|----------|-----------|-------------|
| **Auth** | `POST /api/auth/login`, `GET /api/auth/me` | JWT authentication |
| **AI Chat** | `POST /api/ai/chat`, `GET /api/ai/chat/stream` | Text AI interaction |
| **AI Voice** | `WS /ws/voice/{session_id}` | Real-time voice interaction |
| **Dashboard** | `GET /api/dashboard/summary` | Full KPI summary |
| **Products** | `/api/products/` (CRUD) | Product management |
| **Sales** | `/api/sales/` (create, cancel, returns) | Sales operations |
| **Purchases** | `/api/purchases/` (create, returns) | Purchase operations |
| **Inventory** | `/api/inventory/` (stock, transfers) | Stock management |
| **Customers** | `/api/customers/` (CRUD) | Customer management |
| **Suppliers** | `/api/suppliers/` (CRUD) | Supplier management |
| **Expenses** | `/api/expenses/` (CRUD, summary) | Expense tracking |
| **Reports** | `/api/reports/` (daily, monthly, P&L) | Business reports |
| **Insights** | `/api/insights/` (risks, analysis) | AI business insights |
| **Anomalies** | `/api/anomalies/scan` | Anomaly detection |
| **Notifications** | `/api/notifications/` | Alert management |
| **Users** | `/api/users/` (CRUD, roles) | User management |
| **AI Audit** | `/api/ai-audit/` | AI interaction logs |
| **WebSocket** | `WS /ws/dashboard`, `/ws/notifications`, `/ws/inventory` | Real-time updates |

---

## Voice Commands (Arabic Examples)

The AI assistant understands informal Egyptian Arabic via voice:

```
"بيع 5 متر سيراميك لأحمد"          → Creates sales invoice
"ابعت الفاتورة لأحمد على الواتس"      → Sends invoice via WhatsApp
"بيع وابعت واتس"                     → Creates invoice + WhatsApp (atomic)
"فكر العملاء اللي عليهم فلوس"         → Sends overdue reminders
"ابعتلي تقرير اليوم"                 → Sends daily sales report
"ليه الربح نزل؟"                     → Runs profit drop analysis
"فيه حاجة غريبة في الأرقام؟"          → Scans for anomalies
"كام الكاش؟"                         → Gets cash balance
"وريني مخزون المنتج ده"              → Checks stock level
```

---

## Project Structure

```
ERP-With-AI-Assistant/
├── docker-compose.yml
├── database/
│   ├── schema.sql                    # 27 tables: core ERP schema
│   └── ai_schema.sql                 # pgvector + AI memory tables
│
├── backend/
│   ├── app/
│   │   ├── main.py                   # FastAPI app + middleware
│   │   ├── config.py                 # Pydantic settings (env vars)
│   │   ├── database.py               # SQLAlchemy engine + sessions
│   │   ├── celery_app.py             # Background job scheduler
│   │   │
│   │   ├── models/                   # SQLAlchemy ORM models (16 files)
│   │   │   ├── sales.py, purchases.py, inventory.py
│   │   │   ├── customers.py, suppliers.py, products.py
│   │   │   ├── accounting.py, payments.py, expenses.py
│   │   │   └── users.py, notifications.py, waste.py, ...
│   │   │
│   │   ├── schemas/                  # Pydantic request/response DTOs
│   │   ├── repositories/            # Database query layer
│   │   │
│   │   ├── services/                 # Business logic (20 services)
│   │   │   ├── sales_service.py      # Invoice creation + stock + ledger
│   │   │   ├── inventory_service.py  # Stock management
│   │   │   ├── ledger_service.py     # Double-entry accounting
│   │   │   ├── payment_service.py    # Payment processing
│   │   │   ├── voice_service.py      # STT + TTS integration
│   │   │   ├── insights_service.py   # Business intelligence
│   │   │   ├── cache_service.py      # Redis caching layer
│   │   │   └── ...
│   │   │
│   │   ├── routers/                  # API endpoints (23 route files)
│   │   │   ├── ai.py, voice.py, ws.py
│   │   │   ├── sales.py, purchases.py, inventory.py
│   │   │   ├── dashboard.py, reports.py, insights.py
│   │   │   └── ...
│   │   │
│   │   ├── ai/                       # AI Integration Layer
│   │   │   ├── agents/
│   │   │   │   └── manager_agent.py  # Main orchestrator agent
│   │   │   ├── tools/
│   │   │   │   ├── tool_schemas.py   # 70+ tool definitions
│   │   │   │   ├── action_tools.py   # Write operations
│   │   │   │   ├── query_tools.py    # Read operations
│   │   │   │   ├── whatsapp_tools.py # WhatsApp integration
│   │   │   │   └── workflow_tools.py # Composite operations
│   │   │   ├── safety/
│   │   │   │   ├── permissions.py    # Role-based tool access
│   │   │   │   └── transaction_guard.py # Confirmation + limits
│   │   │   ├── prompts/
│   │   │   │   └── system_prompts.py # Agent instructions + voice commands
│   │   │   ├── memory/              # Conversation memory (pgvector)
│   │   │   ├── rag/                 # Retrieval-augmented generation
│   │   │   ├── embeddings/          # Vector embedding service
│   │   │   ├── executor.py          # Tool execution engine
│   │   │   ├── voice_orchestrator.py # Voice → AI → TTS pipeline
│   │   │   ├── anomaly_detector.py  # Statistical anomaly detection
│   │   │   ├── observability.py     # AI interaction logging
│   │   │   └── claude_client.py     # Anthropic API client
│   │   │
│   │   ├── websocket/
│   │   │   └── voice_events.py      # Voice WebSocket handler
│   │   ├── events/                  # Event bus + handlers
│   │   ├── tasks/                   # Celery background tasks
│   │   ├── core/                    # Auth, security, validators
│   │   └── utils/                   # Shared utilities
│   │
│   ├── requirements.txt
│   ├── Dockerfile
│   └── Dockerfile.celery
│
└── frontend/                         # Flutter (Dart)
    ├── pubspec.yaml
    └── lib/
        ├── main.dart
        ├── core/                     # Theme, router, network, DI
        ├── shared/                   # Shared layouts + widgets
        └── features/
            ├── ai_assistant/         # AI chat + voice UI
            ├── ai_audit/            # AI interaction audit logs
            ├── auth/                # Login / session
            ├── dashboard/           # KPI cards + charts
            ├── sales/              # Invoice management
            ├── purchases/          # Purchase management
            ├── inventory/          # Stock + warehouses
            ├── products/           # Product catalog
            ├── customers/          # Customer management
            ├── suppliers/          # Supplier management
            ├── expenses/           # Expense tracking
            ├── reports/            # Business reports
            ├── notifications/      # Alert center
            └── opening_balances/   # Initial setup
```

---

## User Roles & Permissions

| Role | Access Level |
|------|-------------|
| **Admin** | Full access to all 70+ tools |
| **Manager** | Sales, inventory, CRM, reports, WhatsApp, workflows, insights |
| **Cashier** | Sales, payments, customer lookup (no WhatsApp, no bulk) |
| **Warehouse Employee** | Inventory, stock, transfers (no financials) |
| **Accountant** | Finance, reports, ledger, expenses (no sales, no stock) |

---

## Safety & Guardrails

The AI system includes multiple layers of protection:

1. **Permission Engine** — Role-based tool access (blocked tools return clear error)
2. **Transaction Guard** — High-value operations (>5,000 EGP) require explicit confirmation
3. **Sensitive Operations** — Bulk WhatsApp, overdue reminders always need approval
4. **Dry-Run Previews** — Show what WOULD happen before executing
5. **Rollback Support** — Cancel operations that went wrong
6. **Idempotency** — Duplicate detection prevents double-execution
7. **Financial Limits** — Configurable thresholds per operation type
8. **Confirmation Flow** — Arabic-language confirmation with unique IDs

---

## Production Deployment

```bash
# Backend (Gunicorn with Uvicorn workers)
gunicorn app.main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000

# Celery (separate processes)
celery -A app.celery_app worker --loglevel=warning --concurrency=4
celery -A app.celery_app beat --loglevel=warning

# Frontend (build static)
cd frontend && flutter build web
# Serve frontend/build/web/ via Nginx
```

---

## Default Credentials

| Username | Password | Role |
|----------|----------|------|
| `admin` | `admin123` | Admin (full access) |

> **Change the password immediately after first login.**

---

## License

This project is open-source under the **MIT License**. See [LICENSE](LICENSE) for details.

---

<p align="center">
  <sub>Built with FastAPI + Flutter + Claude AI | Designed for Ceramic Showrooms | Arabic-first, English-supported</sub>
</p>
