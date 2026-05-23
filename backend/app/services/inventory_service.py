from sqlalchemy.orm import Session
from decimal import Decimal
from app.repositories.inventory_repo import InventoryRepository
from app.models.inventory import InventoryCache


class InventoryService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = InventoryRepository(db)

    def get_stock(self, warehouse_id: int | None = None) -> list[InventoryCache]:
        return self.repo.get_stock(warehouse_id)

    def get_product_stock(self, product_id: int) -> list[InventoryCache]:
        return self.repo.get_product_stock(product_id)

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

    def refresh_cache(self):
        self.repo.refresh_cache()
