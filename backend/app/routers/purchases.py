from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.purchases import PurchaseInvoiceCreate, PurchaseInvoiceResponse
from app.services.purchase_service import PurchaseService
from app.core.deps import require_permission
from app.models.users import User

router = APIRouter()


@router.get("/", response_model=list[PurchaseInvoiceResponse])
def list_purchases(current_user: User = Depends(require_permission("purchases:read")), db: Session = Depends(get_db)):
    service = PurchaseService(db)
    return service.list_invoices()


@router.post("/", response_model=PurchaseInvoiceResponse, status_code=201)
def create_purchase(data: PurchaseInvoiceCreate, current_user: User = Depends(require_permission("purchases:write")), db: Session = Depends(get_db)):
    service = PurchaseService(db)
    return service.create_invoice(data)
