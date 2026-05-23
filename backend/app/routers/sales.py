from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.sales import SalesInvoiceCreate, SalesInvoiceResponse
from app.services.sales_service import SalesService
from app.core.deps import require_permission
from app.models.users import User

router = APIRouter()


@router.get("/", response_model=list[SalesInvoiceResponse])
def list_sales(current_user: User = Depends(require_permission("sales:read")), db: Session = Depends(get_db)):
    service = SalesService(db)
    return service.list_invoices()


@router.get("/{invoice_id}", response_model=SalesInvoiceResponse)
def get_sale(invoice_id: int, current_user: User = Depends(require_permission("sales:read")), db: Session = Depends(get_db)):
    service = SalesService(db)
    return service.get_invoice(invoice_id)


@router.post("/", response_model=SalesInvoiceResponse, status_code=201)
def create_sale(data: SalesInvoiceCreate, current_user: User = Depends(require_permission("sales:write")), db: Session = Depends(get_db)):
    service = SalesService(db)
    return service.create_invoice(data)
