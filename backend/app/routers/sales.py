from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.sales import SalesInvoiceCreate, SalesInvoiceResponse
from app.services.sales_service import SalesService
from app.core.deps import require_permission
from app.models.users import User
from app.models.payments import CustomerPayment
from pydantic import BaseModel
from decimal import Decimal
from datetime import datetime

router = APIRouter()


class InvoicePaymentResponse(BaseModel):
    payment_id: int
    payment_amount: Decimal
    payment_date: datetime | None
    notes: str | None

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
