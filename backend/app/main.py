from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from app.routers import products, categories, customers, suppliers, sales, purchases, inventory, payments, expenses, users

app = FastAPI(
    title="Ceramic Showroom ERP API",
    version="1.0.0",
    description="ERP system for ceramic showroom management",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(categories.router, prefix="/api/categories", tags=["Categories"])
app.include_router(products.router, prefix="/api/products", tags=["Products"])
app.include_router(inventory.router, prefix="/api/inventory", tags=["Inventory"])
app.include_router(customers.router, prefix="/api/customers", tags=["Customers"])
app.include_router(suppliers.router, prefix="/api/suppliers", tags=["Suppliers"])
app.include_router(sales.router, prefix="/api/sales", tags=["Sales"])
app.include_router(purchases.router, prefix="/api/purchases", tags=["Purchases"])
app.include_router(payments.router, prefix="/api/payments", tags=["Payments"])
app.include_router(expenses.router, prefix="/api/expenses", tags=["Expenses"])
app.include_router(users.router, prefix="/api/users", tags=["Users"])


@app.get("/")
def root():
    return {"message": "Ceramic Showroom ERP API", "version": "1.0.0"}


@app.get("/health")
def health_check():
    return {"status": "healthy"}
