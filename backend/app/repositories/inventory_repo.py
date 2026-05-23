from sqlalchemy.orm import Session
from sqlalchemy import text
from app.models.inventory import InventoryTransaction, InventoryCache


class InventoryRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_stock(self, warehouse_id: int | None = None) -> list[InventoryCache]:
        query = self.db.query(InventoryCache)
        if warehouse_id:
            query = query.filter(InventoryCache.warehouse_id == warehouse_id)
        return query.all()

    def get_product_stock(self, product_id: int) -> list[InventoryCache]:
        return self.db.query(InventoryCache).filter(
            InventoryCache.product_id == product_id
        ).all()

    def create_transaction(self, **kwargs) -> InventoryTransaction:
        txn = InventoryTransaction(**kwargs)
        self.db.add(txn)
        self.db.flush()
        return txn

    def refresh_cache(self) -> None:
        self.db.execute(text("SELECT fn_refresh_inventory_cache()"))
        self.db.flush()
