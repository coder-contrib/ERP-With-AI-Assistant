from sqlalchemy.orm import Session
from app.models.payments import CustomerPayment, SupplierPayment, CashTransaction


class PaymentRepository:
    def __init__(self, db: Session):
        self.db = db

    def create_customer_payment(self, **kwargs) -> CustomerPayment:
        payment = CustomerPayment(**kwargs)
        self.db.add(payment)
        self.db.flush()
        return payment

    def create_supplier_payment(self, **kwargs) -> SupplierPayment:
        payment = SupplierPayment(**kwargs)
        self.db.add(payment)
        self.db.flush()
        return payment

    def create_cash_transaction(self, **kwargs) -> CashTransaction:
        txn = CashTransaction(**kwargs)
        self.db.add(txn)
        self.db.flush()
        return txn
