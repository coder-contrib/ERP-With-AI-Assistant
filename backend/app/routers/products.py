from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func
from decimal import Decimal
from datetime import datetime, timedelta
from app.database import get_db
from app.schemas.products import ProductCreate, ProductUpdate, ProductResponse, ConversionCreate, ConversionResponse
from app.services.product_service import ProductService
from app.core.deps import require_permission
from app.models.users import User
from app.models.sales import SalesInvoiceItem, SalesInvoice
from app.models.purchases import PurchaseInvoiceItem, PurchaseInvoice

router = APIRouter()


@router.get("/", response_model=list[ProductResponse])
def list_products(active_only: bool = True, current_user: User = Depends(require_permission("products:read")), db: Session = Depends(get_db)):
    service = ProductService(db)
    return service.list_all(active_only)


@router.get("/{product_id}", response_model=ProductResponse)
def get_product(product_id: int, current_user: User = Depends(require_permission("products:read")), db: Session = Depends(get_db)):
    service = ProductService(db)
    return service.get(product_id)


@router.get("/{product_id}/analytics")
def get_product_analytics(product_id: int, current_user: User = Depends(require_permission("products:read")), db: Session = Depends(get_db)):
    service = ProductService(db)
    service.get(product_id)

    now = datetime.utcnow()
    thirty_days_ago = now - timedelta(days=30)
    ninety_days_ago = now - timedelta(days=90)

    # Total sales stats (all time)
    total_sales = db.query(
        func.coalesce(func.sum(SalesInvoiceItem.sold_quantity), 0).label("total_qty"),
        func.coalesce(func.sum(SalesInvoiceItem.total_price), 0).label("total_revenue"),
        func.count(SalesInvoiceItem.item_id).label("total_transactions"),
    ).filter(SalesInvoiceItem.product_id == product_id).first()

    # Last 30 days sales
    recent_sales = db.query(
        func.coalesce(func.sum(SalesInvoiceItem.sold_quantity), 0).label("qty"),
        func.coalesce(func.sum(SalesInvoiceItem.total_price), 0).label("revenue"),
        func.count(SalesInvoiceItem.item_id).label("count"),
    ).join(SalesInvoice, SalesInvoice.invoice_id == SalesInvoiceItem.invoice_id).filter(
        SalesInvoiceItem.product_id == product_id,
        SalesInvoice.invoice_date >= thirty_days_ago,
    ).first()

    # Previous 30 days (30-60 days ago) for comparison
    prev_period = db.query(
        func.coalesce(func.sum(SalesInvoiceItem.sold_quantity), 0).label("qty"),
        func.coalesce(func.sum(SalesInvoiceItem.total_price), 0).label("revenue"),
    ).join(SalesInvoice, SalesInvoice.invoice_id == SalesInvoiceItem.invoice_id).filter(
        SalesInvoiceItem.product_id == product_id,
        SalesInvoice.invoice_date >= thirty_days_ago - timedelta(days=30),
        SalesInvoice.invoice_date < thirty_days_ago,
    ).first()

    # Total purchases (all time)
    total_purchases = db.query(
        func.coalesce(func.sum(PurchaseInvoiceItem.purchased_quantity), 0).label("total_qty"),
        func.coalesce(func.sum(PurchaseInvoiceItem.total_cost), 0).label("total_cost"),
    ).filter(PurchaseInvoiceItem.product_id == product_id).first()

    # Average selling price
    avg_price = db.query(
        func.avg(SalesInvoiceItem.unit_price),
    ).filter(SalesInvoiceItem.product_id == product_id).scalar()

    # Profit calculation
    total_revenue = float(total_sales.total_revenue or 0)
    total_cost_of_sold = db.query(
        func.coalesce(func.sum(SalesInvoiceItem.cost_at_sale * SalesInvoiceItem.sold_quantity), 0),
    ).filter(SalesInvoiceItem.product_id == product_id).scalar()
    total_profit = total_revenue - float(total_cost_of_sold or 0)

    # Trend calculation
    recent_qty = float(recent_sales.qty or 0)
    prev_qty = float(prev_period.qty or 0)
    if prev_qty > 0:
        trend_pct = ((recent_qty - prev_qty) / prev_qty) * 100
    elif recent_qty > 0:
        trend_pct = 100.0
    else:
        trend_pct = 0.0

    if trend_pct > 10:
        trend = "rising"
    elif trend_pct < -10:
        trend = "declining"
    else:
        trend = "stable"

    return {
        "total_sold_quantity": float(total_sales.total_qty or 0),
        "total_revenue": float(total_sales.total_revenue or 0),
        "total_transactions": int(total_sales.total_transactions or 0),
        "total_purchased_quantity": float(total_purchases.total_qty or 0),
        "total_purchase_cost": float(total_purchases.total_cost or 0),
        "total_profit": round(total_profit, 2),
        "average_selling_price": round(float(avg_price or 0), 2),
        "last_30_days": {
            "sold_quantity": float(recent_sales.qty or 0),
            "revenue": float(recent_sales.revenue or 0),
            "transactions": int(recent_sales.count or 0),
        },
        "previous_30_days": {
            "sold_quantity": float(prev_period.qty or 0),
            "revenue": float(prev_period.revenue or 0),
        },
        "trend": trend,
        "trend_percentage": round(trend_pct, 1),
    }


@router.post("/", response_model=ProductResponse, status_code=201)
def create_product(data: ProductCreate, current_user: User = Depends(require_permission("products:write")), db: Session = Depends(get_db)):
    service = ProductService(db)
    return service.create(data)


@router.put("/{product_id}", response_model=ProductResponse)
def update_product(product_id: int, data: ProductUpdate, current_user: User = Depends(require_permission("products:write")), db: Session = Depends(get_db)):
    service = ProductService(db)
    return service.update(product_id, data)


@router.delete("/{product_id}", response_model=ProductResponse)
def delete_product(product_id: int, current_user: User = Depends(require_permission("products:write")), db: Session = Depends(get_db)):
    service = ProductService(db)
    return service.deactivate(product_id)


@router.post("/{product_id}/toggle-status", response_model=ProductResponse)
def toggle_product_status(product_id: int, current_user: User = Depends(require_permission("products:write")), db: Session = Depends(get_db)):
    service = ProductService(db)
    return service.toggle_status(product_id)


@router.get("/{product_id}/conversions", response_model=list[ConversionResponse])
def get_conversions(product_id: int, current_user: User = Depends(require_permission("products:read")), db: Session = Depends(get_db)):
    service = ProductService(db)
    return service.get_conversions(product_id)


@router.post("/{product_id}/conversions", response_model=ConversionResponse, status_code=201)
def add_conversion(product_id: int, data: ConversionCreate, current_user: User = Depends(require_permission("products:write")), db: Session = Depends(get_db)):
    service = ProductService(db)
    return service.add_conversion(product_id, data)


@router.delete("/{product_id}/conversions/{conversion_id}", status_code=204)
def delete_conversion(product_id: int, conversion_id: int, current_user: User = Depends(require_permission("products:write")), db: Session = Depends(get_db)):
    service = ProductService(db)
    service.delete_conversion(product_id, conversion_id)
