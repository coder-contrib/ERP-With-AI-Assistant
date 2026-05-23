from sqlalchemy.orm import Session
from app.repositories.supplier_repo import SupplierRepository
from app.schemas.suppliers import SupplierCreate, SupplierUpdate
from app.models.suppliers import Supplier
from app.core.exceptions import NotFoundError


class SupplierService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = SupplierRepository(db)

    def list_all(self) -> list[Supplier]:
        return self.repo.get_all()

    def get(self, supplier_id: int) -> Supplier:
        supplier = self.repo.get_by_id(supplier_id)
        if not supplier:
            raise NotFoundError("Supplier not found")
        return supplier

    def create(self, data: SupplierCreate) -> Supplier:
        supplier = self.repo.create(**data.model_dump())
        self.db.commit()
        self.db.refresh(supplier)
        return supplier

    def update(self, supplier_id: int, data: SupplierUpdate) -> Supplier:
        supplier = self.get(supplier_id)
        supplier = self.repo.update(supplier, **data.model_dump(exclude_unset=True))
        self.db.commit()
        self.db.refresh(supplier)
        return supplier
