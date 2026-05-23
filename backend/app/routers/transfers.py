from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.transfers import TransferCreate, TransferResponse
from app.services.transfer_service import TransferService
from app.core.deps import require_permission
from app.models.users import User

router = APIRouter()


@router.post("/", response_model=TransferResponse, status_code=201)
def create_transfer(data: TransferCreate, current_user: User = Depends(require_permission("inventory:transfer")), db: Session = Depends(get_db)):
    service = TransferService(db)
    return service.create_transfer(
        from_warehouse_id=data.from_warehouse_id,
        to_warehouse_id=data.to_warehouse_id,
        product_id=data.product_id,
        quantity=data.quantity,
        unit_type=data.unit_type,
        notes=data.notes,
    )
