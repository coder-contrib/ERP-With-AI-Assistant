from sqlalchemy.orm import Session
from decimal import Decimal
from app.models.accounting import LedgerEntry

ACCOUNT_CODES = {
    "cash": 1,
    "accounts_receivable": 2,
    "inventory": 3,
    "accounts_payable": 4,
    "owner_equity": 5,
    "sales_revenue": 6,
    "sales_returns": 7,
    "cogs": 8,
    "purchase_returns": 9,
    "operating_expenses": 10,
}


class LedgerService:
    def __init__(self, db: Session):
        self.db = db

    def _entry(self, account_id: int, debit: Decimal, credit: Decimal,
               entity_type: str, entity_id: int, description: str = ""):
        entry = LedgerEntry(
            account_id=account_id,
            debit=debit,
            credit=credit,
            entity_type=entity_type,
            entity_id=entity_id,
            description=description,
        )
        self.db.add(entry)

    def record_sale(self, invoice_id: int, total_amount: Decimal, cogs: Decimal,
                    cash_received: Decimal, is_credit: bool):
        if is_credit:
            receivable = total_amount - cash_received
            if cash_received > 0:
                self._entry(ACCOUNT_CODES["cash"], debit=cash_received, credit=Decimal("0"),
                            entity_type="sales_invoice", entity_id=invoice_id, description="Cash from sale")
            if receivable > 0:
                self._entry(ACCOUNT_CODES["accounts_receivable"], debit=receivable, credit=Decimal("0"),
                            entity_type="sales_invoice", entity_id=invoice_id, description="Credit sale receivable")
        else:
            self._entry(ACCOUNT_CODES["cash"], debit=total_amount, credit=Decimal("0"),
                        entity_type="sales_invoice", entity_id=invoice_id, description="Cash sale")

        self._entry(ACCOUNT_CODES["sales_revenue"], debit=Decimal("0"), credit=total_amount,
                    entity_type="sales_invoice", entity_id=invoice_id, description="Sales revenue")

        self._entry(ACCOUNT_CODES["cogs"], debit=cogs, credit=Decimal("0"),
                    entity_type="sales_invoice", entity_id=invoice_id, description="Cost of goods sold")

        self._entry(ACCOUNT_CODES["inventory"], debit=Decimal("0"), credit=cogs,
                    entity_type="sales_invoice", entity_id=invoice_id, description="Inventory reduction")

    def record_purchase(self, purchase_invoice_id: int, total_amount: Decimal,
                        cash_paid: Decimal, is_credit: bool):
        self._entry(ACCOUNT_CODES["inventory"], debit=total_amount, credit=Decimal("0"),
                    entity_type="purchase_invoice", entity_id=purchase_invoice_id, description="Inventory addition")

        if cash_paid > 0:
            self._entry(ACCOUNT_CODES["cash"], debit=Decimal("0"), credit=cash_paid,
                        entity_type="purchase_invoice", entity_id=purchase_invoice_id, description="Cash paid for purchase")
        if is_credit:
            payable = total_amount - cash_paid
            if payable > 0:
                self._entry(ACCOUNT_CODES["accounts_payable"], debit=Decimal("0"), credit=payable,
                            entity_type="purchase_invoice", entity_id=purchase_invoice_id, description="Purchase on credit")

    def record_customer_payment(self, payment_id: int, amount: Decimal):
        self._entry(ACCOUNT_CODES["cash"], debit=amount, credit=Decimal("0"),
                    entity_type="customer_payment", entity_id=payment_id, description="Customer payment received")
        self._entry(ACCOUNT_CODES["accounts_receivable"], debit=Decimal("0"), credit=amount,
                    entity_type="customer_payment", entity_id=payment_id, description="Receivable settled")

    def record_supplier_payment(self, payment_id: int, amount: Decimal):
        self._entry(ACCOUNT_CODES["accounts_payable"], debit=amount, credit=Decimal("0"),
                    entity_type="supplier_payment", entity_id=payment_id, description="Payable settled")
        self._entry(ACCOUNT_CODES["cash"], debit=Decimal("0"), credit=amount,
                    entity_type="supplier_payment", entity_id=payment_id, description="Cash paid to supplier")

    def record_expense(self, expense_id: int, amount: Decimal, category: str):
        self._entry(ACCOUNT_CODES["operating_expenses"], debit=amount, credit=Decimal("0"),
                    entity_type="expense", entity_id=expense_id, description=f"Expense: {category}")
        self._entry(ACCOUNT_CODES["cash"], debit=Decimal("0"), credit=amount,
                    entity_type="expense", entity_id=expense_id, description=f"Cash out: {category}")

    def record_sales_return(self, return_id: int, returned_amount: Decimal,
                            refund_amount: Decimal, cogs: Decimal):
        self._entry(ACCOUNT_CODES["sales_returns"], debit=returned_amount, credit=Decimal("0"),
                    entity_type="sales_return", entity_id=return_id, description="Sales return")
        if refund_amount > 0:
            self._entry(ACCOUNT_CODES["cash"], debit=Decimal("0"), credit=refund_amount,
                        entity_type="sales_return", entity_id=return_id, description="Cash refund for return")
        credit_portion = returned_amount - refund_amount
        if credit_portion > 0:
            self._entry(ACCOUNT_CODES["accounts_receivable"], debit=Decimal("0"), credit=credit_portion,
                        entity_type="sales_return", entity_id=return_id, description="Receivable reduced by return")
        self._entry(ACCOUNT_CODES["inventory"], debit=cogs, credit=Decimal("0"),
                    entity_type="sales_return", entity_id=return_id, description="Inventory restored from return")
        self._entry(ACCOUNT_CODES["cogs"], debit=Decimal("0"), credit=cogs,
                    entity_type="sales_return", entity_id=return_id, description="COGS reversal for return")
