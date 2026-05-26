from sqlalchemy.orm import Session
from app.models.products import Product, ProductUnitConversion


class ProductRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_all(self, active_only: bool = True) -> list[Product]:
        query = self.db.query(Product)
        if active_only:
            query = query.filter(Product.active_status == True)
        return query.all()

    def get_by_id(self, product_id: int) -> Product | None:
        return self.db.query(Product).filter(Product.product_id == product_id).first()

    def create(self, **kwargs) -> Product:
        product = Product(**kwargs)
        self.db.add(product)
        self.db.flush()
        return product

    def update(self, product: Product, **kwargs) -> Product:
        for key, value in kwargs.items():
            if value is not None:
                setattr(product, key, value)
        self.db.flush()
        return product

    def deactivate(self, product: Product) -> Product:
        product.active_status = False
        self.db.flush()
        return product

    def get_conversions(self, product_id: int) -> list[ProductUnitConversion]:
        return self.db.query(ProductUnitConversion).filter(
            ProductUnitConversion.product_id == product_id
        ).all()

    def add_conversion(self, product_id: int, from_unit: str, to_unit: str, factor) -> ProductUnitConversion:
        conversion = ProductUnitConversion(
            product_id=product_id, from_unit=from_unit, to_unit=to_unit, factor=factor
        )
        self.db.add(conversion)
        self.db.flush()
        return conversion

    def get_conversion(self, conversion_id: int) -> ProductUnitConversion | None:
        return self.db.query(ProductUnitConversion).filter(
            ProductUnitConversion.conversion_id == conversion_id
        ).first()

    def delete_conversion(self, conversion: ProductUnitConversion) -> None:
        self.db.delete(conversion)
        self.db.flush()
