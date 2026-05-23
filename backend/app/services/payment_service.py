from sqlalchemy.orm import Session
from decimal import Decimal
from app.database import transaction
from app.repositories.payment_repo import PaymentRepository
from app.repositories.customer_repo import CustomerRepository
from app.repositories.supplier_repo import SupplierRepository
from app.services.cash_service import CashService
from app.services.ledger_service import LedgerService
from app.core.validators import Validator
from app.events.event_bus import Event, get_event_bus
from app.events.payment_events import PAYMENT_RECEIVED, PAYMENT_MADE
from app.schemas.payments import CustomerPaymentCreate, SupplierPaymentCreate
from app.core.exceptions import NotFoundError


class PaymentService:
    def __init__(self, db: Session):
        self.db = db
        self.payment_repo = PaymentRepository(db)
        self.customer_repo = CustomerRepository(db)
        self.supplier_repo = SupplierRepository(db)
        self.cash = CashService(db)
        self.ledger = LedgerService(db)
        self.validator = Validator(db)
        self.event_bus = get_event_bus()

    def receive_customer_payment(self, data: CustomerPaymentCreate) -> int:
        with transaction(self.db):
            self.validator.validate_positive_amount(data.payment_amount, "Payment amount")

            customer = self.customer_repo.get_by_id(data.customer_id)
            if not customer:
                raise NotFoundError("Customer not found")

            payment = self.payment_repo.create_customer_payment(**data.model_dump())
            self.customer_repo.update_balance(customer, -data.payment_amount)
            self.cash.record_cash_in(
                amount=data.payment_amount,
                entity_type="customer_payment",
                entity_id=payment.payment_id,
            )
            self.ledger.record_customer_payment(
                payment_id=payment.payment_id,
                amount=data.payment_amount,
            )

        self.event_bus.publish(Event(
            event_type=PAYMENT_RECEIVED,
            data={
                "payment_id": payment.payment_id,
                "customer_id": data.customer_id,
                "amount": str(data.payment_amount),
                "related_invoice_id": data.related_invoice_id,
            },
        ))
        return payment.payment_id

    def make_supplier_payment(self, data: SupplierPaymentCreate) -> int:
        with transaction(self.db):
            self.validator.validate_positive_amount(data.payment_amount, "Payment amount")

            supplier = self.supplier_repo.get_by_id(data.supplier_id)
            if not supplier:
                raise NotFoundError("Supplier not found")

            payment = self.payment_repo.create_supplier_payment(**data.model_dump())
            self.supplier_repo.update_balance(supplier, -data.payment_amount)
            self.supplier_repo.record_payment_date(supplier)
            self.cash.record_cash_out(
                amount=data.payment_amount,
                entity_type="supplier_payment",
                entity_id=payment.payment_id,
            )
            self.ledger.record_supplier_payment(
                payment_id=payment.payment_id,
                amount=data.payment_amount,
            )

        self.event_bus.publish(Event(
            event_type=PAYMENT_MADE,
            data={
                "payment_id": payment.payment_id,
                "supplier_id": data.supplier_id,
                "amount": str(data.payment_amount),
                "related_purchase_invoice_id": data.related_purchase_invoice_id,
            },
        ))
        return payment.payment_id
