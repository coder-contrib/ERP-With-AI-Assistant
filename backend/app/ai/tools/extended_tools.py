"""Extended tools for full ERP control.
Covers: opening balances, expenses, invoice retrieval, purchases, suppliers, products.
"""
from sqlalchemy.orm import Session
from sqlalchemy import func, desc
from decimal import Decimal
from datetime import date, datetime
from app.config import settings
from app.models.sales import SalesInvoice, SalesInvoiceItem, SalesReturn, SalesReturnItem
from app.models.purchases import PurchaseInvoice, PurchaseInvoiceItem, PurchaseReturn, PurchaseReturnItem
from app.models.inventory import InventoryTransaction, InventoryCache
from app.models.payments import CustomerPayment, SupplierPayment, CashTransaction
from app.models.customers import Customer
from app.models.suppliers import Supplier
from app.models.products import Product
from app.models.expenses import Expense, ExpenseCategory


def _check_write_permission() -> dict | None:
    if not settings.ai_can_write:
        return {"error": "AI write operations are disabled. Contact admin to enable AI_CAN_WRITE."}
    return None


class ExtendedTools:
    """Additional tools giving AI full ERP control."""

    def __init__(self, db: Session):
        self.db = db

    # ═══════════════════════════════════════════════════════════════════════════
    # OPENING BALANCES
    # ═══════════════════════════════════════════════════════════════════════════

    def set_customer_opening_balance(
        self,
        customer_id: int,
        amount: float,
        balance_type: str = "debit",
        notes: str | None = None,
    ) -> dict:
        if err := _check_write_permission():
            return err

        from app.services.opening_balance_service import OpeningBalanceService
        service = OpeningBalanceService(self.db)
        try:
            result = service.set_customer_opening_balance(
                customer_id=customer_id,
                amount=Decimal(str(amount)),
                balance_type=balance_type,
                notes=notes,
            )
            self.db.commit()
            return {
                "success": True,
                "customer_id": customer_id,
                "amount": str(amount),
                "balance_type": balance_type,
                "message": f"تم تسجيل رصيد أول المدة {amount} جنيه للعميل #{customer_id}",
            }
        except ValueError as e:
            return {"error": str(e)}

    def set_supplier_opening_balance(
        self,
        supplier_id: int,
        amount: float,
        balance_type: str = "credit",
        notes: str | None = None,
    ) -> dict:
        if err := _check_write_permission():
            return err

        from app.services.opening_balance_service import OpeningBalanceService
        service = OpeningBalanceService(self.db)
        try:
            result = service.set_supplier_opening_balance(
                supplier_id=supplier_id,
                amount=Decimal(str(amount)),
                balance_type=balance_type,
                notes=notes,
            )
            self.db.commit()
            return {
                "success": True,
                "supplier_id": supplier_id,
                "amount": str(amount),
                "balance_type": balance_type,
                "message": f"تم تسجيل رصيد أول المدة {amount} جنيه للمورد #{supplier_id}",
            }
        except ValueError as e:
            return {"error": str(e)}

    def set_cash_opening_balance(
        self,
        amount: float,
        account_name: str = "الصندوق الرئيسي",
        notes: str | None = None,
    ) -> dict:
        if err := _check_write_permission():
            return err

        from app.services.opening_balance_service import OpeningBalanceService
        service = OpeningBalanceService(self.db)
        result = service.set_cash_opening_balance(
            amount=Decimal(str(amount)),
            account_name=account_name,
            notes=notes,
        )
        self.db.commit()
        return {
            "success": True,
            "amount": str(amount),
            "account_name": account_name,
            "message": f"تم تسجيل رصيد الكاش أول المدة {amount} جنيه",
        }

    def set_opening_inventory(
        self,
        product_id: int,
        warehouse_id: int,
        quantity: float,
        cost_per_unit: float,
        notes: str | None = None,
    ) -> dict:
        if err := _check_write_permission():
            return err

        product = self.db.query(Product).filter(Product.product_id == product_id).first()
        if not product:
            return {"error": f"المنتج #{product_id} غير موجود"}

        qty = Decimal(str(quantity))
        cost = Decimal(str(cost_per_unit))

        if qty <= 0:
            return {"error": "الكمية يجب أن تكون أكبر من صفر"}

        stock = self.db.query(InventoryCache).filter(
            InventoryCache.product_id == product_id,
            InventoryCache.warehouse_id == warehouse_id,
        ).first()

        if stock:
            stock.cached_quantity = qty
            stock.cached_avg_cost = cost
            stock.cached_total_cost_in = qty * cost
            stock.cached_total_qty_in = qty
        else:
            stock = InventoryCache(
                product_id=product_id,
                warehouse_id=warehouse_id,
                cached_quantity=qty,
                cached_avg_cost=cost,
                cached_total_cost_in=qty * cost,
                cached_total_qty_in=qty,
            )
            self.db.add(stock)

        txn = InventoryTransaction(
            product_id=product_id,
            warehouse_id=warehouse_id,
            transaction_type="opening_balance",
            direction="in",
            quantity=qty,
            unit_type=product.base_unit or "meter",
            cost_per_unit=cost,
            notes=notes or "رصيد أول المدة",
        )
        self.db.add(txn)
        self.db.commit()

        return {
            "success": True,
            "product_id": product_id,
            "product_name": product.product_name,
            "warehouse_id": warehouse_id,
            "quantity": str(qty),
            "cost_per_unit": str(cost),
            "total_value": str(qty * cost),
            "message": f"تم تسجيل مخزون أول المدة: {qty} وحدة من {product.product_name}",
        }

    def get_opening_balances(self, entity_type: str | None = None) -> dict:
        from app.services.opening_balance_service import OpeningBalanceService
        service = OpeningBalanceService(self.db)
        balances = service.get_opening_balances(entity_type)
        return {"balances": balances, "count": len(balances) if isinstance(balances, list) else 0}

    # ═══════════════════════════════════════════════════════════════════════════
    # EXPENSES
    # ═══════════════════════════════════════════════════════════════════════════

    def create_expense(
        self,
        name: str,
        amount: float,
        category: str = "Miscellaneous",
        notes: str | None = None,
        expense_date: str | None = None,
    ) -> dict:
        if err := _check_write_permission():
            return err

        if amount <= 0:
            return {"error": "المبلغ يجب أن يكون أكبر من صفر"}

        exp_date = datetime.now()
        if expense_date:
            try:
                exp_date = datetime.fromisoformat(expense_date)
            except ValueError:
                return {"error": "تنسيق التاريخ غير صحيح. استخدم YYYY-MM-DD"}

        expense = Expense(
            expense_name=name,
            amount=Decimal(str(amount)),
            expense_category=category,
            notes=notes,
            expense_date=exp_date,
        )
        self.db.add(expense)

        cash_txn = CashTransaction(
            transaction_type="cash_out",
            amount=Decimal(str(amount)),
            entity_type="expense",
            entity_id=0,
            description=f"مصروف: {name} ({category})",
        )
        self.db.add(cash_txn)
        self.db.commit()

        cash_txn.entity_id = expense.expense_id
        self.db.commit()

        return {
            "success": True,
            "expense_id": expense.expense_id,
            "name": name,
            "amount": str(amount),
            "category": category,
            "date": exp_date.strftime("%Y-%m-%d"),
            "message": f"تم تسجيل مصروف '{name}' بمبلغ {amount} جنيه",
        }

    def list_expenses(
        self,
        date_from: str | None = None,
        date_to: str | None = None,
        category: str | None = None,
        search: str | None = None,
        limit: int = 20,
    ) -> dict:
        query = self.db.query(Expense).order_by(desc(Expense.expense_date))

        if date_from:
            query = query.filter(func.date(Expense.expense_date) >= date_from)
        if date_to:
            query = query.filter(func.date(Expense.expense_date) <= date_to)
        if category:
            query = query.filter(Expense.expense_category == category)
        if search:
            query = query.filter(
                Expense.expense_name.ilike(f"%{search}%") |
                Expense.notes.ilike(f"%{search}%")
            )

        expenses = query.limit(limit).all()
        return {
            "expenses": [
                {
                    "expense_id": e.expense_id,
                    "name": e.expense_name,
                    "amount": str(e.amount),
                    "category": e.expense_category,
                    "date": str(e.expense_date)[:10] if e.expense_date else "",
                    "notes": e.notes,
                }
                for e in expenses
            ],
            "count": len(expenses),
        }

    def get_expense_summary(self) -> dict:
        today = date.today()
        first_of_month = today.replace(day=1)

        total_today = self.db.query(
            func.coalesce(func.sum(Expense.amount), 0)
        ).filter(func.date(Expense.expense_date) == today).scalar()

        total_month = self.db.query(
            func.coalesce(func.sum(Expense.amount), 0)
        ).filter(
            func.date(Expense.expense_date) >= first_of_month,
            func.date(Expense.expense_date) <= today,
        ).scalar()

        highest = self.db.query(
            Expense.expense_category,
            func.sum(Expense.amount).label("total"),
        ).filter(
            func.date(Expense.expense_date) >= first_of_month,
        ).group_by(Expense.expense_category).order_by(desc("total")).first()

        return {
            "total_today": str(total_today),
            "total_month": str(total_month),
            "highest_category": highest[0] if highest else None,
            "highest_category_amount": str(highest[1]) if highest else "0",
        }

    # ═══════════════════════════════════════════════════════════════════════════
    # SALES INVOICE RETRIEVAL
    # ═══════════════════════════════════════════════════════════════════════════

    def list_sales_invoices(self, limit: int = 20, status: str | None = None) -> dict:
        query = self.db.query(SalesInvoice).order_by(desc(SalesInvoice.created_at))
        if status:
            query = query.filter(SalesInvoice.payment_status == status)
        invoices = query.limit(limit).all()
        return {
            "invoices": [
                {
                    "invoice_id": inv.invoice_id,
                    "invoice_number": inv.invoice_number,
                    "customer_id": inv.customer_id,
                    "total_amount": str(inv.total_amount),
                    "paid_amount": str(inv.paid_amount),
                    "remaining_amount": str(inv.remaining_amount),
                    "payment_status": inv.payment_status,
                    "invoice_type": inv.invoice_type,
                    "date": str(inv.created_at)[:10] if inv.created_at else "",
                }
                for inv in invoices
            ],
            "count": len(invoices),
        }

    def get_sales_invoice(self, invoice_id: int) -> dict:
        invoice = self.db.query(SalesInvoice).filter(SalesInvoice.invoice_id == invoice_id).first()
        if not invoice:
            return {"error": f"الفاتورة #{invoice_id} غير موجودة"}

        customer_name = ""
        if invoice.customer_id:
            c = self.db.query(Customer).filter(Customer.customer_id == invoice.customer_id).first()
            customer_name = c.customer_name if c else ""

        return {
            "invoice_id": invoice.invoice_id,
            "invoice_number": invoice.invoice_number,
            "customer_id": invoice.customer_id,
            "customer_name": customer_name,
            "total_amount": str(invoice.total_amount),
            "discount_amount": str(invoice.discount_amount),
            "paid_amount": str(invoice.paid_amount),
            "remaining_amount": str(invoice.remaining_amount),
            "payment_status": invoice.payment_status,
            "invoice_type": invoice.invoice_type,
            "warehouse_id": invoice.warehouse_id,
            "notes": invoice.notes,
            "date": str(invoice.created_at)[:10] if invoice.created_at else "",
        }

    def get_invoice_items(self, invoice_id: int) -> dict:
        invoice = self.db.query(SalesInvoice).filter(SalesInvoice.invoice_id == invoice_id).first()
        if not invoice:
            return {"error": f"الفاتورة #{invoice_id} غير موجودة"}

        rows = (
            self.db.query(
                SalesInvoiceItem.item_id,
                SalesInvoiceItem.product_id,
                Product.product_name,
                SalesInvoiceItem.sold_quantity,
                SalesInvoiceItem.unit_type,
                SalesInvoiceItem.unit_price,
                SalesInvoiceItem.discount,
                SalesInvoiceItem.total_price,
            )
            .join(Product, Product.product_id == SalesInvoiceItem.product_id)
            .filter(SalesInvoiceItem.invoice_id == invoice_id)
            .all()
        )

        return {
            "invoice_id": invoice_id,
            "invoice_number": invoice.invoice_number,
            "items": [
                {
                    "item_id": r.item_id,
                    "product_id": r.product_id,
                    "product_name": r.product_name,
                    "quantity": str(r.sold_quantity),
                    "unit_type": r.unit_type,
                    "unit_price": str(r.unit_price),
                    "discount": str(r.discount),
                    "total_price": str(r.total_price),
                }
                for r in rows
            ],
            "items_count": len(rows),
        }

    def create_sales_return(
        self,
        invoice_id: int,
        items: list[dict],
        reason: str | None = None,
    ) -> dict:
        if err := _check_write_permission():
            return err

        from app.services.sales_service import SalesService
        from app.schemas.sales import SalesReturnCreate, SalesReturnItemCreate
        service = SalesService(self.db)

        return_items = [
            SalesReturnItemCreate(
                product_id=i["product_id"],
                returned_quantity=i["quantity"],
                return_price=i.get("return_price", 0),
            )
            for i in items
        ]
        data = SalesReturnCreate(reason=reason or "", items=return_items)

        try:
            result = service.process_return(invoice_id, data)
            return {
                "success": True,
                "return_id": result.return_id,
                "invoice_id": invoice_id,
                "items_returned": len(items),
                "message": f"تم إرجاع {len(items)} أصناف من الفاتورة #{invoice_id}",
            }
        except Exception as e:
            return {"error": str(e)}

    # ═══════════════════════════════════════════════════════════════════════════
    # PURCHASE INVOICES
    # ═══════════════════════════════════════════════════════════════════════════

    def list_purchase_invoices(self, limit: int = 20) -> dict:
        from app.services.purchase_service import PurchaseService
        service = PurchaseService(self.db)
        invoices = service.list_invoices()
        result_list = invoices[:limit] if isinstance(invoices, list) else []
        return {
            "invoices": [
                {
                    "purchase_invoice_id": getattr(inv, "purchase_invoice_id", None),
                    "supplier_id": getattr(inv, "supplier_id", None),
                    "total_amount": str(getattr(inv, "total_amount", 0)),
                    "paid_amount": str(getattr(inv, "paid_amount", 0)),
                    "remaining_amount": str(getattr(inv, "remaining_amount", 0)),
                    "payment_status": getattr(inv, "payment_status", ""),
                    "date": str(getattr(inv, "created_at", ""))[:10],
                }
                for inv in result_list
            ],
            "count": len(result_list),
        }

    def get_purchase_invoice(self, purchase_invoice_id: int) -> dict:
        from app.services.purchase_service import PurchaseService
        service = PurchaseService(self.db)
        try:
            inv = service.get_invoice(purchase_invoice_id)
            supplier_name = ""
            if inv.supplier_id:
                s = self.db.query(Supplier).filter(Supplier.supplier_id == inv.supplier_id).first()
                supplier_name = s.supplier_name if s else ""
            return {
                "purchase_invoice_id": inv.purchase_invoice_id,
                "supplier_id": inv.supplier_id,
                "supplier_name": supplier_name,
                "total_amount": str(inv.total_amount),
                "paid_amount": str(inv.paid_amount),
                "remaining_amount": str(inv.remaining_amount),
                "payment_status": inv.payment_status,
                "notes": inv.notes,
                "date": str(inv.created_at)[:10] if inv.created_at else "",
            }
        except Exception as e:
            return {"error": str(e)}

    def get_purchase_items(self, purchase_invoice_id: int) -> dict:
        rows = (
            self.db.query(
                PurchaseInvoiceItem.item_id,
                PurchaseInvoiceItem.product_id,
                Product.product_name,
                PurchaseInvoiceItem.purchased_quantity,
                PurchaseInvoiceItem.purchase_price,
                PurchaseInvoiceItem.total_cost,
            )
            .join(Product, Product.product_id == PurchaseInvoiceItem.product_id)
            .filter(PurchaseInvoiceItem.purchase_invoice_id == purchase_invoice_id)
            .all()
        )

        if not rows:
            return {"error": f"فاتورة المشتريات #{purchase_invoice_id} غير موجودة أو فارغة"}

        return {
            "purchase_invoice_id": purchase_invoice_id,
            "items": [
                {
                    "item_id": r.item_id,
                    "product_id": r.product_id,
                    "product_name": r.product_name,
                    "quantity": str(r.purchased_quantity),
                    "purchase_price": str(r.purchase_price),
                    "total_cost": str(r.total_cost),
                }
                for r in rows
            ],
            "items_count": len(rows),
        }

    def create_purchase_invoice(
        self,
        supplier_id: int,
        items: list[dict],
        payment_type: str = "cash",
        paid_amount: float | None = None,
        warehouse_id: int = 1,
        notes: str | None = None,
    ) -> dict:
        if err := _check_write_permission():
            return err

        from app.services.purchase_service import PurchaseService
        from app.schemas.purchases import PurchaseInvoiceCreate, PurchaseItemCreate
        service = PurchaseService(self.db)

        purchase_items = [
            PurchaseItemCreate(
                product_id=i["product_id"],
                purchased_quantity=i["quantity"],
                purchase_price=i["purchase_price"],
            )
            for i in items
        ]

        data = PurchaseInvoiceCreate(
            supplier_id=supplier_id,
            items=purchase_items,
            payment_type=payment_type,
            paid_amount=Decimal(str(paid_amount)) if paid_amount is not None else None,
            warehouse_id=warehouse_id,
            notes=notes,
        )

        try:
            result = service.create_invoice(data)
            return {
                "success": True,
                "purchase_invoice_id": result.purchase_invoice_id,
                "total_amount": str(result.total_amount),
                "paid_amount": str(result.paid_amount),
                "remaining_amount": str(result.remaining_amount),
                "items_count": len(items),
                "message": f"تم إنشاء فاتورة مشتريات بـ {len(items)} أصناف",
            }
        except Exception as e:
            return {"error": str(e)}

    def create_purchase_return(
        self,
        purchase_invoice_id: int,
        items: list[dict],
        reason: str | None = None,
    ) -> dict:
        if err := _check_write_permission():
            return err

        from app.services.purchase_service import PurchaseService
        from app.schemas.purchases import PurchaseReturnCreate, PurchaseReturnItemCreate
        service = PurchaseService(self.db)

        return_items = [
            PurchaseReturnItemCreate(
                product_id=i["product_id"],
                returned_quantity=i["quantity"],
                return_price=i.get("return_price", 0),
            )
            for i in items
        ]
        data = PurchaseReturnCreate(reason=reason or "", items=return_items)

        try:
            result = service.process_return(purchase_invoice_id, data)
            return {
                "success": True,
                "return_id": result.return_id,
                "purchase_invoice_id": purchase_invoice_id,
                "items_returned": len(items),
                "message": f"تم إرجاع {len(items)} أصناف لفاتورة المشتريات #{purchase_invoice_id}",
            }
        except Exception as e:
            return {"error": str(e)}

    # ═══════════════════════════════════════════════════════════════════════════
    # SUPPLIERS
    # ═══════════════════════════════════════════════════════════════════════════

    def create_supplier(
        self,
        name: str,
        phone: str | None = None,
        address: str | None = None,
        notes: str | None = None,
    ) -> dict:
        if err := _check_write_permission():
            return err

        if not name or not name.strip():
            return {"error": "اسم المورد مطلوب"}

        existing = self.db.query(Supplier).filter(Supplier.supplier_name == name.strip()).first()
        if existing:
            return {"error": f"المورد '{name}' موجود بالفعل (ID: {existing.supplier_id})"}

        supplier = Supplier(
            supplier_name=name.strip(),
            phone_number=phone,
            address=address,
            current_balance=Decimal("0"),
            notes=notes,
        )
        self.db.add(supplier)
        self.db.commit()

        return {
            "success": True,
            "supplier_id": supplier.supplier_id,
            "name": supplier.supplier_name,
            "message": f"تم إنشاء المورد '{name}'",
        }

    def update_supplier(
        self,
        supplier_id: int,
        name: str | None = None,
        phone: str | None = None,
        address: str | None = None,
        notes: str | None = None,
    ) -> dict:
        if err := _check_write_permission():
            return err

        supplier = self.db.query(Supplier).filter(Supplier.supplier_id == supplier_id).first()
        if not supplier:
            return {"error": f"المورد #{supplier_id} غير موجود"}

        updated = []
        if name is not None:
            supplier.supplier_name = name.strip()
            updated.append("name")
        if phone is not None:
            supplier.phone_number = phone
            updated.append("phone")
        if address is not None:
            supplier.address = address
            updated.append("address")
        if notes is not None:
            supplier.notes = notes
            updated.append("notes")

        if not updated:
            return {"error": "لا يوجد حقول للتحديث"}

        self.db.commit()
        return {
            "success": True,
            "supplier_id": supplier_id,
            "name": supplier.supplier_name,
            "updated_fields": updated,
        }

    def search_suppliers(self, query: str, limit: int = 10) -> dict:
        results = (
            self.db.query(Supplier)
            .filter(
                Supplier.supplier_name.ilike(f"%{query}%") |
                Supplier.phone_number.ilike(f"%{query}%")
            )
            .limit(limit)
            .all()
        )
        return {
            "suppliers": [
                {
                    "supplier_id": s.supplier_id,
                    "name": s.supplier_name,
                    "phone": s.phone_number,
                    "address": s.address,
                    "balance": str(s.current_balance),
                }
                for s in results
            ],
            "count": len(results),
        }

    # ═══════════════════════════════════════════════════════════════════════════
    # PRODUCTS
    # ═══════════════════════════════════════════════════════════════════════════

    def create_product(
        self,
        name: str,
        sku: str | None = None,
        category_id: int | None = None,
        selling_price: float = 0,
        cost_price: float = 0,
        base_unit: str = "meter",
        barcode: str | None = None,
        notes: str | None = None,
    ) -> dict:
        if err := _check_write_permission():
            return err

        if not name or not name.strip():
            return {"error": "اسم المنتج مطلوب"}

        existing = self.db.query(Product).filter(Product.product_name == name.strip()).first()
        if existing:
            return {"error": f"المنتج '{name}' موجود بالفعل (ID: {existing.product_id})"}

        product = Product(
            product_name=name.strip(),
            sku=sku,
            category_id=category_id,
            selling_price=Decimal(str(selling_price)),
            cost_price=Decimal(str(cost_price)),
            base_unit=base_unit,
            barcode=barcode,
            notes=notes,
        )
        self.db.add(product)
        self.db.commit()

        return {
            "success": True,
            "product_id": product.product_id,
            "name": product.product_name,
            "selling_price": str(selling_price),
            "cost_price": str(cost_price),
            "message": f"تم إنشاء المنتج '{name}'",
        }

    def update_product(
        self,
        product_id: int,
        name: str | None = None,
        selling_price: float | None = None,
        cost_price: float | None = None,
        category_id: int | None = None,
        base_unit: str | None = None,
        barcode: str | None = None,
        notes: str | None = None,
    ) -> dict:
        if err := _check_write_permission():
            return err

        product = self.db.query(Product).filter(Product.product_id == product_id).first()
        if not product:
            return {"error": f"المنتج #{product_id} غير موجود"}

        updated = []
        if name is not None:
            product.product_name = name.strip()
            updated.append("name")
        if selling_price is not None:
            product.selling_price = Decimal(str(selling_price))
            updated.append("selling_price")
        if cost_price is not None:
            product.cost_price = Decimal(str(cost_price))
            updated.append("cost_price")
        if category_id is not None:
            product.category_id = category_id
            updated.append("category_id")
        if base_unit is not None:
            product.base_unit = base_unit
            updated.append("base_unit")
        if barcode is not None:
            product.barcode = barcode
            updated.append("barcode")
        if notes is not None:
            product.notes = notes
            updated.append("notes")

        if not updated:
            return {"error": "لا يوجد حقول للتحديث"}

        self.db.commit()
        return {
            "success": True,
            "product_id": product_id,
            "name": product.product_name,
            "updated_fields": updated,
        }

    def get_product(self, product_id: int) -> dict:
        product = self.db.query(Product).filter(Product.product_id == product_id).first()
        if not product:
            return {"error": f"المنتج #{product_id} غير موجود"}

        stocks = (
            self.db.query(InventoryCache)
            .filter(InventoryCache.product_id == product_id)
            .all()
        )
        total_qty = sum(s.cached_quantity for s in stocks)

        return {
            "product_id": product.product_id,
            "name": product.product_name,
            "sku": product.sku,
            "category_id": product.category_id,
            "selling_price": str(product.selling_price),
            "cost_price": str(product.cost_price),
            "base_unit": product.base_unit,
            "barcode": product.barcode,
            "total_stock": str(total_qty),
            "warehouses": [
                {
                    "warehouse_id": s.warehouse_id,
                    "quantity": str(s.cached_quantity),
                    "avg_cost": str(s.cached_avg_cost),
                }
                for s in stocks
            ],
        }
