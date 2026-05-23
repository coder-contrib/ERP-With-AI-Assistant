from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.inventory import StockResponse
from app.services.inventory_service import InventoryService

router = APIRouter()


@router.get("/stock", response_model=list[StockResponse])
def get_stock(warehouse_id: int | None = None, db: Session = Depends(get_db)):
    service = InventoryService(db)
    return service.get_stock(warehouse_id)


@router.get("/stock/{product_id}", response_model=list[StockResponse])
def get_product_stock(product_id: int, db: Session = Depends(get_db)):
    service = InventoryService(db)
    return service.get_product_stock(product_id)


@router.post("/refresh-cache")
def refresh_cache(db: Session = Depends(get_db)):
    service = InventoryService(db)
    service.refresh_cache()
    db.commit()
    return {"detail": "Inventory cache refreshed"}
