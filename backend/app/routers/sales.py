from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.sales import SalesInvoiceCreate, SalesInvoiceResponse
from app.services.sales_service import SalesService

router = APIRouter()


@router.get("/", response_model=list[SalesInvoiceResponse])
def list_sales(db: Session = Depends(get_db)):
    service = SalesService(db)
    return service.list_invoices()


@router.get("/{invoice_id}", response_model=SalesInvoiceResponse)
def get_sale(invoice_id: int, db: Session = Depends(get_db)):
    service = SalesService(db)
    return service.get_invoice(invoice_id)


@router.post("/", response_model=SalesInvoiceResponse, status_code=201)
def create_sale(data: SalesInvoiceCreate, db: Session = Depends(get_db)):
    service = SalesService(db)
    return service.create_invoice(data)
