from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.payments import CustomerPaymentCreate, SupplierPaymentCreate
from app.services.payment_service import PaymentService

router = APIRouter()


@router.post("/customers", status_code=201)
def receive_customer_payment(data: CustomerPaymentCreate, db: Session = Depends(get_db)):
    service = PaymentService(db)
    payment_id = service.receive_customer_payment(data)
    return {"detail": "Payment received", "payment_id": payment_id}


@router.post("/suppliers", status_code=201)
def make_supplier_payment(data: SupplierPaymentCreate, db: Session = Depends(get_db)):
    service = PaymentService(db)
    payment_id = service.make_supplier_payment(data)
    return {"detail": "Payment made", "payment_id": payment_id}
