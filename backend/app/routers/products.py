from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.products import ProductCreate, ProductUpdate, ProductResponse, ConversionCreate, ConversionResponse
from app.repositories.product_repo import ProductRepository
from app.core.exceptions import NotFoundError

router = APIRouter()


@router.get("/", response_model=list[ProductResponse])
def list_products(active_only: bool = True, db: Session = Depends(get_db)):
    repo = ProductRepository(db)
    return repo.get_all(active_only)


@router.get("/{product_id}", response_model=ProductResponse)
def get_product(product_id: int, db: Session = Depends(get_db)):
    repo = ProductRepository(db)
    product = repo.get_by_id(product_id)
    if not product:
        raise NotFoundError("Product not found")
    return product


@router.post("/", response_model=ProductResponse, status_code=201)
def create_product(data: ProductCreate, db: Session = Depends(get_db)):
    repo = ProductRepository(db)
    product = repo.create(**data.model_dump())
    db.commit()
    db.refresh(product)
    return product


@router.put("/{product_id}", response_model=ProductResponse)
def update_product(product_id: int, data: ProductUpdate, db: Session = Depends(get_db)):
    repo = ProductRepository(db)
    product = repo.get_by_id(product_id)
    if not product:
        raise NotFoundError("Product not found")
    product = repo.update(product, **data.model_dump(exclude_unset=True))
    db.commit()
    db.refresh(product)
    return product


@router.get("/{product_id}/conversions", response_model=list[ConversionResponse])
def get_conversions(product_id: int, db: Session = Depends(get_db)):
    repo = ProductRepository(db)
    return repo.get_conversions(product_id)


@router.post("/{product_id}/conversions", response_model=ConversionResponse, status_code=201)
def add_conversion(product_id: int, data: ConversionCreate, db: Session = Depends(get_db)):
    repo = ProductRepository(db)
    conversion = repo.add_conversion(product_id, data.from_unit, data.to_unit, data.factor)
    db.commit()
    db.refresh(conversion)
    return conversion
