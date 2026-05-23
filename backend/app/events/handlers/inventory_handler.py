from app.events.event_bus import Event
from app.events.sale_events import SALE_CREATED
from app.events.purchase_events import PURCHASE_CREATED
from app.events.inventory_events import INVENTORY_IN, INVENTORY_OUT
from sqlalchemy.orm import Session
from app.repositories.inventory_repo import InventoryRepository
from app.core.redis import get_redis
from app.services.cache_service import CacheService


def handle_sale_inventory(event: Event, db: Session):
    repo = InventoryRepository(db)
    cache = CacheService(get_redis())
    for item in event.data.get("items", []):
        repo.create_transaction(
            product_id=item["product_id"],
            warehouse_id=event.data["warehouse_id"],
            transaction_type="sale",
            direction="OUT",
            quantity=item["sold_quantity"],
            unit_type=item["unit_type"],
            cost_per_unit=item["cost_at_sale"],
            reference_type="sales_invoice",
            reference_id=event.data["invoice_id"],
        )
        cache.invalidate_stock(item["product_id"], event.data["warehouse_id"])


def handle_purchase_inventory(event: Event, db: Session):
    repo = InventoryRepository(db)
    cache = CacheService(get_redis())
    for item in event.data.get("items", []):
        repo.create_transaction(
            product_id=item["product_id"],
            warehouse_id=event.data["warehouse_id"],
            transaction_type="purchase",
            direction="IN",
            quantity=item["purchased_quantity"],
            unit_type=item.get("unit_type", "meter"),
            cost_per_unit=item["purchase_price"],
            reference_type="purchase_invoice",
            reference_id=event.data["purchase_invoice_id"],
        )
        cache.invalidate_stock(item["product_id"], event.data["warehouse_id"])
