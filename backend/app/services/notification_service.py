from sqlalchemy.orm import Session
from sqlalchemy import func
from app.models.notifications import Notification
from app.models.inventory import InventoryCache
from app.models.customers import Customer
from app.models.suppliers import Supplier
from app.models.products import Product
from app.models.warehouses import Warehouse
from datetime import date


class NotificationService:
    def __init__(self, db: Session):
        self.db = db

    def get_unread(self, user_id: int | None = None) -> list[Notification]:
        query = self.db.query(Notification).filter(Notification.is_read == False)
        if user_id:
            query = query.filter(
                (Notification.user_id == user_id) | (Notification.user_id == None)
            )
        return query.order_by(Notification.created_date.desc()).all()

    def get_all(self, user_id: int | None = None, limit: int = 50) -> list[Notification]:
        query = self.db.query(Notification)
        if user_id:
            query = query.filter(
                (Notification.user_id == user_id) | (Notification.user_id == None)
            )
        return query.order_by(Notification.created_date.desc()).limit(limit).all()

    def mark_read(self, notification_id: int):
        notif = self.db.query(Notification).filter(
            Notification.notification_id == notification_id
        ).first()
        if notif:
            notif.is_read = True
            self.db.commit()

    def mark_all_read(self, user_id: int | None = None):
        query = self.db.query(Notification).filter(Notification.is_read == False)
        if user_id:
            query = query.filter(
                (Notification.user_id == user_id) | (Notification.user_id == None)
            )
        query.update({"is_read": True})
        self.db.commit()

    def create(self, notification_type: str, severity: str, title: str,
               message: str, user_id: int | None = None,
               entity_type: str | None = None, entity_id: int | None = None) -> Notification:
        notif = Notification(
            user_id=user_id,
            notification_type=notification_type,
            severity=severity,
            title=title,
            message=message,
            entity_type=entity_type,
            entity_id=entity_id,
        )
        self.db.add(notif)
        self.db.flush()
        return notif

    def _already_notified(self, notification_type: str, entity_type: str, entity_id: int) -> bool:
        return self.db.query(Notification).filter(
            Notification.notification_type == notification_type,
            Notification.entity_type == entity_type,
            Notification.entity_id == entity_id,
        ).first() is not None

    def check_low_stock(self, threshold: float = 10.0) -> int:
        results = self.db.query(
            InventoryCache.product_id,
            Product.product_name,
            InventoryCache.warehouse_id,
            Warehouse.warehouse_name,
            InventoryCache.cached_quantity,
        ).join(Product, Product.product_id == InventoryCache.product_id
        ).join(Warehouse, Warehouse.warehouse_id == InventoryCache.warehouse_id
        ).filter(
            InventoryCache.cached_quantity <= threshold,
            InventoryCache.cached_quantity > 0,
        ).all()

        seen_products = set()
        count = 0
        for r in results:
            if r.product_id in seen_products:
                continue
            seen_products.add(r.product_id)
            if self._already_notified("low_stock", "product", r.product_id):
                continue
            self.create(
                notification_type="low_stock",
                severity="warning",
                title=f"Low stock: {r.product_name}",
                message=f"{r.product_name} has only {r.cached_quantity} units left in {r.warehouse_name}",
                entity_type="product",
                entity_id=r.product_id,
            )
            count += 1
        self.db.commit()
        return count

    def check_credit_limit_exceeded(self) -> int:
        results = self.db.query(Customer).filter(
            Customer.credit_limit > 0,
            Customer.current_balance > Customer.credit_limit,
        ).all()

        count = 0
        for c in results:
            if self._already_notified("credit_limit_exceeded", "customer", c.customer_id):
                continue
            over = c.current_balance - c.credit_limit
            self.create(
                notification_type="credit_limit_exceeded",
                severity="critical",
                title=f"Credit limit exceeded: {c.customer_name}",
                message=f"{c.customer_name} is over limit by {over}. Balance: {c.current_balance}, Limit: {c.credit_limit}",
                entity_type="customer",
                entity_id=c.customer_id,
            )
            count += 1
        self.db.commit()
        return count

    def check_overdue_supplier_payments(self) -> int:
        results = self.db.query(Supplier).filter(
            Supplier.current_balance > 0,
            Supplier.payment_terms > 0,
        ).all()

        today = date.today()
        count = 0
        for s in results:
            if s.last_payment_date:
                days_since = (today - s.last_payment_date.date()).days
            else:
                days_since = 999

            if days_since > s.payment_terms:
                if self._already_notified("overdue_supplier", "supplier", s.supplier_id):
                    continue
                self.create(
                    notification_type="overdue_supplier",
                    severity="warning",
                    title=f"Overdue payment: {s.supplier_name}",
                    message=f"Payment to {s.supplier_name} is overdue by {days_since - s.payment_terms} days. Balance: {s.current_balance}",
                    entity_type="supplier",
                    entity_id=s.supplier_id,
                )
                count += 1
        self.db.commit()
        return count

    def create_daily_closing_reminder(self) -> Notification:
        return self.create(
            notification_type="daily_closing",
            severity="info",
            title="Daily closing reminder",
            message="Please review today's transactions and close the day. Run financial summary refresh if needed.",
        )
