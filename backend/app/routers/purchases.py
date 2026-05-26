from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func
from decimal import Decimal
from datetime import datetime
from pydantic import BaseModel
from app.database import get_db
from app.schemas.purchases import (
    PurchaseInvoiceCreate,
    PurchaseInvoiceResponse,
    PurchaseReturnCreate,
    PurchaseReturnResponse,
)
from app.services.purchase_service import PurchaseService
from app.core.deps import require_permission
from app.models.users import User
from app.models.purchases import PurchaseInvoiceItem, PurchaseReturn, PurchaseReturnItem
from app.models.products import Product
from app.models.payments import SupplierPayment

router = APIRouter()


class PurchasePaymentResponse(BaseModel):
    payment_id: int
    payment_amount: Decimal
    payment_date: datetime | None
    notes: str | None

    class Config:
        from_attributes = True


class PurchaseItemResponse(BaseModel):
    item_id: int
    product_id: int
    product_name: str
    purchased_quantity: Decimal
    purchase_price: Decimal
    total_cost: Decimal
    returned_quantity: Decimal = Decimal("0")

    class Config:
        from_attributes = True


@router.get("/", response_model=list[PurchaseInvoiceResponse])
def list_purchases(
    current_user: User = Depends(require_permission("purchases:read")),
    db: Session = Depends(get_db),
):
    service = PurchaseService(db)
    return service.list_invoices()


@router.get("/{purchase_invoice_id}", response_model=PurchaseInvoiceResponse)
def get_purchase(
    purchase_invoice_id: int,
    current_user: User = Depends(require_permission("purchases:read")),
    db: Session = Depends(get_db),
):
    service = PurchaseService(db)
    return service.get_invoice(purchase_invoice_id)


@router.get("/{purchase_invoice_id}/items", response_model=list[PurchaseItemResponse])
def get_purchase_items(
    purchase_invoice_id: int,
    current_user: User = Depends(require_permission("purchases:read")),
    db: Session = Depends(get_db),
):
    returned_subq = (
        db.query(
            PurchaseReturnItem.product_id,
            func.coalesce(func.sum(PurchaseReturnItem.returned_quantity), 0).label("returned_qty"),
        )
        .join(PurchaseReturn, PurchaseReturn.return_id == PurchaseReturnItem.return_id)
        .filter(PurchaseReturn.original_purchase_invoice_id == purchase_invoice_id)
        .group_by(PurchaseReturnItem.product_id)
        .subquery()
    )

    rows = (
        db.query(
            PurchaseInvoiceItem.item_id,
            PurchaseInvoiceItem.product_id,
            Product.product_name,
            PurchaseInvoiceItem.purchased_quantity,
            PurchaseInvoiceItem.purchase_price,
            PurchaseInvoiceItem.total_cost,
            func.coalesce(returned_subq.c.returned_qty, 0).label("returned_quantity"),
        )
        .join(Product, Product.product_id == PurchaseInvoiceItem.product_id)
        .outerjoin(returned_subq, returned_subq.c.product_id == PurchaseInvoiceItem.product_id)
        .filter(PurchaseInvoiceItem.purchase_invoice_id == purchase_invoice_id)
        .all()
    )

    return [
        PurchaseItemResponse(
            item_id=r.item_id,
            product_id=r.product_id,
            product_name=r.product_name,
            purchased_quantity=r.purchased_quantity,
            purchase_price=r.purchase_price,
            total_cost=r.total_cost,
            returned_quantity=r.returned_quantity,
        )
        for r in rows
    ]


@router.get("/{purchase_invoice_id}/payments", response_model=list[PurchasePaymentResponse])
def get_purchase_payments(
    purchase_invoice_id: int,
    current_user: User = Depends(require_permission("purchases:read")),
    db: Session = Depends(get_db),
):
    payments = (
        db.query(SupplierPayment)
        .filter(SupplierPayment.related_purchase_invoice_id == purchase_invoice_id)
        .order_by(SupplierPayment.payment_date.desc())
        .all()
    )
    return payments


@router.post("/", response_model=PurchaseInvoiceResponse, status_code=201)
def create_purchase(
    data: PurchaseInvoiceCreate,
    current_user: User = Depends(require_permission("purchases:write")),
    db: Session = Depends(get_db),
):
    service = PurchaseService(db)
    return service.create_invoice(data)


@router.post("/{purchase_invoice_id}/returns", response_model=PurchaseReturnResponse, status_code=201)
def create_purchase_return(
    purchase_invoice_id: int,
    data: PurchaseReturnCreate,
    current_user: User = Depends(require_permission("purchases:write")),
    db: Session = Depends(get_db),
):
    service = PurchaseService(db)
    return service.process_return(purchase_invoice_id, data)


@router.get("/{purchase_invoice_id}/returns", response_model=list[PurchaseReturnResponse])
def get_purchase_returns(
    purchase_invoice_id: int,
    current_user: User = Depends(require_permission("purchases:read")),
    db: Session = Depends(get_db),
):
    service = PurchaseService(db)
    return service.repo.get_returns_for_invoice(purchase_invoice_id)
