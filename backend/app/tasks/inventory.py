from app.celery_app import celery_app
from app.database import SessionLocal
from app.core.redis import get_redis
from sqlalchemy import text


@celery_app.task(name="app.tasks.inventory.refresh_inventory_cache")
def refresh_inventory_cache():
    db = SessionLocal()
    try:
        db.execute(text("SELECT fn_refresh_inventory_cache()"))
        db.commit()
        redis = get_redis()
        redis.delete_pattern("stock:*")
        return {"status": "success", "detail": "Inventory cache refreshed"}
    except Exception as e:
        db.rollback()
        return {"status": "error", "detail": str(e)}
    finally:
        db.close()


@celery_app.task(name="app.tasks.inventory.check_low_stock")
def check_low_stock(threshold: float = 10.0):
    db = SessionLocal()
    try:
        result = db.execute(text("""
            SELECT ic.product_id, p.product_name, ic.warehouse_id, w.warehouse_name, ic.cached_quantity
            FROM inventory_cache ic
            JOIN products p ON p.product_id = ic.product_id
            JOIN warehouses w ON w.warehouse_id = ic.warehouse_id
            WHERE ic.cached_quantity <= :threshold AND ic.cached_quantity > 0
            ORDER BY ic.cached_quantity ASC
        """), {"threshold": threshold})
        low_stock = [dict(row._mapping) for row in result]
        return {"status": "success", "low_stock_count": len(low_stock), "items": low_stock}
    finally:
        db.close()
