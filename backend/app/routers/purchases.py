from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.purchases import PurchaseInvoiceCreate, PurchaseInvoiceResponse
from app.services.purchase_service import PurchaseService

router = APIRouter()


@router.get("/", response_model=list[PurchaseInvoiceResponse])
def list_purchases(db: Session = Depends(get_db)):
    service = PurchaseService(db)
    return service.list_invoices()


@router.post("/", response_model=PurchaseInvoiceResponse, status_code=201)
def create_purchase(data: PurchaseInvoiceCreate, db: Session = Depends(get_db)):
    service = PurchaseService(db)
    return service.create_invoice(data)
