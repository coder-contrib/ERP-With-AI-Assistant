from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel
from decimal import Decimal
from app.database import get_db
from app.models.inventory import InventoryCache

router = APIRouter()


class StockResponse(BaseModel):
    product_id: int
    warehouse_id: int
    cached_quantity: Decimal
    cached_avg_cost: Decimal

    class Config:
        from_attributes = True


@router.get("/stock", response_model=list[StockResponse])
def get_stock(warehouse_id: int | None = None, db: Session = Depends(get_db)):
    query = db.query(InventoryCache)
    if warehouse_id:
        query = query.filter(InventoryCache.warehouse_id == warehouse_id)
    return query.all()


@router.get("/stock/{product_id}", response_model=list[StockResponse])
def get_product_stock(product_id: int, db: Session = Depends(get_db)):
    return db.query(InventoryCache).filter(InventoryCache.product_id == product_id).all()


@router.post("/refresh-cache")
def refresh_cache(db: Session = Depends(get_db)):
    db.execute(text("SELECT fn_refresh_inventory_cache()"))
    db.commit()
    return {"detail": "Inventory cache refreshed"}
