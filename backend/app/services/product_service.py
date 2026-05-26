from sqlalchemy.orm import Session
from app.database import transaction
from app.repositories.product_repo import ProductRepository
from app.schemas.products import ProductCreate, ProductUpdate, ConversionCreate
from app.models.products import Product, ProductUnitConversion
from app.core.exceptions import NotFoundError


class ProductService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = ProductRepository(db)

    def list_all(self, active_only: bool = True) -> list[Product]:
        return self.repo.get_all(active_only)

    def get(self, product_id: int) -> Product:
        product = self.repo.get_by_id(product_id)
        if not product:
            raise NotFoundError("Product not found")
        return product

    def create(self, data: ProductCreate) -> Product:
        with transaction(self.db):
            product = self.repo.create(**data.model_dump())
        self.db.refresh(product)
        return product

    def update(self, product_id: int, data: ProductUpdate) -> Product:
        with transaction(self.db):
            product = self.get(product_id)
            product = self.repo.update(product, **data.model_dump(exclude_unset=True))
        self.db.refresh(product)
        return product

    def deactivate(self, product_id: int) -> Product:
        with transaction(self.db):
            product = self.get(product_id)
            product = self.repo.deactivate(product)
        self.db.refresh(product)
        return product

    def toggle_status(self, product_id: int) -> Product:
        with transaction(self.db):
            product = self.get(product_id)
            product.active_status = not product.active_status
            self.db.flush()
        self.db.refresh(product)
        return product

    def get_conversions(self, product_id: int) -> list[ProductUnitConversion]:
        self.get(product_id)
        return self.repo.get_conversions(product_id)

    def add_conversion(self, product_id: int, data: ConversionCreate) -> ProductUnitConversion:
        with transaction(self.db):
            self.get(product_id)
            conversion = self.repo.add_conversion(product_id, data.from_unit, data.to_unit, data.factor)
        self.db.refresh(conversion)
        return conversion

    def delete_conversion(self, product_id: int, conversion_id: int) -> None:
        self.get(product_id)
        conversion = self.repo.get_conversion(conversion_id)
        if not conversion or conversion.product_id != product_id:
            raise NotFoundError("Conversion not found")
        with transaction(self.db):
            self.repo.delete_conversion(conversion)
