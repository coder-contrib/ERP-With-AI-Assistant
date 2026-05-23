from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.suppliers import SupplierCreate, SupplierUpdate, SupplierResponse
from app.repositories.supplier_repo import SupplierRepository
from app.core.exceptions import NotFoundError

router = APIRouter()


@router.get("/", response_model=list[SupplierResponse])
def list_suppliers(db: Session = Depends(get_db)):
    repo = SupplierRepository(db)
    return repo.get_all()


@router.get("/{supplier_id}", response_model=SupplierResponse)
def get_supplier(supplier_id: int, db: Session = Depends(get_db)):
    repo = SupplierRepository(db)
    supplier = repo.get_by_id(supplier_id)
    if not supplier:
        raise NotFoundError("Supplier not found")
    return supplier


@router.post("/", response_model=SupplierResponse, status_code=201)
def create_supplier(data: SupplierCreate, db: Session = Depends(get_db)):
    repo = SupplierRepository(db)
    supplier = repo.create(**data.model_dump())
    db.commit()
    db.refresh(supplier)
    return supplier


@router.put("/{supplier_id}", response_model=SupplierResponse)
def update_supplier(supplier_id: int, data: SupplierUpdate, db: Session = Depends(get_db)):
    repo = SupplierRepository(db)
    supplier = repo.get_by_id(supplier_id)
    if not supplier:
        raise NotFoundError("Supplier not found")
    supplier = repo.update(supplier, **data.model_dump(exclude_unset=True))
    db.commit()
    db.refresh(supplier)
    return supplier
