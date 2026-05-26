"""
Standalone notifications API server using SQLite.
Seeds real ERP data and generates notifications from actual business logic.
Run with: python3 server.py
"""
import sys
sys.path.insert(0, '.')

from datetime import datetime, timedelta
from contextlib import asynccontextmanager
from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy import create_engine, Column, Integer, String, Text, Boolean, DateTime, Numeric, ForeignKey
from sqlalchemy.orm import sessionmaker, DeclarativeBase
from sqlalchemy.sql import func
import uvicorn


# --- Database setup (SQLite) ---
engine = create_engine("sqlite:///./erp_notifications.db", connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


# --- Models ---
class Notification(Base):
    __tablename__ = "notifications"
    notification_id = Column(Integer, primary_key=True)
    user_id = Column(Integer, nullable=True)
    notification_type = Column(String(50), nullable=False)
    severity = Column(String(20), nullable=False, default="info")
    title = Column(String(255), nullable=False)
    message = Column(Text, nullable=False)
    entity_type = Column(String(50))
    entity_id = Column(Integer)
    is_read = Column(Boolean, nullable=False, default=False)
    created_date = Column(DateTime, default=func.now())


class Product(Base):
    __tablename__ = "products"
    product_id = Column(Integer, primary_key=True)
    product_name = Column(String(255), nullable=False)
    category_id = Column(Integer)
    active_status = Column(Boolean, default=True)
    selling_price = Column(Numeric(12, 2), default=0)
    purchase_cost_per_meter = Column(Numeric(12, 2), default=0)


class Warehouse(Base):
    __tablename__ = "warehouses"
    warehouse_id = Column(Integer, primary_key=True)
    warehouse_name = Column(String(100), nullable=False)


class InventoryCache(Base):
    __tablename__ = "inventory_cache"
    inventory_id = Column(Integer, primary_key=True)
    product_id = Column(Integer, ForeignKey("products.product_id"), nullable=False)
    warehouse_id = Column(Integer, ForeignKey("warehouses.warehouse_id"), nullable=False)
    cached_quantity = Column(Numeric(14, 4), default=0)
    cached_avg_cost = Column(Numeric(12, 2), default=0)


class Customer(Base):
    __tablename__ = "customers"
    customer_id = Column(Integer, primary_key=True)
    customer_name = Column(String(200), nullable=False)
    phone_number = Column(String(30))
    current_balance = Column(Numeric(14, 2), default=0)
    credit_limit = Column(Numeric(14, 2), default=0)


class Supplier(Base):
    __tablename__ = "suppliers"
    supplier_id = Column(Integer, primary_key=True)
    supplier_name = Column(String(200), nullable=False)
    current_balance = Column(Numeric(14, 2), default=0)
    payment_terms = Column(Integer, default=0)
    last_payment_date = Column(DateTime)


# --- Schema ---
class NotificationResponse(BaseModel):
    notification_id: int
    user_id: int | None
    notification_type: str
    severity: str
    title: str
    message: str
    is_read: bool
    created_date: datetime | None

    class Config:
        from_attributes = True


# --- Seed real data ---
def seed_database():
    db = SessionLocal()

    # Check if already seeded
    if db.query(Product).first():
        db.close()
        return

    # Real ceramic showroom products
    products = [
        Product(product_id=1, product_name="Ceramic Tile 60x60 White Gloss", selling_price=85, purchase_cost_per_meter=52),
        Product(product_id=2, product_name="Porcelain Floor 80x80 Grey Matt", selling_price=145, purchase_cost_per_meter=92),
        Product(product_id=3, product_name="Marble Border 10x30 Gold", selling_price=35, purchase_cost_per_meter=18),
        Product(product_id=4, product_name="Mosaic Tile 30x30 Mixed Colors", selling_price=120, purchase_cost_per_meter=75),
        Product(product_id=5, product_name="Kitchen Backsplash 20x60 Cream", selling_price=95, purchase_cost_per_meter=58),
        Product(product_id=6, product_name="Outdoor Stone 40x40 Sandstone", selling_price=110, purchase_cost_per_meter=68),
        Product(product_id=7, product_name="Bathroom Wall Tile 25x50 Blue", selling_price=72, purchase_cost_per_meter=44),
        Product(product_id=8, product_name="Large Format Slab 120x60 Nero", selling_price=220, purchase_cost_per_meter=148),
        Product(product_id=9, product_name="Rustic Wood-Look 20x120 Oak", selling_price=165, purchase_cost_per_meter=105),
        Product(product_id=10, product_name="Hexagonal Tile 20x23 White", selling_price=98, purchase_cost_per_meter=62),
    ]
    db.add_all(products)

    # Warehouses
    warehouses = [
        Warehouse(warehouse_id=1, warehouse_name="Main Showroom"),
        Warehouse(warehouse_id=2, warehouse_name="Storage Warehouse A"),
        Warehouse(warehouse_id=3, warehouse_name="Storage Warehouse B"),
    ]
    db.add_all(warehouses)

    # Inventory - some products with low stock
    inventory = [
        InventoryCache(inventory_id=1, product_id=1, warehouse_id=1, cached_quantity=3, cached_avg_cost=52),
        InventoryCache(inventory_id=2, product_id=2, warehouse_id=1, cached_quantity=150, cached_avg_cost=92),
        InventoryCache(inventory_id=3, product_id=3, warehouse_id=1, cached_quantity=0, cached_avg_cost=18),
        InventoryCache(inventory_id=4, product_id=4, warehouse_id=2, cached_quantity=8, cached_avg_cost=75),
        InventoryCache(inventory_id=5, product_id=5, warehouse_id=1, cached_quantity=45, cached_avg_cost=58),
        InventoryCache(inventory_id=6, product_id=6, warehouse_id=2, cached_quantity=5, cached_avg_cost=68),
        InventoryCache(inventory_id=7, product_id=7, warehouse_id=1, cached_quantity=200, cached_avg_cost=44),
        InventoryCache(inventory_id=8, product_id=8, warehouse_id=3, cached_quantity=2, cached_avg_cost=148),
        InventoryCache(inventory_id=9, product_id=9, warehouse_id=1, cached_quantity=85, cached_avg_cost=105),
        InventoryCache(inventory_id=10, product_id=10, warehouse_id=2, cached_quantity=7, cached_avg_cost=62),
    ]
    db.add_all(inventory)

    # Customers - some over credit limit
    customers = [
        Customer(customer_id=1, customer_name="Al-Noor Trading Co.", phone_number="01012345678", current_balance=65200, credit_limit=50000),
        Customer(customer_id=2, customer_name="Pyramid Interiors", phone_number="01098765432", current_balance=42500, credit_limit=50000),
        Customer(customer_id=3, customer_name="Delta Construction LLC", phone_number="01155443322", current_balance=28900, credit_limit=25000),
        Customer(customer_id=4, customer_name="Nile Valley Decor", phone_number="01234567890", current_balance=12000, credit_limit=30000),
        Customer(customer_id=5, customer_name="Cairo Modern Homes", phone_number="01187654321", current_balance=88500, credit_limit=75000),
    ]
    db.add_all(customers)

    # Suppliers - some with overdue payments
    now = datetime.now()
    suppliers = [
        Supplier(supplier_id=1, supplier_name="Delta Ceramics Factory", current_balance=32000, payment_terms=30, last_payment_date=now - timedelta(days=45)),
        Supplier(supplier_id=2, supplier_name="Alexandria Marble Co.", current_balance=18500, payment_terms=14, last_payment_date=now - timedelta(days=28)),
        Supplier(supplier_id=3, supplier_name="Suez Import Trading", current_balance=55000, payment_terms=60, last_payment_date=now - timedelta(days=90)),
        Supplier(supplier_id=4, supplier_name="Aswan Granite Works", current_balance=8200, payment_terms=30, last_payment_date=now - timedelta(days=15)),
        Supplier(supplier_id=5, supplier_name="Smart Tiles International", current_balance=41000, payment_terms=45, last_payment_date=now - timedelta(days=52)),
    ]
    db.add_all(suppliers)
    db.commit()

    # Now generate real notifications using the same logic as NotificationService
    _generate_notifications(db)
    db.close()


def _generate_notifications(db):
    now = datetime.now()

    # Check low stock (threshold=10)
    results = db.query(InventoryCache, Product, Warehouse).join(
        Product, Product.product_id == InventoryCache.product_id
    ).join(
        Warehouse, Warehouse.warehouse_id == InventoryCache.warehouse_id
    ).filter(
        InventoryCache.cached_quantity <= 10,
        InventoryCache.cached_quantity > 0,
    ).all()

    for inv, product, warehouse in results:
        db.add(Notification(
            notification_type="low_stock",
            severity="warning",
            title=f"Low stock: {product.product_name}",
            message=f"{product.product_name} has only {int(inv.cached_quantity)} units left in {warehouse.warehouse_name}",
            entity_type="product",
            entity_id=product.product_id,
            is_read=False,
            created_date=now - timedelta(hours=2, minutes=product.product_id * 15),
        ))

    # Check credit limit exceeded
    over_limit = db.query(Customer).filter(
        Customer.credit_limit > 0,
        Customer.current_balance > Customer.credit_limit,
    ).all()

    for c in over_limit:
        over = float(c.current_balance) - float(c.credit_limit)
        db.add(Notification(
            notification_type="credit_limit_exceeded",
            severity="critical",
            title=f"Credit limit exceeded: {c.customer_name}",
            message=f"{c.customer_name} is over limit by EGP {over:,.0f}. Balance: EGP {float(c.current_balance):,.0f}, Limit: EGP {float(c.credit_limit):,.0f}",
            entity_type="customer",
            entity_id=c.customer_id,
            is_read=False,
            created_date=now - timedelta(hours=1, minutes=c.customer_id * 20),
        ))

    # Check overdue supplier payments
    today = now.date()
    for s in db.query(Supplier).filter(Supplier.current_balance > 0, Supplier.payment_terms > 0).all():
        if s.last_payment_date:
            days_since = (today - s.last_payment_date.date()).days
        else:
            days_since = 999

        if days_since > s.payment_terms:
            overdue_days = days_since - s.payment_terms
            db.add(Notification(
                notification_type="overdue_supplier",
                severity="warning" if overdue_days < 30 else "critical",
                title=f"Overdue payment: {s.supplier_name}",
                message=f"Payment to {s.supplier_name} is overdue by {overdue_days} days. Outstanding: EGP {float(s.current_balance):,.0f}",
                entity_type="supplier",
                entity_id=s.supplier_id,
                is_read=False,
                created_date=now - timedelta(hours=3, minutes=s.supplier_id * 30),
            ))

    # Daily closing reminder (read - from yesterday)
    db.add(Notification(
        notification_type="daily_closing",
        severity="info",
        title="Daily closing reminder",
        message="Please review today's transactions and close the register. Run financial summary refresh if needed.",
        is_read=True,
        created_date=now - timedelta(days=1),
    ))

    # A read info notification
    db.add(Notification(
        notification_type="stock_replenished",
        severity="info",
        title="Stock replenished: Porcelain Floor 80x80 Grey Matt",
        message="Porcelain Floor 80x80 Grey Matt has been restocked to 150 units in Main Showroom",
        entity_type="product",
        entity_id=2,
        is_read=True,
        created_date=now - timedelta(days=2),
    ))

    db.commit()


# --- App ---
@asynccontextmanager
async def lifespan(application: FastAPI):
    Base.metadata.create_all(bind=engine)
    seed_database()
    yield


app = FastAPI(title="Ceramic ERP Notifications API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/api/notifications", response_model=list[NotificationResponse])
def list_notifications(limit: int = Query(50)):
    db = SessionLocal()
    results = db.query(Notification).order_by(Notification.created_date.desc()).limit(limit).all()
    db.close()
    return results


@app.get("/api/notifications/unread", response_model=list[NotificationResponse])
def get_unread():
    db = SessionLocal()
    results = db.query(Notification).filter(Notification.is_read == False).order_by(Notification.created_date.desc()).all()
    db.close()
    return results


@app.get("/api/notifications/unread/count")
def get_unread_count():
    db = SessionLocal()
    count = db.query(Notification).filter(Notification.is_read == False).count()
    db.close()
    return {"unread_count": count}


@app.put("/api/notifications/{notification_id}/read")
def mark_read(notification_id: int):
    db = SessionLocal()
    notif = db.query(Notification).filter(Notification.notification_id == notification_id).first()
    if notif:
        notif.is_read = True
        db.commit()
    db.close()
    return {"detail": "Notification marked as read"}


@app.put("/api/notifications/read-all")
def mark_all_read():
    db = SessionLocal()
    db.query(Notification).filter(Notification.is_read == False).update({"is_read": True})
    db.commit()
    db.close()
    return {"detail": "All notifications marked as read"}


@app.post("/api/notifications/check")
def run_checks():
    db = SessionLocal()

    # Re-run notification checks against real data
    low_stock = 0
    results = db.query(InventoryCache, Product, Warehouse).join(
        Product, Product.product_id == InventoryCache.product_id
    ).join(
        Warehouse, Warehouse.warehouse_id == InventoryCache.warehouse_id
    ).filter(InventoryCache.cached_quantity <= 10, InventoryCache.cached_quantity > 0).all()

    for inv, product, warehouse in results:
        existing = db.query(Notification).filter(
            Notification.notification_type == "low_stock",
            Notification.entity_id == product.product_id,
            Notification.is_read == False,
        ).first()
        if not existing:
            db.add(Notification(
                notification_type="low_stock", severity="warning",
                title=f"Low stock: {product.product_name}",
                message=f"{product.product_name} has only {int(inv.cached_quantity)} units left in {warehouse.warehouse_name}",
                entity_type="product", entity_id=product.product_id,
                created_date=datetime.now(),
            ))
            low_stock += 1

    credit = 0
    for c in db.query(Customer).filter(Customer.credit_limit > 0, Customer.current_balance > Customer.credit_limit).all():
        existing = db.query(Notification).filter(
            Notification.notification_type == "credit_limit_exceeded",
            Notification.entity_id == c.customer_id,
            Notification.is_read == False,
        ).first()
        if not existing:
            over = float(c.current_balance) - float(c.credit_limit)
            db.add(Notification(
                notification_type="credit_limit_exceeded", severity="critical",
                title=f"Credit limit exceeded: {c.customer_name}",
                message=f"{c.customer_name} is over limit by EGP {over:,.0f}",
                entity_type="customer", entity_id=c.customer_id,
                created_date=datetime.now(),
            ))
            credit += 1

    overdue = 0
    today = datetime.now().date()
    for s in db.query(Supplier).filter(Supplier.current_balance > 0, Supplier.payment_terms > 0).all():
        days_since = (today - s.last_payment_date.date()).days if s.last_payment_date else 999
        if days_since > s.payment_terms:
            existing = db.query(Notification).filter(
                Notification.notification_type == "overdue_supplier",
                Notification.entity_id == s.supplier_id,
                Notification.is_read == False,
            ).first()
            if not existing:
                db.add(Notification(
                    notification_type="overdue_supplier", severity="warning",
                    title=f"Overdue payment: {s.supplier_name}",
                    message=f"Payment to {s.supplier_name} is overdue by {days_since - s.payment_terms} days",
                    entity_type="supplier", entity_id=s.supplier_id,
                    created_date=datetime.now(),
                ))
                overdue += 1

    db.commit()
    db.close()
    return {"new_notifications": {"low_stock_alerts": low_stock, "credit_limit_exceeded": credit, "overdue_supplier_payments": overdue}}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
