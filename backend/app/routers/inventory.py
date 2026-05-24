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
    tx_type = data.transaction_type.lower()
    if tx_type == "opening_stock":
        service.record_opening_stock(
            product_id=data.product_id,
            warehouse_id=data.warehouse_id,
            quantity=data.quantity,
            unit_type=data.unit_type,
            cost_per_unit=data.cost_per_unit,
        )
    elif tx_type == "sale":
        service.record_sale(
            product_id=data.product_id,
            warehouse_id=data.warehouse_id,
            quantity=data.quantity,
            unit_type=data.unit_type,
            cost_per_unit=data.cost_per_unit,
            reference_id=data.reference_id or 0,
        )
    elif tx_type == "purchase":
        service.record_purchase(
            product_id=data.product_id,
            warehouse_id=data.warehouse_id,
            quantity=data.quantity,
            unit_type=data.unit_type,
            cost_per_unit=data.cost_per_unit,
            reference_id=data.reference_id or 0,
        )
    elif tx_type == "waste":
        service.record_waste(
            product_id=data.product_id,
            warehouse_id=data.warehouse_id,
            quantity=data.quantity,
            unit_type=data.unit_type,
            cost_per_unit=data.cost_per_unit,
            reference_id=data.reference_id or 0,
        )
    else:
        service.record_opening_stock(
            product_id=data.product_id,
            warehouse_id=data.warehouse_id,
            quantity=data.quantity,
            unit_type=data.unit_type,
            cost_per_unit=data.cost_per_unit,
        )
    db.commit()
    return {"detail": f"Transaction ({tx_type}) recorded successfully"}


@router.post("/opening-stock", status_code=201)
def create_opening_stock(data: InventoryTransactionCreate, current_user: User = Depends(require_permission("inventory:write")), db: Session = Depends(get_db)):
    service = InventoryService(db)
    service.record_opening_stock(
        product_id=data.product_id,
        warehouse_id=data.warehouse_id,
        quantity=data.quantity,
        unit_type=data.unit_type,
        cost_per_unit=data.cost_per_unit,
    )
    db.commit()
    return {"detail": "Opening stock recorded successfully"}


@router.post("/refresh-cache")
def refresh_cache(current_user: User = Depends(require_permission("inventory:write")), db: Session = Depends(get_db)):
    service = InventoryService(db)
    service.refresh_cache()
    db.commit()
    return {"detail": "Inventory cache refreshed"}
