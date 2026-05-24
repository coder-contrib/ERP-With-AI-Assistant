from sqlalchemy.orm import Session
from decimal import Decimal
from datetime import date
from app.models.customers import Customer
from app.models.suppliers import Supplier
from app.models.accounting import LedgerEntry
from app.models.payments import CashTransaction
from app.services.ledger_service import ACCOUNT_CODES
from app.services.cache_service import CacheService
from app.core.redis import get_redis


class OpeningBalanceService:
    def __init__(self, db: Session):
        self.db = db
        self.cache = CacheService(get_redis())

    def set_customer_opening_balance(
        self,
        customer_id: int,
        amount: Decimal,
        balance_type: str = "receivable",
        notes: str | None = None,
    ) -> dict:
        customer = self.db.query(Customer).filter(Customer.customer_id == customer_id).first()
        if not customer:
            raise ValueError(f"Customer {customer_id} not found")

        customer.current_balance = amount

        if balance_type == "receivable":
            entry = LedgerEntry(
                account_id=ACCOUNT_CODES["accounts_receivable"],
                debit=amount,
                credit=Decimal("0"),
                entity_type="opening_balance",
                entity_id=customer_id,
                description=f"Opening balance (receivable) for customer: {customer.customer_name}",
            )
        else:
            entry = LedgerEntry(
                account_id=ACCOUNT_CODES["accounts_receivable"],
                debit=Decimal("0"),
                credit=amount,
                entity_type="opening_balance",
                entity_id=customer_id,
                description=f"Opening balance (advance) for customer: {customer.customer_name}",
            )
        self.db.add(entry)
        self.cache.invalidate_dashboard()

        return {
            "entity_type": "customer",
            "entity_id": customer_id,
            "entity_name": customer.customer_name,
            "amount": str(amount),
            "balance_type": balance_type,
            "notes": notes,
        }

    def set_supplier_opening_balance(
        self,
        supplier_id: int,
        amount: Decimal,
        balance_type: str = "payable",
        notes: str | None = None,
    ) -> dict:
        supplier = self.db.query(Supplier).filter(Supplier.supplier_id == supplier_id).first()
        if not supplier:
            raise ValueError(f"Supplier {supplier_id} not found")

        supplier.current_balance = amount

        if balance_type == "payable":
            entry = LedgerEntry(
                account_id=ACCOUNT_CODES["accounts_payable"],
                debit=Decimal("0"),
                credit=amount,
                entity_type="opening_balance",
                entity_id=supplier_id,
                description=f"Opening balance (payable) for supplier: {supplier.supplier_name}",
            )
        else:
            entry = LedgerEntry(
                account_id=ACCOUNT_CODES["accounts_payable"],
                debit=amount,
                credit=Decimal("0"),
                entity_type="opening_balance",
                entity_id=supplier_id,
                description=f"Opening balance (advance) for supplier: {supplier.supplier_name}",
            )
        self.db.add(entry)
        self.cache.invalidate_dashboard()

        return {
            "entity_type": "supplier",
            "entity_id": supplier_id,
            "entity_name": supplier.supplier_name,
            "amount": str(amount),
            "balance_type": balance_type,
            "notes": notes,
        }

    def set_cash_opening_balance(
        self,
        amount: Decimal,
        account_name: str = "cash",
        notes: str | None = None,
    ) -> dict:
        entry = LedgerEntry(
            account_id=ACCOUNT_CODES["cash"],
            debit=amount,
            credit=Decimal("0"),
            entity_type="opening_balance",
            entity_id=0,
            description=f"Opening cash/bank balance: {account_name}",
        )
        self.db.add(entry)

        equity_entry = LedgerEntry(
            account_id=ACCOUNT_CODES["owner_equity"],
            debit=Decimal("0"),
            credit=amount,
            entity_type="opening_balance",
            entity_id=0,
            description=f"Owner equity from opening balance: {account_name}",
        )
        self.db.add(equity_entry)

        cash_tx = CashTransaction(
            transaction_type="cash_in",
            amount=amount,
            entity_type="opening_balance",
            entity_id=0,
            description=f"Opening balance: {account_name}" + (f" - {notes}" if notes else ""),
        )
        self.db.add(cash_tx)

        self.cache.invalidate_dashboard()

        return {
            "entity_type": "cash",
            "entity_id": 0,
            "entity_name": account_name,
            "amount": str(amount),
            "balance_type": "cash",
            "notes": notes,
        }

    def get_opening_balances(self, entity_type: str | None = None) -> list[dict]:
        query = self.db.query(LedgerEntry).filter(LedgerEntry.entity_type == "opening_balance")
        entries = query.all()

        results = []
        for e in entries:
            if entity_type == "customer" and "customer" not in (e.description or ""):
                continue
            if entity_type == "supplier" and "supplier" not in (e.description or ""):
                continue
            if entity_type == "cash" and "cash" not in (e.description or "").lower():
                continue

            results.append({
                "id": e.entry_id,
                "entity_type": "customer" if "customer" in (e.description or "") else "supplier" if "supplier" in (e.description or "") else "cash",
                "entity_id": e.entity_id,
                "amount": str(e.debit if e.debit > 0 else e.credit),
                "balance_type": "receivable" if e.debit > 0 and e.account_id == ACCOUNT_CODES["accounts_receivable"] else "payable" if e.credit > 0 and e.account_id == ACCOUNT_CODES["accounts_payable"] else "advance" if (e.credit > 0 and e.account_id == ACCOUNT_CODES["accounts_receivable"]) or (e.debit > 0 and e.account_id == ACCOUNT_CODES["accounts_payable"]) else "cash",
                "notes": e.description,
            })
        return results
