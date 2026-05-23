from sqlalchemy.orm import Session
from app.models.customers import Customer


class CustomerRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_all(self) -> list[Customer]:
        return self.db.query(Customer).all()

    def get_by_id(self, customer_id: int) -> Customer | None:
        return self.db.query(Customer).filter(Customer.customer_id == customer_id).first()

    def create(self, **kwargs) -> Customer:
        customer = Customer(**kwargs)
        self.db.add(customer)
        self.db.flush()
        return customer

    def update(self, customer: Customer, **kwargs) -> Customer:
        for key, value in kwargs.items():
            if value is not None:
                setattr(customer, key, value)
        self.db.flush()
        return customer

    def update_balance(self, customer: Customer, amount) -> None:
        customer.current_balance += amount
        self.db.flush()
