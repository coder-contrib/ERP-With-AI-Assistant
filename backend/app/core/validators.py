from decimal import Decimal
from sqlalchemy.orm import Session
from app.models.products import Product, ProductUnitConversion
from app.models.inventory import InventoryCache
from app.models.customers import Customer
from app.core.exceptions import ValidationError


class Validator:
    def __init__(self, db: Session):
        self.db = db

    def validate_product_active(self, product_id: int) -> Product:
        product = self.db.query(Product).filter(Product.product_id == product_id).first()
        if not product:
            raise ValidationError(f"Product {product_id} not found")
        if not product.active_status:
            raise ValidationError(f"Product '{product.product_name}' is inactive and cannot be sold")
        return product

    def validate_stock_available(self, product_id: int, warehouse_id: int, quantity: Decimal):
        cache = self.db.query(InventoryCache).filter(
            InventoryCache.product_id == product_id,
            InventoryCache.warehouse_id == warehouse_id,
        ).first()
        available = cache.cached_quantity if cache else Decimal("0")
        if available < quantity:
            raise ValidationError(
                f"Insufficient stock for product {product_id}. "
                f"Available: {available}, Requested: {quantity}"
            )

    def validate_stock_not_negative(self, product_id: int, warehouse_id: int, deduction: Decimal):
        cache = self.db.query(InventoryCache).filter(
            InventoryCache.product_id == product_id,
            InventoryCache.warehouse_id == warehouse_id,
        ).first()
        available = cache.cached_quantity if cache else Decimal("0")
        if (available - deduction) < 0:
            raise ValidationError(
                f"Operation would result in negative stock for product {product_id}. "
                f"Current: {available}, Deduction: {deduction}"
            )

    def validate_credit_limit(self, customer_id: int, invoice_amount: Decimal):
        customer = self.db.query(Customer).filter(Customer.customer_id == customer_id).first()
        if not customer:
            raise ValidationError(f"Customer {customer_id} not found")
        if customer.credit_limit <= 0:
            return
        new_balance = customer.current_balance + invoice_amount
        if new_balance > customer.credit_limit:
            raise ValidationError(
                f"Credit limit exceeded for '{customer.customer_name}'. "
                f"Limit: {customer.credit_limit}, "
                f"Current balance: {customer.current_balance}, "
                f"New invoice: {invoice_amount}, "
                f"Would become: {new_balance}"
            )

    def validate_transfer_warehouses(self, from_warehouse_id: int, to_warehouse_id: int):
        if from_warehouse_id == to_warehouse_id:
            raise ValidationError("Cannot transfer to the same warehouse")

    def validate_unit_type_for_product(self, product_id: int, unit_type: str):
        product = self.db.query(Product).filter(Product.product_id == product_id).first()
        if not product:
            raise ValidationError(f"Product {product_id} not found")
        if unit_type == "piece" and not product.allow_piece_sale:
            raise ValidationError(
                f"Product '{product.product_name}' does not allow piece-based sales"
            )
        if unit_type == "carton" and not product.allow_carton_display:
            raise ValidationError(
                f"Product '{product.product_name}' does not allow carton-based operations"
            )

    def validate_conversion_exists(self, product_id: int, from_unit: str, to_unit: str):
        if from_unit == to_unit:
            return
        direct = self.db.query(ProductUnitConversion).filter(
            ProductUnitConversion.product_id == product_id,
            ProductUnitConversion.from_unit == from_unit,
            ProductUnitConversion.to_unit == to_unit,
        ).first()
        if direct:
            return
        reverse = self.db.query(ProductUnitConversion).filter(
            ProductUnitConversion.product_id == product_id,
            ProductUnitConversion.from_unit == to_unit,
            ProductUnitConversion.to_unit == from_unit,
        ).first()
        if reverse:
            return
        raise ValidationError(
            f"No unit conversion defined for product {product_id} "
            f"between '{from_unit}' and '{to_unit}'"
        )

    def validate_positive_amount(self, amount: Decimal, field_name: str = "Amount"):
        if amount <= 0:
            raise ValidationError(f"{field_name} must be greater than zero")

    def validate_quantity(self, quantity: Decimal, field_name: str = "Quantity"):
        if quantity <= 0:
            raise ValidationError(f"{field_name} must be greater than zero")
