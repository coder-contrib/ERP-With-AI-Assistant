from sqlalchemy.orm import Session
from app.models.purchases import PurchaseInvoice, PurchaseInvoiceItem, PurchaseReturn, PurchaseReturnItem


class PurchaseRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_all(self) -> list[PurchaseInvoice]:
        return self.db.query(PurchaseInvoice).order_by(PurchaseInvoice.purchase_date.desc()).all()

    def get_by_id(self, purchase_invoice_id: int) -> PurchaseInvoice | None:
        return self.db.query(PurchaseInvoice).filter(
            PurchaseInvoice.purchase_invoice_id == purchase_invoice_id
        ).first()

    def create_invoice(self, **kwargs) -> PurchaseInvoice:
        invoice = PurchaseInvoice(**kwargs)
        self.db.add(invoice)
        self.db.flush()
        return invoice

    def create_item(self, **kwargs) -> PurchaseInvoiceItem:
        item = PurchaseInvoiceItem(**kwargs)
        self.db.add(item)
        self.db.flush()
        return item

    def get_items_for_invoice(self, purchase_invoice_id: int) -> list[PurchaseInvoiceItem]:
        return self.db.query(PurchaseInvoiceItem).filter(
            PurchaseInvoiceItem.purchase_invoice_id == purchase_invoice_id
        ).all()

    def get_returns_for_invoice(self, purchase_invoice_id: int) -> list[PurchaseReturn]:
        return self.db.query(PurchaseReturn).filter(
            PurchaseReturn.original_purchase_invoice_id == purchase_invoice_id
        ).order_by(PurchaseReturn.return_date.desc()).all()

    def create_return(self, **kwargs) -> PurchaseReturn:
        purchase_return = PurchaseReturn(**kwargs)
        self.db.add(purchase_return)
        self.db.flush()
        return purchase_return

    def create_return_item(self, **kwargs) -> PurchaseReturnItem:
        item = PurchaseReturnItem(**kwargs)
        self.db.add(item)
        self.db.flush()
        return item
