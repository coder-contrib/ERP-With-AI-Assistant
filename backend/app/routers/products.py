from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.products import ProductCreate, ProductUpdate, ProductResponse, ConversionCreate, ConversionResponse
from app.services.product_service import ProductService
from app.core.deps import require_permission
from app.models.users import User

router = APIRouter()


@router.get("/", response_model=list[ProductResponse])
def list_products(active_only: bool = True, current_user: User = Depends(require_permission("products:read")), db: Session = Depends(get_db)):
    service = ProductService(db)
    return service.list_all(active_only)


@router.get("/{product_id}", response_model=ProductResponse)
def get_product(product_id: int, current_user: User = Depends(require_permission("products:read")), db: Session = Depends(get_db)):
    service = ProductService(db)
    return service.get(product_id)


@router.post("/", response_model=ProductResponse, status_code=201)
def create_product(data: ProductCreate, current_user: User = Depends(require_permission("products:write")), db: Session = Depends(get_db)):
    service = ProductService(db)
    return service.create(data)


@router.put("/{product_id}", response_model=ProductResponse)
def update_product(product_id: int, data: ProductUpdate, current_user: User = Depends(require_permission("products:write")), db: Session = Depends(get_db)):
    service = ProductService(db)
    return service.update(product_id, data)


@router.get("/{product_id}/conversions", response_model=list[ConversionResponse])
def get_conversions(product_id: int, current_user: User = Depends(require_permission("products:read")), db: Session = Depends(get_db)):
    service = ProductService(db)
    return service.get_conversions(product_id)


@router.post("/{product_id}/conversions", response_model=ConversionResponse, status_code=201)
def add_conversion(product_id: int, data: ConversionCreate, current_user: User = Depends(require_permission("products:write")), db: Session = Depends(get_db)):
    service = ProductService(db)
    return service.add_conversion(product_id, data)
