from sqlalchemy.orm import Session
from decimal import Decimal
from app.database import transaction
from app.repositories.inventory_repo import InventoryRepository
from app.services.cache_service import CacheService
from app.core.redis import get_redis
from app.models.inventory import InventoryCache


class InventoryService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = InventoryRepository(db)
        self.cache = CacheService(get_redis())

    def get_stock(self, warehouse_id: int | None = None) -> list[InventoryCache]:
        if not warehouse_id:
            cached = self.cache.get_all_stock()
            if cached:
                return cached
        stocks = self.repo.get_stock(warehouse_id)
        if not warehouse_id:
            self.cache.set_all_stock(
                [{"product_id": s.product_id, "warehouse_id": s.warehouse_id,
                  "cached_quantity": str(s.cached_quantity), "cached_avg_cost": str(s.cached_avg_cost)}
                 for s in stocks]
            )
        return stocks

    def get_product_stock(self, product_id: int) -> list[InventoryCache]:
        return self.repo.get_product_stock(product_id)

    def get_available_quantity(self, product_id: int, warehouse_id: int) -> Decimal:
        cached = self.cache.get_stock(product_id, warehouse_id)
        if cached:
            return Decimal(cached["cached_quantity"])
        stocks = self.repo.get_product_stock(product_id)
        for stock in stocks:
            if stock.warehouse_id == warehouse_id:
                self.cache.set_stock(product_id, warehouse_id, {
                    "cached_quantity": str(stock.cached_quantity),
                    "cached_avg_cost": str(stock.cached_avg_cost),
                })
                return stock.cached_quantity
        return Decimal("0")

    def record_sale(self, product_id: int, warehouse_id: int, quantity: Decimal,
                    unit_type: str, cost_per_unit: Decimal, reference_id: int):
        self.repo.create_transaction(
            product_id=product_id,
            warehouse_id=warehouse_id,
            transaction_type="sale",
            direction="OUT",
            quantity=quantity,
            unit_type=unit_type,
            cost_per_unit=cost_per_unit,
            reference_type="sales_invoice",
            reference_id=reference_id,
        )
        self.cache.invalidate_stock(product_id, warehouse_id)

    def record_purchase(self, product_id: int, warehouse_id: int, quantity: Decimal,
                        unit_type: str, cost_per_unit: Decimal, reference_id: int):
        self.repo.create_transaction(
            product_id=product_id,
            warehouse_id=warehouse_id,
            transaction_type="purchase",
            direction="IN",
            quantity=quantity,
            unit_type=unit_type,
            cost_per_unit=cost_per_unit,
            reference_type="purchase_invoice",
            reference_id=reference_id,
        )
        self.cache.invalidate_stock(product_id, warehouse_id)

    def record_opening_stock(self, product_id: int, warehouse_id: int, quantity: Decimal,
                             unit_type: str, cost_per_unit: Decimal):
        self.repo.create_transaction(
            product_id=product_id,
            warehouse_id=warehouse_id,
            transaction_type="opening_stock",
            direction="IN",
            quantity=quantity,
            unit_type=unit_type,
            cost_per_unit=cost_per_unit,
        )
        self.cache.invalidate_stock(product_id, warehouse_id)

    def record_waste(self, product_id: int, warehouse_id: int, quantity: Decimal,
                     unit_type: str, cost_per_unit: Decimal, reference_id: int):
        self.repo.create_transaction(
            product_id=product_id,
            warehouse_id=warehouse_id,
            transaction_type="waste",
            direction="OUT",
            quantity=quantity,
            unit_type=unit_type,
            cost_per_unit=cost_per_unit,
            reference_type="waste",
            reference_id=reference_id,
        )
        self.cache.invalidate_stock(product_id, warehouse_id)

    def refresh_cache(self):
        self.repo.refresh_cache()
        self.cache.invalidate_all_stock()
