from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from decimal import Decimal
from app.database import get_db
from app.models.customers import Customer

router = APIRouter()


class CustomerCreate(BaseModel):
    customer_name: str
    phone_number: str | None = None
    address: str | None = None
    credit_limit: Decimal = Decimal("0")
    payment_terms: int = 0
    notes: str | None = None


class CustomerResponse(BaseModel):
    customer_id: int
    customer_name: str
    phone_number: str | None
    address: str | None
    current_balance: Decimal
    credit_limit: Decimal
    payment_terms: int
    notes: str | None

    class Config:
        from_attributes = True


@router.get("/", response_model=list[CustomerResponse])
def list_customers(db: Session = Depends(get_db)):
    return db.query(Customer).all()


@router.get("/{customer_id}", response_model=CustomerResponse)
def get_customer(customer_id: int, db: Session = Depends(get_db)):
    customer = db.query(Customer).filter(Customer.customer_id == customer_id).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")
    return customer


@router.post("/", response_model=CustomerResponse, status_code=201)
def create_customer(data: CustomerCreate, db: Session = Depends(get_db)):
    customer = Customer(**data.model_dump())
    db.add(customer)
    db.commit()
    db.refresh(customer)
    return customer


@router.put("/{customer_id}", response_model=CustomerResponse)
def update_customer(customer_id: int, data: CustomerCreate, db: Session = Depends(get_db)):
    customer = db.query(Customer).filter(Customer.customer_id == customer_id).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")
    for key, value in data.model_dump().items():
        setattr(customer, key, value)
    db.commit()
    db.refresh(customer)
    return customer
