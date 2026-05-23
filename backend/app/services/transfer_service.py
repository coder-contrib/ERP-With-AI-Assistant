from sqlalchemy.orm import Session
from decimal import Decimal
from app.database import transaction
from app.repositories.inventory_repo import InventoryRepository
from app.core.validators import Validator
from app.core.exceptions import NotFoundError
from app.models.transfers import WarehouseTransfer


class TransferService:
    def __init__(self, db: Session):
        self.db = db
        self.inventory_repo = InventoryRepository(db)
        self.validator = Validator(db)

    def create_transfer(self, from_warehouse_id: int, to_warehouse_id: int,
                        product_id: int, quantity: Decimal, unit_type: str,
                        notes: str | None = None) -> WarehouseTransfer:
        with transaction(self.db):
            # --- VALIDATION ---
            self.validator.validate_transfer_warehouses(from_warehouse_id, to_warehouse_id)
            self.validator.validate_product_active(product_id)
            self.validator.validate_quantity(quantity, "Transfer quantity")
            self.validator.validate_stock_available(product_id, from_warehouse_id, quantity)

            # --- EXECUTION ---
            transfer = WarehouseTransfer(
                from_warehouse_id=from_warehouse_id,
                to_warehouse_id=to_warehouse_id,
                product_id=product_id,
                quantity=quantity,
                notes=notes,
            )
            self.db.add(transfer)
            self.db.flush()

            # OUT from source warehouse
            self.inventory_repo.create_transaction(
                product_id=product_id,
                warehouse_id=from_warehouse_id,
                transaction_type="warehouse_transfer",
                direction="OUT",
                quantity=quantity,
                unit_type=unit_type,
                cost_per_unit=Decimal("0"),
                warehouse_from=from_warehouse_id,
                warehouse_to=to_warehouse_id,
                reference_type="warehouse_transfer",
                reference_id=transfer.transfer_id,
            )

            # IN to destination warehouse
            self.inventory_repo.create_transaction(
                product_id=product_id,
                warehouse_id=to_warehouse_id,
                transaction_type="warehouse_transfer",
                direction="IN",
                quantity=quantity,
                unit_type=unit_type,
                cost_per_unit=Decimal("0"),
                warehouse_from=from_warehouse_id,
                warehouse_to=to_warehouse_id,
                reference_type="warehouse_transfer",
                reference_id=transfer.transfer_id,
            )

        self.db.refresh(transfer)
        return transfer
