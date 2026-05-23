from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.suppliers import SupplierCreate, SupplierUpdate, SupplierResponse
from app.services.supplier_service import SupplierService
from app.core.deps import require_permission
from app.models.users import User

router = APIRouter()


@router.get("/", response_model=list[SupplierResponse])
def list_suppliers(current_user: User = Depends(require_permission("suppliers:read")), db: Session = Depends(get_db)):
    service = SupplierService(db)
    return service.list_all()


@router.get("/{supplier_id}", response_model=SupplierResponse)
def get_supplier(supplier_id: int, current_user: User = Depends(require_permission("suppliers:read")), db: Session = Depends(get_db)):
    service = SupplierService(db)
    return service.get(supplier_id)


@router.post("/", response_model=SupplierResponse, status_code=201)
def create_supplier(data: SupplierCreate, current_user: User = Depends(require_permission("suppliers:write")), db: Session = Depends(get_db)):
    service = SupplierService(db)
    return service.create(data)


@router.put("/{supplier_id}", response_model=SupplierResponse)
def update_supplier(supplier_id: int, data: SupplierUpdate, current_user: User = Depends(require_permission("suppliers:write")), db: Session = Depends(get_db)):
    service = SupplierService(db)
    return service.update(supplier_id, data)
