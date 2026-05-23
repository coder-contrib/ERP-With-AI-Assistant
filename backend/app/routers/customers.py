from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.customers import CustomerCreate, CustomerUpdate, CustomerResponse
from app.repositories.customer_repo import CustomerRepository
from app.core.exceptions import NotFoundError

router = APIRouter()


@router.get("/", response_model=list[CustomerResponse])
def list_customers(db: Session = Depends(get_db)):
    repo = CustomerRepository(db)
    return repo.get_all()


@router.get("/{customer_id}", response_model=CustomerResponse)
def get_customer(customer_id: int, db: Session = Depends(get_db)):
    repo = CustomerRepository(db)
    customer = repo.get_by_id(customer_id)
    if not customer:
        raise NotFoundError("Customer not found")
    return customer


@router.post("/", response_model=CustomerResponse, status_code=201)
def create_customer(data: CustomerCreate, db: Session = Depends(get_db)):
    repo = CustomerRepository(db)
    customer = repo.create(**data.model_dump())
    db.commit()
    db.refresh(customer)
    return customer


@router.put("/{customer_id}", response_model=CustomerResponse)
def update_customer(customer_id: int, data: CustomerUpdate, db: Session = Depends(get_db)):
    repo = CustomerRepository(db)
    customer = repo.get_by_id(customer_id)
    if not customer:
        raise NotFoundError("Customer not found")
    customer = repo.update(customer, **data.model_dump(exclude_unset=True))
    db.commit()
    db.refresh(customer)
    return customer
