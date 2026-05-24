from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.inventory import StockResponse, InventoryTransactionCreate
from app.services.inventory_service import InventoryService
from app.core.deps import require_permission
from app.models.users import User

router = APIRouter()


@router.get("/stock", response_model=list[StockResponse])
def get_stock(warehouse_id: int | None = None, current_user: User = Depends(require_permission("inventory:read")), db: Session = Depends(get_db)):
    service = InventoryService(db)
    return service.get_stock(warehouse_id)


@router.get("/stock/{product_id}", response_model=list[StockResponse])
def get_product_stock(product_id: int, current_user: User = Depends(require_permission("inventory:read")), db: Session = Depends(get_db)):
    service = InventoryService(db)
    return service.get_product_stock(product_id)


@router.post("/transactions", status_code=201)
def create_transaction(data: InventoryTransactionCreate, current_user: User = Depends(require_permission("inventory:write")), db: Session = Depends(get_db)):
    service = InventoryService(db)
    result = service.create_transaction(data)
    db.commit()
    return result


@router.post("/opening-stock", status_code=201)
def create_opening_stock(data: InventoryTransactionCreate, current_user: User = Depends(require_permission("inventory:write")), db: Session = Depends(get_db)):
    data.transaction_type = "opening_stock"
    data.direction = "in"
    service = InventoryService(db)
    result = service.create_transaction(data)
    db.commit()
    return result


@router.post("/refresh-cache")
def refresh_cache(current_user: User = Depends(require_permission("inventory:write")), db: Session = Depends(get_db)):
    service = InventoryService(db)
    service.refresh_cache()
    db.commit()
    return {"detail": "Inventory cache refreshed"}
