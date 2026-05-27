from sqlalchemy.orm import Session
from sqlalchemy import func
from decimal import Decimal
from datetime import datetime
from app.models.sales import SalesInvoice, SalesInvoiceItem
from app.models.inventory import InventoryTransaction, InventoryCache
from app.models.payments import CustomerPayment, CashTransaction
from app.models.customers import Customer
from app.models.products import Product
from app.models.transfers import WarehouseTransfer


class ActionTools:
    """Write/action tools for the AI Agent.
    These tools allow the AI to perform real operations:
    create invoices, record payments, manage stock, and CRM actions.
    """

    def __init__(self, db: Session):
        self.db = db

    # ─── Sales Actions ───────────────────────────────────────────────────────

    def create_invoice(
        self,
        customer_id: int | None,
        items: list[dict],
        payment_type: str = "cash",
        warehouse_id: int = 1,
        discount: float = 0,
        paid_amount: float | None = None,
        notes: str | None = None,
    ) -> dict:
        if not items:
            return {"error": "Items list cannot be empty"}

        if payment_type not in ("cash", "credit", "mixed"):
            return {"error": "payment_type must be 'cash', 'credit', or 'mixed'"}

        if customer_id:
            customer = self.db.query(Customer).filter(Customer.customer_id == customer_id).first()
            if not customer:
                return {"error": f"Customer {customer_id} not found"}

        validated_items = []
        for item in items:
            product_id = item.get("product_id")
            quantity = Decimal(str(item.get("quantity", 0)))
            unit_price = item.get("unit_price")
            unit_type = item.get("unit_type", "meter")

            if not product_id or quantity <= 0:
                return {"error": f"Invalid item: product_id and quantity > 0 required"}

            product = self.db.query(Product).filter(Product.product_id == product_id).first()
            if not product:
                return {"error": f"Product {product_id} not found"}

            stock = self.db.query(InventoryCache).filter(
                InventoryCache.product_id == product_id,
                InventoryCache.warehouse_id == warehouse_id,
            ).first()

            if not stock or stock.cached_quantity < quantity:
                available = stock.cached_quantity if stock else 0
                return {
                    "error": f"Insufficient stock for '{product.product_name}': "
                             f"requested {quantity}, available {available} in warehouse {warehouse_id}"
                }

            if unit_price is None:
                unit_price = float(product.selling_price) if product.selling_price else 0

            item_discount = Decimal(str(item.get("discount", 0)))
            line_total = (quantity * Decimal(str(unit_price))) - item_discount

            validated_items.append({
                "product_id": product_id,
                "product_name": product.product_name,
                "quantity": quantity,
                "unit_type": unit_type,
                "unit_price": Decimal(str(unit_price)),
                "cost": stock.cached_avg_cost if stock else Decimal("0"),
                "discount": item_discount,
                "total": line_total,
            })

        subtotal = sum(i["total"] for i in validated_items)
        discount_amount = Decimal(str(discount))
        total_amount = subtotal - discount_amount
        if total_amount < 0:
            total_amount = Decimal("0")

        if paid_amount is None:
            paid = total_amount if payment_type == "cash" else Decimal("0")
        else:
            paid = Decimal(str(paid_amount))

        remaining = total_amount - paid
        if remaining < 0:
            remaining = Decimal("0")

        if paid >= total_amount:
            status = "paid"
        elif paid > 0:
            status = "partial"
        else:
            status = "unpaid"

        invoice_number = f"INV-{datetime.now().strftime('%Y%m%d%H%M%S')}"

        invoice = SalesInvoice(
            customer_id=customer_id,
            invoice_number=invoice_number,
            invoice_type=payment_type,
            total_amount=total_amount,
            discount_amount=discount_amount,
            paid_amount=paid,
            remaining_amount=remaining,
            payment_status=status,
            warehouse_id=warehouse_id,
            notes=notes,
        )
        self.db.add(invoice)
        self.db.flush()

        for vi in validated_items:
            inv_item = SalesInvoiceItem(
                invoice_id=invoice.invoice_id,
                product_id=vi["product_id"],
                sold_quantity=vi["quantity"],
                unit_type=vi["unit_type"],
                unit_price=vi["unit_price"],
                cost_at_sale=vi["cost"],
                discount=vi["discount"],
                total_price=vi["total"],
            )
            self.db.add(inv_item)

            stock = self.db.query(InventoryCache).filter(
                InventoryCache.product_id == vi["product_id"],
                InventoryCache.warehouse_id == warehouse_id,
            ).first()
            stock.cached_quantity -= vi["quantity"]

            txn = InventoryTransaction(
                product_id=vi["product_id"],
                warehouse_id=warehouse_id,
                transaction_type="sale",
                direction="out",
                quantity=vi["quantity"],
                unit_type=vi["unit_type"],
                cost_per_unit=vi["cost"],
                reference_type="sales_invoice",
                reference_id=invoice.invoice_id,
            )
            self.db.add(txn)

        if paid > 0:
            cash_txn = CashTransaction(
                transaction_type="cash_in",
                amount=paid,
                entity_type="sales_invoice",
                entity_id=invoice.invoice_id,
                description=f"Payment for {invoice_number}",
            )
            self.db.add(cash_txn)

        if customer_id and remaining > 0:
            customer = self.db.query(Customer).filter(Customer.customer_id == customer_id).first()
            customer.current_balance += remaining

        self.db.commit()

        return {
            "success": True,
            "invoice_id": invoice.invoice_id,
            "invoice_number": invoice_number,
            "total_amount": str(total_amount),
            "paid": str(paid),
            "remaining": str(remaining),
            "status": status,
            "items_count": len(validated_items),
        }

    def cancel_invoice(self, invoice_id: int, reason: str | None = None) -> dict:
        invoice = self.db.query(SalesInvoice).filter(SalesInvoice.invoice_id == invoice_id).first()
        if not invoice:
            return {"error": f"Invoice {invoice_id} not found"}

        if invoice.payment_status == "cancelled":
            return {"error": "Invoice is already cancelled"}

        items = self.db.query(SalesInvoiceItem).filter(SalesInvoiceItem.invoice_id == invoice_id).all()
        for item in items:
            stock = self.db.query(InventoryCache).filter(
                InventoryCache.product_id == item.product_id,
                InventoryCache.warehouse_id == invoice.warehouse_id,
            ).first()
            if stock:
                stock.cached_quantity += item.sold_quantity

            txn = InventoryTransaction(
                product_id=item.product_id,
                warehouse_id=invoice.warehouse_id,
                transaction_type="sale_cancellation",
                direction="in",
                quantity=item.sold_quantity,
                unit_type=item.unit_type,
                cost_per_unit=item.cost_at_sale,
                reference_type="sales_invoice",
                reference_id=invoice_id,
                notes=reason,
            )
            self.db.add(txn)

        if invoice.paid_amount > 0:
            cash_txn = CashTransaction(
                transaction_type="cash_out",
                amount=invoice.paid_amount,
                entity_type="sales_invoice_cancel",
                entity_id=invoice_id,
                description=f"Refund for cancelled invoice {invoice.invoice_number}",
            )
            self.db.add(cash_txn)

        if invoice.customer_id and invoice.remaining_amount > 0:
            customer = self.db.query(Customer).filter(Customer.customer_id == invoice.customer_id).first()
            if customer:
                customer.current_balance -= invoice.remaining_amount

        old_status = invoice.payment_status
        invoice.payment_status = "cancelled"
        invoice.notes = (invoice.notes or "") + f"\n[CANCELLED] {reason or 'No reason provided'}"
        self.db.commit()

        return {
            "success": True,
            "invoice_id": invoice_id,
            "invoice_number": invoice.invoice_number,
            "previous_status": old_status,
            "refunded_amount": str(invoice.paid_amount),
            "stock_restored": len(items),
        }

    def apply_discount(self, invoice_id: int, discount_amount: float) -> dict:
        invoice = self.db.query(SalesInvoice).filter(SalesInvoice.invoice_id == invoice_id).first()
        if not invoice:
            return {"error": f"Invoice {invoice_id} not found"}

        if invoice.payment_status == "cancelled":
            return {"error": "Cannot modify a cancelled invoice"}

        new_discount = Decimal(str(discount_amount))
        items_total = self.db.query(
            func.coalesce(func.sum(SalesInvoiceItem.total_price), 0)
        ).filter(SalesInvoiceItem.invoice_id == invoice_id).scalar()

        new_total = Decimal(str(items_total)) - new_discount
        if new_total < 0:
            return {"error": "Discount exceeds invoice total"}

        old_discount = invoice.discount_amount
        invoice.discount_amount = new_discount
        invoice.total_amount = new_total
        invoice.remaining_amount = new_total - invoice.paid_amount
        if invoice.remaining_amount < 0:
            invoice.remaining_amount = Decimal("0")

        if invoice.paid_amount >= new_total:
            invoice.payment_status = "paid"
        elif invoice.paid_amount > 0:
            invoice.payment_status = "partial"
        else:
            invoice.payment_status = "unpaid"

        self.db.commit()

        return {
            "success": True,
            "invoice_id": invoice_id,
            "old_discount": str(old_discount),
            "new_discount": str(new_discount),
            "new_total": str(new_total),
            "remaining": str(invoice.remaining_amount),
            "status": invoice.payment_status,
        }

    # ─── Payment Actions ─────────────────────────────────────────────────────

    def record_payment(
        self,
        customer_id: int,
        invoice_id: int,
        amount: float,
        notes: str | None = None,
    ) -> dict:
        if amount <= 0:
            return {"error": "Amount must be greater than 0"}

        customer = self.db.query(Customer).filter(Customer.customer_id == customer_id).first()
        if not customer:
            return {"error": f"Customer {customer_id} not found"}

        invoice = self.db.query(SalesInvoice).filter(SalesInvoice.invoice_id == invoice_id).first()
        if not invoice:
            return {"error": f"Invoice {invoice_id} not found"}

        if invoice.payment_status in ("paid", "cancelled"):
            return {"error": f"Invoice is already {invoice.payment_status}"}

        payment_amount = Decimal(str(amount))
        if payment_amount > invoice.remaining_amount:
            return {"error": f"Payment {amount} exceeds remaining {invoice.remaining_amount}"}

        payment = CustomerPayment(
            customer_id=customer_id,
            related_invoice_id=invoice_id,
            payment_amount=payment_amount,
            notes=notes,
        )
        self.db.add(payment)

        invoice.paid_amount += payment_amount
        invoice.remaining_amount -= payment_amount
        if invoice.remaining_amount <= 0:
            invoice.remaining_amount = Decimal("0")
            invoice.payment_status = "paid"
        else:
            invoice.payment_status = "partial"

        customer.current_balance -= payment_amount
        if customer.current_balance < 0:
            customer.current_balance = Decimal("0")

        cash_txn = CashTransaction(
            transaction_type="cash_in",
            amount=payment_amount,
            entity_type="customer_payment",
            entity_id=payment.payment_id,
            description=f"Payment from {customer.customer_name} for {invoice.invoice_number}",
        )
        self.db.add(cash_txn)
        self.db.commit()

        return {
            "success": True,
            "payment_id": payment.payment_id,
            "amount": str(payment_amount),
            "invoice_number": invoice.invoice_number,
            "new_remaining": str(invoice.remaining_amount),
            "invoice_status": invoice.payment_status,
            "customer_balance": str(customer.current_balance),
        }

    def refund_payment(self, invoice_id: int, amount: float, reason: str | None = None) -> dict:
        if amount <= 0:
            return {"error": "Amount must be greater than 0"}

        invoice = self.db.query(SalesInvoice).filter(SalesInvoice.invoice_id == invoice_id).first()
        if not invoice:
            return {"error": f"Invoice {invoice_id} not found"}

        refund = Decimal(str(amount))
        if refund > invoice.paid_amount:
            return {"error": f"Refund {amount} exceeds paid amount {invoice.paid_amount}"}

        invoice.paid_amount -= refund
        invoice.remaining_amount += refund

        if invoice.paid_amount <= 0:
            invoice.payment_status = "unpaid"
        elif invoice.remaining_amount > 0:
            invoice.payment_status = "partial"

        if invoice.customer_id:
            customer = self.db.query(Customer).filter(Customer.customer_id == invoice.customer_id).first()
            if customer:
                customer.current_balance += refund

        cash_txn = CashTransaction(
            transaction_type="cash_out",
            amount=refund,
            entity_type="refund",
            entity_id=invoice_id,
            description=f"Refund for {invoice.invoice_number}: {reason or 'No reason'}",
        )
        self.db.add(cash_txn)
        self.db.commit()

        return {
            "success": True,
            "invoice_id": invoice_id,
            "invoice_number": invoice.invoice_number,
            "refunded": str(refund),
            "new_paid": str(invoice.paid_amount),
            "new_remaining": str(invoice.remaining_amount),
            "status": invoice.payment_status,
        }

    # ─── Inventory Actions ───────────────────────────────────────────────────

    def update_stock(
        self,
        product_id: int,
        warehouse_id: int,
        quantity: float,
        cost_per_unit: float = 0,
        notes: str | None = None,
    ) -> dict:
        if quantity <= 0:
            return {"error": "Quantity must be greater than 0"}

        product = self.db.query(Product).filter(Product.product_id == product_id).first()
        if not product:
            return {"error": f"Product {product_id} not found"}

        qty = Decimal(str(quantity))
        cost = Decimal(str(cost_per_unit))

        stock = self.db.query(InventoryCache).filter(
            InventoryCache.product_id == product_id,
            InventoryCache.warehouse_id == warehouse_id,
        ).first()

        if stock:
            stock.cached_quantity += qty
            if cost > 0:
                total_cost = (stock.cached_total_cost_in or Decimal("0")) + (qty * cost)
                total_qty = (stock.cached_total_qty_in or Decimal("0")) + qty
                stock.cached_avg_cost = total_cost / total_qty if total_qty > 0 else cost
                stock.cached_total_cost_in = total_cost
                stock.cached_total_qty_in = total_qty
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
            transaction_type="stock_in",
            direction="in",
            quantity=qty,
            unit_type=product.base_unit or "meter",
            cost_per_unit=cost,
            notes=notes,
        )
        self.db.add(txn)
        self.db.commit()

        return {
            "success": True,
            "product_id": product_id,
            "product_name": product.product_name,
            "warehouse_id": warehouse_id,
            "added_quantity": str(qty),
            "new_total_quantity": str(stock.cached_quantity),
            "avg_cost": str(stock.cached_avg_cost),
        }

    def transfer_stock(
        self,
        product_id: int,
        from_warehouse_id: int,
        to_warehouse_id: int,
        quantity: float,
        notes: str | None = None,
    ) -> dict:
        if quantity <= 0:
            return {"error": "Quantity must be greater than 0"}

        if from_warehouse_id == to_warehouse_id:
            return {"error": "Source and destination warehouse must be different"}

        product = self.db.query(Product).filter(Product.product_id == product_id).first()
        if not product:
            return {"error": f"Product {product_id} not found"}

        qty = Decimal(str(quantity))

        source_stock = self.db.query(InventoryCache).filter(
            InventoryCache.product_id == product_id,
            InventoryCache.warehouse_id == from_warehouse_id,
        ).first()

        if not source_stock or source_stock.cached_quantity < qty:
            available = source_stock.cached_quantity if source_stock else 0
            return {
                "error": f"Insufficient stock in warehouse {from_warehouse_id}: "
                         f"requested {quantity}, available {available}"
            }

        cost = source_stock.cached_avg_cost

        source_stock.cached_quantity -= qty

        dest_stock = self.db.query(InventoryCache).filter(
            InventoryCache.product_id == product_id,
            InventoryCache.warehouse_id == to_warehouse_id,
        ).first()

        if dest_stock:
            dest_stock.cached_quantity += qty
        else:
            dest_stock = InventoryCache(
                product_id=product_id,
                warehouse_id=to_warehouse_id,
                cached_quantity=qty,
                cached_avg_cost=cost,
                cached_total_cost_in=qty * cost,
                cached_total_qty_in=qty,
            )
            self.db.add(dest_stock)

        transfer = WarehouseTransfer(
            from_warehouse_id=from_warehouse_id,
            to_warehouse_id=to_warehouse_id,
            product_id=product_id,
            quantity=qty,
            notes=notes,
        )
        self.db.add(transfer)

        txn_out = InventoryTransaction(
            product_id=product_id,
            warehouse_id=from_warehouse_id,
            transaction_type="transfer_out",
            direction="out",
            quantity=qty,
            unit_type=product.base_unit or "meter",
            cost_per_unit=cost,
            warehouse_from=from_warehouse_id,
            warehouse_to=to_warehouse_id,
            reference_type="warehouse_transfer",
            reference_id=transfer.transfer_id,
            notes=notes,
        )
        txn_in = InventoryTransaction(
            product_id=product_id,
            warehouse_id=to_warehouse_id,
            transaction_type="transfer_in",
            direction="in",
            quantity=qty,
            unit_type=product.base_unit or "meter",
            cost_per_unit=cost,
            warehouse_from=from_warehouse_id,
            warehouse_to=to_warehouse_id,
            reference_type="warehouse_transfer",
            reference_id=transfer.transfer_id,
            notes=notes,
        )
        self.db.add(txn_out)
        self.db.add(txn_in)
        self.db.commit()

        return {
            "success": True,
            "transfer_id": transfer.transfer_id,
            "product_name": product.product_name,
            "quantity": str(qty),
            "from_warehouse": from_warehouse_id,
            "to_warehouse": to_warehouse_id,
            "source_remaining": str(source_stock.cached_quantity),
            "dest_new_total": str(dest_stock.cached_quantity),
        }

    def adjust_stock(
        self,
        product_id: int,
        warehouse_id: int,
        new_quantity: float,
        reason: str = "manual_adjustment",
    ) -> dict:
        product = self.db.query(Product).filter(Product.product_id == product_id).first()
        if not product:
            return {"error": f"Product {product_id} not found"}

        new_qty = Decimal(str(new_quantity))
        if new_qty < 0:
            return {"error": "Quantity cannot be negative"}

        stock = self.db.query(InventoryCache).filter(
            InventoryCache.product_id == product_id,
            InventoryCache.warehouse_id == warehouse_id,
        ).first()

        old_qty = stock.cached_quantity if stock else Decimal("0")
        diff = new_qty - old_qty

        if stock:
            stock.cached_quantity = new_qty
        else:
            stock = InventoryCache(
                product_id=product_id,
                warehouse_id=warehouse_id,
                cached_quantity=new_qty,
                cached_avg_cost=Decimal("0"),
                cached_total_cost_in=Decimal("0"),
                cached_total_qty_in=new_qty,
            )
            self.db.add(stock)

        direction = "in" if diff > 0 else "out"
        txn = InventoryTransaction(
            product_id=product_id,
            warehouse_id=warehouse_id,
            transaction_type="adjustment",
            direction=direction,
            quantity=abs(diff),
            unit_type=product.base_unit or "meter",
            cost_per_unit=stock.cached_avg_cost,
            notes=reason,
        )
        self.db.add(txn)
        self.db.commit()

        return {
            "success": True,
            "product_id": product_id,
            "product_name": product.product_name,
            "warehouse_id": warehouse_id,
            "old_quantity": str(old_qty),
            "new_quantity": str(new_qty),
            "adjustment": str(diff),
            "reason": reason,
        }

    # ─── CRM Actions ─────────────────────────────────────────────────────────

    def create_customer(
        self,
        name: str,
        phone: str | None = None,
        address: str | None = None,
        credit_limit: float = 0,
        payment_terms: int = 0,
        notes: str | None = None,
    ) -> dict:
        if not name or not name.strip():
            return {"error": "Customer name is required"}

        existing = self.db.query(Customer).filter(Customer.customer_name == name.strip()).first()
        if existing:
            return {"error": f"Customer '{name}' already exists (ID: {existing.customer_id})"}

        customer = Customer(
            customer_name=name.strip(),
            phone_number=phone,
            address=address,
            current_balance=Decimal("0"),
            credit_limit=Decimal(str(credit_limit)),
            payment_terms=payment_terms,
            notes=notes,
        )
        self.db.add(customer)
        self.db.commit()

        return {
            "success": True,
            "customer_id": customer.customer_id,
            "name": customer.customer_name,
            "credit_limit": str(customer.credit_limit),
            "payment_terms": customer.payment_terms,
        }

    def update_customer(
        self,
        customer_id: int,
        name: str | None = None,
        phone: str | None = None,
        address: str | None = None,
        credit_limit: float | None = None,
        payment_terms: int | None = None,
        notes: str | None = None,
    ) -> dict:
        customer = self.db.query(Customer).filter(Customer.customer_id == customer_id).first()
        if not customer:
            return {"error": f"Customer {customer_id} not found"}

        updated_fields = []
        if name is not None:
            customer.customer_name = name.strip()
            updated_fields.append("name")
        if phone is not None:
            customer.phone_number = phone
            updated_fields.append("phone")
        if address is not None:
            customer.address = address
            updated_fields.append("address")
        if credit_limit is not None:
            customer.credit_limit = Decimal(str(credit_limit))
            updated_fields.append("credit_limit")
        if payment_terms is not None:
            customer.payment_terms = payment_terms
            updated_fields.append("payment_terms")
        if notes is not None:
            customer.notes = notes
            updated_fields.append("notes")

        if not updated_fields:
            return {"error": "No fields to update"}

        self.db.commit()

        return {
            "success": True,
            "customer_id": customer.customer_id,
            "name": customer.customer_name,
            "updated_fields": updated_fields,
            "credit_limit": str(customer.credit_limit),
            "balance": str(customer.current_balance),
        }
