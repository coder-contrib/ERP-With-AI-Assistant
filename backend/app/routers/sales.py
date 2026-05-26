from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.sales import SalesInvoiceCreate, SalesInvoiceResponse, SalesReturnCreate, SalesReturnResponse
from app.services.sales_service import SalesService
from app.core.deps import require_permission
from app.models.users import User
from app.models.payments import CustomerPayment
from app.models.sales import SalesInvoiceItem, SalesReturnItem, SalesReturn
from app.models.products import Product
from pydantic import BaseModel
from decimal import Decimal
from datetime import datetime
from sqlalchemy import func

router = APIRouter()


class InvoicePaymentResponse(BaseModel):
    payment_id: int
    payment_amount: Decimal
    payment_date: datetime | None
    notes: str | None

    class Config:
        from_attributes = True


class InvoiceItemResponse(BaseModel):
    item_id: int
    product_id: int
    product_name: str
    sold_quantity: Decimal
    unit_type: str
    unit_price: Decimal
    discount: Decimal
    total_price: Decimal
    returned_quantity: Decimal = Decimal("0")

    class Config:
        from_attributes = True


@router.get("/", response_model=list[SalesInvoiceResponse])
def list_sales(current_user: User = Depends(require_permission("sales:read")), db: Session = Depends(get_db)):
    service = SalesService(db)
    return service.list_invoices()


@router.get("/{invoice_id}", response_model=SalesInvoiceResponse)
def get_sale(invoice_id: int, current_user: User = Depends(require_permission("sales:read")), db: Session = Depends(get_db)):
    service = SalesService(db)
    return service.get_invoice(invoice_id)


@router.get("/{invoice_id}/items", response_model=list[InvoiceItemResponse])
def get_invoice_items(invoice_id: int, current_user: User = Depends(require_permission("sales:read")), db: Session = Depends(get_db)):
    returned_subq = (
        db.query(
            SalesReturnItem.product_id,
            func.coalesce(func.sum(SalesReturnItem.returned_quantity), 0).label("returned_qty"),
        )
        .join(SalesReturn, SalesReturn.return_id == SalesReturnItem.return_id)
        .filter(SalesReturn.original_invoice_id == invoice_id)
        .group_by(SalesReturnItem.product_id)
        .subquery()
    )

    rows = (
        db.query(
            SalesInvoiceItem.item_id,
            SalesInvoiceItem.product_id,
            Product.product_name,
            SalesInvoiceItem.sold_quantity,
            SalesInvoiceItem.unit_type,
            SalesInvoiceItem.unit_price,
            SalesInvoiceItem.discount,
            SalesInvoiceItem.total_price,
            func.coalesce(returned_subq.c.returned_qty, 0).label("returned_quantity"),
        )
        .join(Product, Product.product_id == SalesInvoiceItem.product_id)
        .outerjoin(returned_subq, returned_subq.c.product_id == SalesInvoiceItem.product_id)
        .filter(SalesInvoiceItem.invoice_id == invoice_id)
        .all()
    )
    return [
        InvoiceItemResponse(
            item_id=r.item_id,
            product_id=r.product_id,
            product_name=r.product_name,
            sold_quantity=r.sold_quantity,
            unit_type=r.unit_type,
            unit_price=r.unit_price,
            discount=r.discount,
            total_price=r.total_price,
            returned_quantity=r.returned_quantity,
        )
        for r in rows
    ]


@router.get("/{invoice_id}/payments", response_model=list[InvoicePaymentResponse])
def get_invoice_payments(invoice_id: int, current_user: User = Depends(require_permission("sales:read")), db: Session = Depends(get_db)):
    payments = (
        db.query(CustomerPayment)
        .filter(CustomerPayment.related_invoice_id == invoice_id)
        .order_by(CustomerPayment.payment_date.desc())
        .all()
    )
    return payments


@router.post("/", response_model=SalesInvoiceResponse, status_code=201)
def create_sale(data: SalesInvoiceCreate, current_user: User = Depends(require_permission("sales:write")), db: Session = Depends(get_db)):
    service = SalesService(db)
    return service.create_invoice(data)


@router.post("/{invoice_id}/returns", response_model=SalesReturnResponse, status_code=201)
def create_return(invoice_id: int, data: SalesReturnCreate, current_user: User = Depends(require_permission("sales:write")), db: Session = Depends(get_db)):
    service = SalesService(db)
    return service.process_return(invoice_id, data)


@router.get("/{invoice_id}/returns", response_model=list[SalesReturnResponse])
def get_returns(invoice_id: int, current_user: User = Depends(require_permission("sales:read")), db: Session = Depends(get_db)):
    service = SalesService(db)
    return service.repo.get_returns_for_invoice(invoice_id)
