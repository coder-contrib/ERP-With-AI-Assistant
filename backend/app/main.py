from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from app.core.exceptions import AppError
from app.core.middleware import app_error_handler
from app.events.registry import register_event_handlers
from app.routers import auth, products, categories, customers, suppliers, sales, purchases, inventory, payments, expenses, users, transfers, dashboard, tasks, ai, reports

app = FastAPI(
    title="Ceramic Showroom ERP API",
    version="3.2.0",
    description="Event-driven ERP system with AI assistant and reports",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_exception_handler(AppError, app_error_handler)
register_event_handlers()

app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"])
app.include_router(dashboard.router, prefix="/api/dashboard", tags=["Dashboard"])
app.include_router(ai.router, prefix="/api/ai", tags=["AI Assistant"])
app.include_router(reports.router, prefix="/api/reports", tags=["Reports"])
app.include_router(categories.router, prefix="/api/categories", tags=["Categories"])
app.include_router(products.router, prefix="/api/products", tags=["Products"])
app.include_router(inventory.router, prefix="/api/inventory", tags=["Inventory"])
app.include_router(transfers.router, prefix="/api/transfers", tags=["Transfers"])
app.include_router(customers.router, prefix="/api/customers", tags=["Customers"])
app.include_router(suppliers.router, prefix="/api/suppliers", tags=["Suppliers"])
app.include_router(sales.router, prefix="/api/sales", tags=["Sales"])
app.include_router(purchases.router, prefix="/api/purchases", tags=["Purchases"])
app.include_router(payments.router, prefix="/api/payments", tags=["Payments"])
app.include_router(expenses.router, prefix="/api/expenses", tags=["Expenses"])
app.include_router(users.router, prefix="/api/users", tags=["Users"])
app.include_router(tasks.router, prefix="/api/tasks", tags=["Background Tasks"])


@app.get("/")
def root():
    return {"message": "Ceramic Showroom ERP API", "version": "3.2.0"}


@app.get("/health")
def health_check():
    from app.core.redis import get_redis
    redis_ok = get_redis().ping()
    return {"status": "healthy", "redis": "connected" if redis_ok else "disconnected"}
