from sqlalchemy.orm import Session
from sqlalchemy import func
from decimal import Decimal
from datetime import date, timedelta
from app.models.inventory import InventoryTransaction, InventoryCache
from app.models.products import Product
from app.models.warehouses import Warehouse


class StockTools:
    """Tools for the Inventory AI Agent.
    All data access goes through SQLAlchemy models.
    """

    def __init__(self, db: Session):
        self.db = db

    def get_stock_level(self, product_id: int, warehouse_id: int | None = None) -> dict:
        query = self.db.query(InventoryCache).filter(InventoryCache.product_id == product_id)
        if warehouse_id:
            query = query.filter(InventoryCache.warehouse_id == warehouse_id)
        stocks = query.all()
        return {
            "product_id": product_id,
            "warehouses": [
                {
                    "warehouse_id": s.warehouse_id,
                    "quantity": str(s.cached_quantity),
                    "avg_cost": str(s.cached_avg_cost),
                }
                for s in stocks
            ],
            "total_quantity": str(sum(s.cached_quantity for s in stocks)),
        }

    def get_low_stock_items(self, threshold: float = 10.0) -> dict:
        results = self.db.query(
            InventoryCache.product_id,
            Product.product_name,
            InventoryCache.warehouse_id,
            InventoryCache.cached_quantity,
        ).join(Product, Product.product_id == InventoryCache.product_id
        ).filter(InventoryCache.cached_quantity <= threshold, InventoryCache.cached_quantity > 0
        ).order_by(InventoryCache.cached_quantity.asc()).all()

        return {
            "threshold": threshold,
            "count": len(results),
            "items": [
                {
                    "product_id": r.product_id,
                    "name": r.product_name,
                    "warehouse_id": r.warehouse_id,
                    "quantity": str(r.cached_quantity),
                }
                for r in results
            ],
        }

    def get_stock_movement_history(self, product_id: int, limit: int = 20) -> dict:
        movements = self.db.query(InventoryTransaction).filter(
            InventoryTransaction.product_id == product_id
        ).order_by(InventoryTransaction.created_date.desc()).limit(limit).all()

        return {
            "product_id": product_id,
            "movements": [
                {
                    "date": str(m.created_date),
                    "type": m.transaction_type,
                    "direction": m.direction,
                    "quantity": str(m.quantity),
                    "unit": m.unit_type,
                    "warehouse_id": m.warehouse_id,
                }
                for m in movements
            ],
        }

    def get_warehouse_summary(self, warehouse_id: int) -> dict:
        results = self.db.query(
            func.count(InventoryCache.product_id).label("product_count"),
            func.sum(InventoryCache.cached_quantity).label("total_quantity"),
            func.sum(InventoryCache.cached_quantity * InventoryCache.cached_avg_cost).label("total_value"),
        ).filter(InventoryCache.warehouse_id == warehouse_id).first()

        warehouse = self.db.query(Warehouse).filter(Warehouse.warehouse_id == warehouse_id).first()

        return {
            "warehouse_id": warehouse_id,
            "warehouse_name": warehouse.warehouse_name if warehouse else "Unknown",
            "product_count": results.product_count or 0,
            "total_quantity": str(results.total_quantity or 0),
            "total_value": str(results.total_value or 0),
        }

    def get_dead_stock(self, days: int = 30) -> dict:
        cutoff = date.today() - timedelta(days=days)
        subquery = self.db.query(
            InventoryTransaction.product_id
        ).filter(InventoryTransaction.created_date >= cutoff).distinct().subquery()

        dead = self.db.query(
            InventoryCache.product_id,
            Product.product_name,
            InventoryCache.warehouse_id,
            InventoryCache.cached_quantity,
            InventoryCache.cached_avg_cost,
        ).join(Product, Product.product_id == InventoryCache.product_id
        ).filter(
            InventoryCache.cached_quantity > 0,
            ~InventoryCache.product_id.in_(subquery),
        ).all()

        return {
            "days_threshold": days,
            "count": len(dead),
            "items": [
                {
                    "product_id": r.product_id,
                    "name": r.product_name,
                    "warehouse_id": r.warehouse_id,
                    "quantity": str(r.cached_quantity),
                    "value": str(r.cached_quantity * r.cached_avg_cost),
                }
                for r in dead
            ],
        }

    def get_stock_valuation(self, warehouse_id: int | None = None) -> dict:
        query = self.db.query(
            InventoryCache.warehouse_id,
            func.sum(InventoryCache.cached_quantity * InventoryCache.cached_avg_cost).label("value"),
            func.count(InventoryCache.product_id).label("products"),
        )
        if warehouse_id:
            query = query.filter(InventoryCache.warehouse_id == warehouse_id)
        results = query.group_by(InventoryCache.warehouse_id).all()

        return {
            "warehouses": [
                {
                    "warehouse_id": r.warehouse_id,
                    "total_value": str(r.value or 0),
                    "product_count": r.products,
                }
                for r in results
            ],
            "grand_total": str(sum(r.value or 0 for r in results)),
        }
