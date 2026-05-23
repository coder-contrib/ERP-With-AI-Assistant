from sqlalchemy.orm import Session
from app.models.suppliers import Supplier
from datetime import datetime


class SupplierRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_all(self) -> list[Supplier]:
        return self.db.query(Supplier).all()

    def get_by_id(self, supplier_id: int) -> Supplier | None:
        return self.db.query(Supplier).filter(Supplier.supplier_id == supplier_id).first()

    def create(self, **kwargs) -> Supplier:
        supplier = Supplier(**kwargs)
        self.db.add(supplier)
        self.db.flush()
        return supplier

    def update(self, supplier: Supplier, **kwargs) -> Supplier:
        for key, value in kwargs.items():
            if value is not None:
                setattr(supplier, key, value)
        self.db.flush()
        return supplier

    def update_balance(self, supplier: Supplier, amount) -> None:
        supplier.current_balance += amount
        self.db.flush()

    def record_payment_date(self, supplier: Supplier) -> None:
        supplier.last_payment_date = datetime.utcnow()
        self.db.flush()
