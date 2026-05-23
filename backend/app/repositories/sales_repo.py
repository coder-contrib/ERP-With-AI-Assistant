from sqlalchemy.orm import Session
from app.models.sales import SalesInvoice, SalesInvoiceItem


class SalesRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_all(self) -> list[SalesInvoice]:
        return self.db.query(SalesInvoice).order_by(SalesInvoice.invoice_date.desc()).all()

    def get_by_id(self, invoice_id: int) -> SalesInvoice | None:
        return self.db.query(SalesInvoice).filter(SalesInvoice.invoice_id == invoice_id).first()

    def create_invoice(self, **kwargs) -> SalesInvoice:
        invoice = SalesInvoice(**kwargs)
        self.db.add(invoice)
        self.db.flush()
        return invoice

    def create_item(self, **kwargs) -> SalesInvoiceItem:
        item = SalesInvoiceItem(**kwargs)
        self.db.add(item)
        self.db.flush()
        return item

    def get_items(self, invoice_id: int) -> list[SalesInvoiceItem]:
        return self.db.query(SalesInvoiceItem).filter(
            SalesInvoiceItem.invoice_id == invoice_id
        ).all()
