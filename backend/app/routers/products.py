from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from decimal import Decimal
from app.database import get_db
from app.models.products import Product, ProductUnitConversion

router = APIRouter()


class ProductCreate(BaseModel):
    product_name: str
    category_id: int | None = None
    is_meter_based: bool = True
    allow_piece_sale: bool = False
    allow_carton_display: bool = True
    base_unit: str = "meter"
    purchase_cost_per_meter: Decimal = Decimal("0")
    selling_price: Decimal = Decimal("0")
    barcode: str | None = None
    notes: str | None = None


class ProductResponse(BaseModel):
    product_id: int
    product_name: str
    category_id: int | None
    is_meter_based: bool
    allow_piece_sale: bool
    allow_carton_display: bool
    base_unit: str
    purchase_cost_per_meter: Decimal
    selling_price: Decimal
    barcode: str | None
    active_status: bool

    class Config:
        from_attributes = True


class ConversionCreate(BaseModel):
    product_id: int
    from_unit: str
    to_unit: str
    factor: Decimal


class ConversionResponse(BaseModel):
    conversion_id: int
    product_id: int
    from_unit: str
    to_unit: str
    factor: Decimal

    class Config:
        from_attributes = True


@router.get("/", response_model=list[ProductResponse])
def list_products(active_only: bool = True, db: Session = Depends(get_db)):
    query = db.query(Product)
    if active_only:
        query = query.filter(Product.active_status == True)
    return query.all()


@router.get("/{product_id}", response_model=ProductResponse)
def get_product(product_id: int, db: Session = Depends(get_db)):
    product = db.query(Product).filter(Product.product_id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return product


@router.post("/", response_model=ProductResponse, status_code=201)
def create_product(data: ProductCreate, db: Session = Depends(get_db)):
    product = Product(**data.model_dump())
    db.add(product)
    db.commit()
    db.refresh(product)
    return product


@router.put("/{product_id}", response_model=ProductResponse)
def update_product(product_id: int, data: ProductCreate, db: Session = Depends(get_db)):
    product = db.query(Product).filter(Product.product_id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    for key, value in data.model_dump().items():
        setattr(product, key, value)
    db.commit()
    db.refresh(product)
    return product


@router.get("/{product_id}/conversions", response_model=list[ConversionResponse])
def get_product_conversions(product_id: int, db: Session = Depends(get_db)):
    return db.query(ProductUnitConversion).filter(
        ProductUnitConversion.product_id == product_id
    ).all()


@router.post("/{product_id}/conversions", response_model=ConversionResponse, status_code=201)
def add_conversion(product_id: int, data: ConversionCreate, db: Session = Depends(get_db)):
    conversion = ProductUnitConversion(product_id=product_id, from_unit=data.from_unit, to_unit=data.to_unit, factor=data.factor)
    db.add(conversion)
    db.commit()
    db.refresh(conversion)
    return conversion
