from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.customers import CustomerCreate, CustomerUpdate, CustomerResponse
from app.services.customer_service import CustomerService
from app.core.deps import require_permission
from app.models.users import User

router = APIRouter()


@router.get("/", response_model=list[CustomerResponse])
def list_customers(current_user: User = Depends(require_permission("customers:read")), db: Session = Depends(get_db)):
    service = CustomerService(db)
    return service.list_all()


@router.get("/{customer_id}", response_model=CustomerResponse)
def get_customer(customer_id: int, current_user: User = Depends(require_permission("customers:read")), db: Session = Depends(get_db)):
    service = CustomerService(db)
    return service.get(customer_id)


@router.post("/", response_model=CustomerResponse, status_code=201)
def create_customer(data: CustomerCreate, current_user: User = Depends(require_permission("customers:write")), db: Session = Depends(get_db)):
    service = CustomerService(db)
    return service.create(data)


@router.put("/{customer_id}", response_model=CustomerResponse)
def update_customer(customer_id: int, data: CustomerUpdate, current_user: User = Depends(require_permission("customers:write")), db: Session = Depends(get_db)):
    service = CustomerService(db)
    return service.update(customer_id, data)
