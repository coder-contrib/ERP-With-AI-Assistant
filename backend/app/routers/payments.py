from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from decimal import Decimal
from app.database import get_db
from app.models.payments import CustomerPayment, SupplierPayment, CashTransaction
from app.models.customers import Customer
from app.models.suppliers import Supplier

router = APIRouter()


class CustomerPaymentCreate(BaseModel):
    customer_id: int
    related_invoice_id: int | None = None
    payment_amount: Decimal
    notes: str | None = None


class SupplierPaymentCreate(BaseModel):
    supplier_id: int
    related_purchase_invoice_id: int | None = None
    payment_amount: Decimal
    notes: str | None = None


@router.post("/customers", status_code=201)
def receive_customer_payment(data: CustomerPaymentCreate, db: Session = Depends(get_db)):
    payment = CustomerPayment(**data.model_dump())
    db.add(payment)

    customer = db.query(Customer).filter(Customer.customer_id == data.customer_id).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")
    customer.current_balance -= data.payment_amount

    cash_txn = CashTransaction(
        transaction_type="cash_in",
        amount=data.payment_amount,
        entity_type="customer_payment",
        entity_id=data.customer_id,
    )
    db.add(cash_txn)
    db.commit()
    return {"detail": "Payment received", "payment_id": payment.payment_id}


@router.post("/suppliers", status_code=201)
def make_supplier_payment(data: SupplierPaymentCreate, db: Session = Depends(get_db)):
    payment = SupplierPayment(**data.model_dump())
    db.add(payment)

    supplier = db.query(Supplier).filter(Supplier.supplier_id == data.supplier_id).first()
    if not supplier:
        raise HTTPException(status_code=404, detail="Supplier not found")
    supplier.current_balance -= data.payment_amount

    cash_txn = CashTransaction(
        transaction_type="cash_out",
        amount=data.payment_amount,
        entity_type="supplier_payment",
        entity_id=data.supplier_id,
    )
    db.add(cash_txn)
    db.commit()
    return {"detail": "Payment made", "payment_id": payment.payment_id}
