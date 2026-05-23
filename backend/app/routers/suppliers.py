from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from decimal import Decimal
from app.database import get_db
from app.models.suppliers import Supplier

router = APIRouter()


class SupplierCreate(BaseModel):
    supplier_name: str
    phone_number: str | None = None
    address: str | None = None
    payment_terms: int = 0
    notes: str | None = None


class SupplierResponse(BaseModel):
    supplier_id: int
    supplier_name: str
    phone_number: str | None
    address: str | None
    current_balance: Decimal
    payment_terms: int
    notes: str | None

    class Config:
        from_attributes = True


@router.get("/", response_model=list[SupplierResponse])
def list_suppliers(db: Session = Depends(get_db)):
    return db.query(Supplier).all()


@router.get("/{supplier_id}", response_model=SupplierResponse)
def get_supplier(supplier_id: int, db: Session = Depends(get_db)):
    supplier = db.query(Supplier).filter(Supplier.supplier_id == supplier_id).first()
    if not supplier:
        raise HTTPException(status_code=404, detail="Supplier not found")
    return supplier


@router.post("/", response_model=SupplierResponse, status_code=201)
def create_supplier(data: SupplierCreate, db: Session = Depends(get_db)):
    supplier = Supplier(**data.model_dump())
    db.add(supplier)
    db.commit()
    db.refresh(supplier)
    return supplier


@router.put("/{supplier_id}", response_model=SupplierResponse)
def update_supplier(supplier_id: int, data: SupplierCreate, db: Session = Depends(get_db)):
    supplier = db.query(Supplier).filter(Supplier.supplier_id == supplier_id).first()
    if not supplier:
        raise HTTPException(status_code=404, detail="Supplier not found")
    for key, value in data.model_dump().items():
        setattr(supplier, key, value)
    db.commit()
    db.refresh(supplier)
    return supplier
