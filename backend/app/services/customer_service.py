from sqlalchemy.orm import Session
from app.database import transaction
from app.repositories.customer_repo import CustomerRepository
from app.schemas.customers import CustomerCreate, CustomerUpdate
from app.models.customers import Customer
from app.core.exceptions import NotFoundError


class CustomerService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = CustomerRepository(db)

    def list_all(self) -> list[Customer]:
        return self.repo.get_all()

    def get(self, customer_id: int) -> Customer:
        customer = self.repo.get_by_id(customer_id)
        if not customer:
            raise NotFoundError("Customer not found")
        return customer

    def create(self, data: CustomerCreate) -> Customer:
        with transaction(self.db):
            customer = self.repo.create(**data.model_dump())
        self.db.refresh(customer)
        return customer

    def update(self, customer_id: int, data: CustomerUpdate) -> Customer:
        with transaction(self.db):
            customer = self.get(customer_id)
            customer = self.repo.update(customer, **data.model_dump(exclude_unset=True))
        self.db.refresh(customer)
        return customer

    def check_credit_limit(self, customer_id: int, amount) -> bool:
        customer = self.get(customer_id)
        if customer.credit_limit <= 0:
            return True
        return (customer.current_balance + amount) <= customer.credit_limit
