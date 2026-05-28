from sqlalchemy.orm import Session
from sqlalchemy import func, case, extract, and_
from decimal import Decimal
from datetime import date, timedelta
from app.models.sales import SalesInvoice, SalesInvoiceItem
from app.models.purchases import PurchaseInvoice
from app.models.customers import Customer
from app.models.suppliers import Supplier
from app.models.products import Product
from app.models.inventory import InventoryCache, InventoryTransaction
from app.models.payments import CashTransaction
from app.models.expenses import Expense
from app.models.waste import Waste
from app.models.warehouses import Warehouse
from app.models.accounting import DailyFinancialSummary


class ReportService:
    def __init__(self, db: Session):
        self.db = db

    # ─── EXISTING REPORTS ───────────────────────────────────────────

    def daily_sales(self, start_date: date, end_date: date) -> list[dict]:
        results = self.db.query(
            func.date(SalesInvoice.invoice_date).label("day"),
            func.count(SalesInvoice.invoice_id).label("invoice_count"),
            func.coalesce(func.sum(SalesInvoice.total_amount), 0).label("total_sales"),
            func.coalesce(func.sum(SalesInvoice.discount_amount), 0).label("total_discount"),
            func.coalesce(func.sum(SalesInvoice.paid_amount), 0).label("cash_collected"),
            func.coalesce(func.sum(
                case((SalesInvoice.invoice_type == "credit", SalesInvoice.total_amount), else_=0)
            ), 0).label("credit_sales"),
        ).filter(
            func.date(SalesInvoice.invoice_date) >= start_date,
            func.date(SalesInvoice.invoice_date) <= end_date,
        ).group_by(func.date(SalesInvoice.invoice_date)
        ).order_by(func.date(SalesInvoice.invoice_date)).all()

        return [
            {
                "date": str(r.day),
                "invoice_count": r.invoice_count,
                "total_sales": str(r.total_sales),
                "total_discount": str(r.total_discount),
                "cash_collected": str(r.cash_collected),
                "credit_sales": str(r.credit_sales),
            }
            for r in results
        ]

    def monthly_profit(self, year: int) -> list[dict]:
        results = self.db.query(
            extract("month", DailyFinancialSummary.summary_date).label("month"),
            func.sum(DailyFinancialSummary.revenue).label("revenue"),
            func.sum(DailyFinancialSummary.cogs).label("cogs"),
            func.sum(DailyFinancialSummary.gross_profit).label("gross_profit"),
            func.sum(DailyFinancialSummary.expenses).label("expenses"),
            func.sum(DailyFinancialSummary.net_profit).label("net_profit"),
        ).filter(
            extract("year", DailyFinancialSummary.summary_date) == year,
        ).group_by(extract("month", DailyFinancialSummary.summary_date)
        ).order_by(extract("month", DailyFinancialSummary.summary_date)).all()

        return [
            {
                "month": f"{year}-{int(r.month):02d}",
                "revenue": str(r.revenue or 0),
                "cogs": str(r.cogs or 0),
                "gross_profit": str(r.gross_profit or 0),
                "gross_margin": str(
                    round((r.gross_profit / r.revenue * 100), 2)
                    if r.revenue and r.revenue > 0 else 0
                ),
                "expenses": str(r.expenses or 0),
                "net_profit": str(r.net_profit or 0),
            }
            for r in results
        ]

    def top_selling_products(self, start_date: date, end_date: date, limit: int = 20) -> list[dict]:
        results = self.db.query(
            SalesInvoiceItem.product_id,
            Product.product_name,
            func.sum(SalesInvoiceItem.sold_quantity).label("total_quantity"),
            func.sum(SalesInvoiceItem.total_price).label("total_revenue"),
        ).join(Product, Product.product_id == SalesInvoiceItem.product_id
        ).join(SalesInvoice, SalesInvoice.invoice_id == SalesInvoiceItem.invoice_id
        ).filter(
            func.date(SalesInvoice.invoice_date) >= start_date,
            func.date(SalesInvoice.invoice_date) <= end_date,
        ).group_by(SalesInvoiceItem.product_id, Product.product_name
        ).order_by(func.sum(SalesInvoiceItem.total_price).desc()
        ).limit(limit).all()

        return [
            {
                "product_id": r.product_id,
                "product_name": r.product_name,
                "total_quantity": str(r.total_quantity),
                "total_revenue": str(r.total_revenue),
            }
            for r in results
        ]

    def inventory_valuation(self, warehouse_id: int | None = None) -> dict:
        query = self.db.query(
            InventoryCache.warehouse_id,
            Warehouse.warehouse_name,
            func.count(InventoryCache.product_id).label("product_count"),
            func.sum(InventoryCache.cached_quantity).label("total_quantity"),
            func.sum(InventoryCache.cached_quantity * InventoryCache.cached_avg_cost).label("total_value"),
        ).join(Warehouse, Warehouse.warehouse_id == InventoryCache.warehouse_id)
        if warehouse_id:
            query = query.filter(InventoryCache.warehouse_id == warehouse_id)
        results = query.group_by(InventoryCache.warehouse_id, Warehouse.warehouse_name).all()

        warehouses = [
            {
                "warehouse_id": r.warehouse_id,
                "warehouse_name": r.warehouse_name,
                "product_count": r.product_count,
                "total_quantity": str(r.total_quantity or 0),
                "total_value": str(r.total_value or 0),
            }
            for r in results
        ]
        return {
            "warehouses": warehouses,
            "grand_total_value": str(sum(r.total_value or 0 for r in results)),
        }

    def customer_balances(self) -> list[dict]:
        results = self.db.query(Customer).filter(
            Customer.current_balance > 0
        ).order_by(Customer.current_balance.desc()).all()

        return [
            {
                "customer_id": c.customer_id,
                "customer_name": c.customer_name,
                "current_balance": str(c.current_balance),
                "credit_limit": str(c.credit_limit),
                "over_limit": c.credit_limit > 0 and c.current_balance > c.credit_limit,
            }
            for c in results
        ]

    def supplier_balances(self) -> list[dict]:
        results = self.db.query(Supplier).filter(
            Supplier.current_balance > 0
        ).order_by(Supplier.current_balance.desc()).all()

        return [
            {
                "supplier_id": s.supplier_id,
                "supplier_name": s.supplier_name,
                "current_balance": str(s.current_balance),
                "payment_terms": s.payment_terms,
            }
            for s in results
        ]

    def cash_flow(self, start_date: date, end_date: date) -> dict:
        results = self.db.query(
            func.date(CashTransaction.transaction_date).label("day"),
            func.coalesce(func.sum(
                case((CashTransaction.transaction_type == "cash_in", CashTransaction.amount), else_=0)
            ), 0).label("cash_in"),
            func.coalesce(func.sum(
                case((CashTransaction.transaction_type == "cash_out", CashTransaction.amount), else_=0)
            ), 0).label("cash_out"),
        ).filter(
            func.date(CashTransaction.transaction_date) >= start_date,
            func.date(CashTransaction.transaction_date) <= end_date,
        ).group_by(func.date(CashTransaction.transaction_date)
        ).order_by(func.date(CashTransaction.transaction_date)).all()

        days = [
            {
                "date": str(r.day),
                "cash_in": str(r.cash_in),
                "cash_out": str(r.cash_out),
                "net": str(r.cash_in - r.cash_out),
            }
            for r in results
        ]
        return {
            "period": {"start": str(start_date), "end": str(end_date)},
            "days": days,
            "total_in": str(sum(r.cash_in for r in results)),
            "total_out": str(sum(r.cash_out for r in results)),
            "net_flow": str(sum(r.cash_in - r.cash_out for r in results)),
        }

    def waste_report(self, start_date: date, end_date: date) -> dict:
        results = self.db.query(
            Waste.product_id,
            Product.product_name,
            Waste.warehouse_id,
            func.sum(Waste.quantity).label("total_quantity"),
            Waste.waste_reason,
        ).join(Product, Product.product_id == Waste.product_id
        ).filter(
            func.date(Waste.waste_date) >= start_date,
            func.date(Waste.waste_date) <= end_date,
        ).group_by(
            Waste.product_id, Product.product_name, Waste.warehouse_id, Waste.waste_reason
        ).order_by(func.sum(Waste.quantity).desc()).all()

        items = [
            {
                "product_id": r.product_id,
                "product_name": r.product_name,
                "warehouse_id": r.warehouse_id,
                "total_quantity": str(r.total_quantity),
                "waste_reason": r.waste_reason,
            }
            for r in results
        ]
        return {
            "period": {"start": str(start_date), "end": str(end_date)},
            "items": items,
            "total_waste_entries": len(items),
        }

    def warehouse_stock(self, warehouse_id: int) -> dict:
        results = self.db.query(
            InventoryCache.product_id,
            Product.product_name,
            InventoryCache.cached_quantity,
            InventoryCache.cached_avg_cost,
        ).join(Product, Product.product_id == InventoryCache.product_id
        ).filter(
            InventoryCache.warehouse_id == warehouse_id,
            InventoryCache.cached_quantity > 0,
        ).order_by(Product.product_name).all()

        items = [
            {
                "product_id": r.product_id,
                "product_name": r.product_name,
                "quantity": str(r.cached_quantity),
                "avg_cost": str(r.cached_avg_cost),
                "total_value": str(r.cached_quantity * r.cached_avg_cost),
            }
            for r in results
        ]
        total_value = sum(r.cached_quantity * r.cached_avg_cost for r in results)
        return {
            "warehouse_id": warehouse_id,
            "product_count": len(items),
            "total_value": str(total_value),
            "items": items,
        }

    # ─── NEW: SALES REPORTS ─────────────────────────────────────────

    def sales_by_period(self, period: str, start_date: date, end_date: date) -> dict:
        if period == "week":
            group_expr = func.date_trunc("week", SalesInvoice.invoice_date)
        elif period == "month":
            group_expr = func.date_trunc("month", SalesInvoice.invoice_date)
        else:
            group_expr = func.date(SalesInvoice.invoice_date)

        results = self.db.query(
            group_expr.label("period_start"),
            func.count(SalesInvoice.invoice_id).label("invoice_count"),
            func.coalesce(func.sum(SalesInvoice.total_amount), 0).label("total_sales"),
            func.coalesce(func.sum(SalesInvoice.paid_amount), 0).label("cash_collected"),
            func.coalesce(func.sum(SalesInvoice.discount_amount), 0).label("total_discount"),
        ).filter(
            func.date(SalesInvoice.invoice_date) >= start_date,
            func.date(SalesInvoice.invoice_date) <= end_date,
        ).group_by(group_expr
        ).order_by(group_expr).all()

        periods = []
        for i, r in enumerate(results):
            total_sales = float(r.total_sales)
            prev_sales = float(results[i - 1].total_sales) if i > 0 else 0
            growth = round(((total_sales - prev_sales) / prev_sales * 100), 2) if prev_sales > 0 else 0
            avg_invoice = round(total_sales / r.invoice_count, 2) if r.invoice_count > 0 else 0
            periods.append({
                "period_start": str(r.period_start.date() if hasattr(r.period_start, 'date') else r.period_start),
                "invoice_count": r.invoice_count,
                "total_sales": str(r.total_sales),
                "cash_collected": str(r.cash_collected),
                "total_discount": str(r.total_discount),
                "avg_invoice_value": str(avg_invoice),
                "growth_pct": str(growth),
            })

        grand_total = sum(float(r.total_sales) for r in results)
        return {
            "period_type": period,
            "start_date": str(start_date),
            "end_date": str(end_date),
            "total_sales": str(grand_total),
            "total_invoices": sum(r.invoice_count for r in results),
            "periods": periods,
        }

    def sales_invoices(self, start_date: date, end_date: date, status: str | None = None, payment_method: str | None = None) -> dict:
        query = self.db.query(SalesInvoice).filter(
            func.date(SalesInvoice.invoice_date) >= start_date,
            func.date(SalesInvoice.invoice_date) <= end_date,
        )
        if status:
            query = query.filter(SalesInvoice.payment_status == status)
        if payment_method:
            query = query.filter(SalesInvoice.invoice_type == payment_method)
        query = query.order_by(SalesInvoice.invoice_date.desc())
        invoices = query.all()

        items = []
        for inv in invoices:
            customer = self.db.query(Customer.customer_name).filter(
                Customer.customer_id == inv.customer_id
            ).scalar() if inv.customer_id else "Walk-in"
            items.append({
                "invoice_id": inv.invoice_id,
                "invoice_number": inv.invoice_number,
                "customer_name": customer or "Walk-in",
                "invoice_date": str(inv.invoice_date),
                "invoice_type": inv.invoice_type,
                "total_amount": str(inv.total_amount),
                "paid_amount": str(inv.paid_amount),
                "remaining_amount": str(inv.remaining_amount),
                "discount_amount": str(inv.discount_amount),
                "payment_status": inv.payment_status,
            })

        total = sum(float(i["total_amount"]) for i in items)
        paid = sum(float(i["paid_amount"]) for i in items)
        return {
            "period": {"start": str(start_date), "end": str(end_date)},
            "filters": {"status": status, "payment_method": payment_method},
            "summary": {
                "total_invoices": len(items),
                "total_amount": str(total),
                "total_paid": str(paid),
                "total_remaining": str(total - paid),
            },
            "invoices": items,
        }

    def product_performance(self, start_date: date, end_date: date) -> dict:
        results = self.db.query(
            SalesInvoiceItem.product_id,
            Product.product_name,
            func.sum(SalesInvoiceItem.sold_quantity).label("total_quantity"),
            func.sum(SalesInvoiceItem.total_price).label("total_revenue"),
            func.sum(SalesInvoiceItem.cost_at_sale * SalesInvoiceItem.sold_quantity).label("total_cost"),
            func.count(SalesInvoiceItem.item_id).label("times_sold"),
        ).join(Product, Product.product_id == SalesInvoiceItem.product_id
        ).join(SalesInvoice, SalesInvoice.invoice_id == SalesInvoiceItem.invoice_id
        ).filter(
            func.date(SalesInvoice.invoice_date) >= start_date,
            func.date(SalesInvoice.invoice_date) <= end_date,
        ).group_by(SalesInvoiceItem.product_id, Product.product_name
        ).order_by(func.sum(SalesInvoiceItem.total_price).desc()).all()

        items = []
        for r in results:
            revenue = float(r.total_revenue or 0)
            cost = float(r.total_cost or 0)
            profit = revenue - cost
            margin = round((profit / revenue * 100), 2) if revenue > 0 else 0
            items.append({
                "product_id": r.product_id,
                "product_name": r.product_name,
                "total_quantity": str(r.total_quantity),
                "total_revenue": str(r.total_revenue),
                "total_cost": str(r.total_cost or 0),
                "profit": str(round(profit, 2)),
                "margin_pct": str(margin),
                "times_sold": r.times_sold,
            })

        return {
            "period": {"start": str(start_date), "end": str(end_date)},
            "total_revenue": str(sum(float(i["total_revenue"]) for i in items)),
            "total_profit": str(sum(float(i["profit"]) for i in items)),
            "product_count": len(items),
            "products": items,
        }

    # ─── NEW: INVENTORY REPORTS ─────────────────────────────────────

    def low_stock_alert(self, threshold: int = 10) -> dict:
        results = self.db.query(
            InventoryCache.product_id,
            Product.product_name,
            InventoryCache.warehouse_id,
            Warehouse.warehouse_name,
            InventoryCache.cached_quantity,
            InventoryCache.cached_avg_cost,
        ).join(Product, Product.product_id == InventoryCache.product_id
        ).join(Warehouse, Warehouse.warehouse_id == InventoryCache.warehouse_id
        ).filter(
            InventoryCache.cached_quantity <= threshold,
            InventoryCache.cached_quantity > 0,
        ).order_by(InventoryCache.cached_quantity.asc()).all()

        items = [
            {
                "product_id": r.product_id,
                "product_name": r.product_name,
                "warehouse_id": r.warehouse_id,
                "warehouse_name": r.warehouse_name,
                "current_quantity": str(r.cached_quantity),
                "avg_cost": str(r.cached_avg_cost),
                "reorder_suggestion": str(max(threshold * 3 - float(r.cached_quantity), 0)),
            }
            for r in results
        ]

        out_of_stock = self.db.query(
            InventoryCache.product_id,
            Product.product_name,
            InventoryCache.warehouse_id,
            Warehouse.warehouse_name,
        ).join(Product, Product.product_id == InventoryCache.product_id
        ).join(Warehouse, Warehouse.warehouse_id == InventoryCache.warehouse_id
        ).filter(InventoryCache.cached_quantity <= 0).all()

        oos_items = [
            {
                "product_id": r.product_id,
                "product_name": r.product_name,
                "warehouse_id": r.warehouse_id,
                "warehouse_name": r.warehouse_name,
            }
            for r in out_of_stock
        ]

        return {
            "threshold": threshold,
            "low_stock_count": len(items),
            "out_of_stock_count": len(oos_items),
            "low_stock": items,
            "out_of_stock": oos_items,
        }

    def stock_movement(self, start_date: date, end_date: date) -> dict:
        results = self.db.query(
            InventoryTransaction.product_id,
            Product.product_name,
            InventoryTransaction.direction,
            InventoryTransaction.transaction_type,
            func.sum(InventoryTransaction.quantity).label("total_quantity"),
            func.count(InventoryTransaction.transaction_id).label("transaction_count"),
        ).join(Product, Product.product_id == InventoryTransaction.product_id
        ).filter(
            func.date(InventoryTransaction.created_date) >= start_date,
            func.date(InventoryTransaction.created_date) <= end_date,
        ).group_by(
            InventoryTransaction.product_id,
            Product.product_name,
            InventoryTransaction.direction,
            InventoryTransaction.transaction_type,
        ).order_by(Product.product_name).all()

        product_map = {}
        for r in results:
            pid = r.product_id
            if pid not in product_map:
                product_map[pid] = {
                    "product_id": pid,
                    "product_name": r.product_name,
                    "total_in": 0,
                    "total_out": 0,
                    "movements": [],
                }
            qty = float(r.total_quantity)
            if r.direction == "IN":
                product_map[pid]["total_in"] += qty
            else:
                product_map[pid]["total_out"] += qty
            product_map[pid]["movements"].append({
                "type": r.transaction_type,
                "direction": r.direction,
                "quantity": str(r.total_quantity),
                "count": r.transaction_count,
            })

        items = list(product_map.values())
        for item in items:
            item["total_in"] = str(item["total_in"])
            item["total_out"] = str(item["total_out"])
            item["net"] = str(float(item["total_in"]) - float(item["total_out"]))

        return {
            "period": {"start": str(start_date), "end": str(end_date)},
            "product_count": len(items),
            "products": items,
        }

    def dead_stock(self, days: int = 30) -> dict:
        cutoff_date = date.today() - timedelta(days=days)

        active_products = self.db.query(
            InventoryTransaction.product_id
        ).filter(
            func.date(InventoryTransaction.created_date) >= cutoff_date
        ).distinct().subquery()

        results = self.db.query(
            InventoryCache.product_id,
            Product.product_name,
            InventoryCache.warehouse_id,
            Warehouse.warehouse_name,
            InventoryCache.cached_quantity,
            InventoryCache.cached_avg_cost,
        ).join(Product, Product.product_id == InventoryCache.product_id
        ).join(Warehouse, Warehouse.warehouse_id == InventoryCache.warehouse_id
        ).filter(
            InventoryCache.cached_quantity > 0,
            ~InventoryCache.product_id.in_(self.db.query(active_products.c.product_id)),
        ).order_by((InventoryCache.cached_quantity * InventoryCache.cached_avg_cost).desc()).all()

        items = []
        total_value = Decimal(0)
        for r in results:
            value = r.cached_quantity * r.cached_avg_cost
            total_value += value
            last_txn = self.db.query(
                func.max(InventoryTransaction.created_date)
            ).filter(InventoryTransaction.product_id == r.product_id).scalar()
            items.append({
                "product_id": r.product_id,
                "product_name": r.product_name,
                "warehouse_id": r.warehouse_id,
                "warehouse_name": r.warehouse_name,
                "quantity": str(r.cached_quantity),
                "avg_cost": str(r.cached_avg_cost),
                "total_value": str(value),
                "last_movement": str(last_txn) if last_txn else "Never",
            })

        return {
            "days_threshold": days,
            "dead_stock_count": len(items),
            "total_capital_locked": str(total_value),
            "items": items,
        }

    # ─── NEW: FINANCE REPORTS ───────────────────────────────────────

    def profit_loss(self, start_date: date, end_date: date) -> dict:
        summary = self.db.query(
            func.coalesce(func.sum(DailyFinancialSummary.revenue), 0).label("revenue"),
            func.coalesce(func.sum(DailyFinancialSummary.cogs), 0).label("cogs"),
            func.coalesce(func.sum(DailyFinancialSummary.gross_profit), 0).label("gross_profit"),
            func.coalesce(func.sum(DailyFinancialSummary.expenses), 0).label("expenses"),
            func.coalesce(func.sum(DailyFinancialSummary.net_profit), 0).label("net_profit"),
        ).filter(
            DailyFinancialSummary.summary_date >= start_date,
            DailyFinancialSummary.summary_date <= end_date,
        ).first()

        revenue = float(summary.revenue)
        cogs = float(summary.cogs)
        gross_profit = float(summary.gross_profit)
        expenses = float(summary.expenses)
        net_profit = float(summary.net_profit)
        gross_margin = round((gross_profit / revenue * 100), 2) if revenue > 0 else 0
        net_margin = round((net_profit / revenue * 100), 2) if revenue > 0 else 0

        expense_breakdown = self.db.query(
            Expense.expense_category,
            func.sum(Expense.amount).label("total"),
        ).filter(
            func.date(Expense.expense_date) >= start_date,
            func.date(Expense.expense_date) <= end_date,
        ).group_by(Expense.expense_category
        ).order_by(func.sum(Expense.amount).desc()).all()

        return {
            "period": {"start": str(start_date), "end": str(end_date)},
            "revenue": str(revenue),
            "cogs": str(cogs),
            "gross_profit": str(gross_profit),
            "gross_margin_pct": str(gross_margin),
            "total_expenses": str(expenses),
            "net_profit": str(net_profit),
            "net_margin_pct": str(net_margin),
            "expense_breakdown": [
                {"category": r.expense_category, "total": str(r.total)}
                for r in expense_breakdown
            ],
        }

    def expense_by_category(self, start_date: date, end_date: date) -> dict:
        results = self.db.query(
            Expense.expense_category,
            func.count(Expense.expense_id).label("count"),
            func.sum(Expense.amount).label("total_amount"),
            func.avg(Expense.amount).label("avg_amount"),
        ).filter(
            func.date(Expense.expense_date) >= start_date,
            func.date(Expense.expense_date) <= end_date,
        ).group_by(Expense.expense_category
        ).order_by(func.sum(Expense.amount).desc()).all()

        grand_total = sum(float(r.total_amount) for r in results)
        categories = []
        for r in results:
            total = float(r.total_amount)
            pct = round((total / grand_total * 100), 2) if grand_total > 0 else 0
            categories.append({
                "category": r.expense_category,
                "count": r.count,
                "total_amount": str(r.total_amount),
                "avg_amount": str(round(float(r.avg_amount), 2)),
                "percentage": str(pct),
            })

        daily_trend = self.db.query(
            func.date(Expense.expense_date).label("day"),
            func.sum(Expense.amount).label("total"),
        ).filter(
            func.date(Expense.expense_date) >= start_date,
            func.date(Expense.expense_date) <= end_date,
        ).group_by(func.date(Expense.expense_date)
        ).order_by(func.date(Expense.expense_date)).all()

        return {
            "period": {"start": str(start_date), "end": str(end_date)},
            "grand_total": str(grand_total),
            "category_count": len(categories),
            "categories": categories,
            "daily_trend": [
                {"date": str(r.day), "total": str(r.total)}
                for r in daily_trend
            ],
        }

    # ─── NEW: CUSTOMER REPORTS ──────────────────────────────────────

    def customer_profile(self, customer_id: int) -> dict:
        customer = self.db.query(Customer).filter(
            Customer.customer_id == customer_id
        ).first()
        if not customer:
            return {"error": "Customer not found"}

        total_purchases = self.db.query(
            func.coalesce(func.sum(SalesInvoice.total_amount), 0)
        ).filter(SalesInvoice.customer_id == customer_id).scalar()

        invoice_count = self.db.query(
            func.count(SalesInvoice.invoice_id)
        ).filter(SalesInvoice.customer_id == customer_id).scalar()

        last_invoice = self.db.query(SalesInvoice).filter(
            SalesInvoice.customer_id == customer_id
        ).order_by(SalesInvoice.invoice_date.desc()).first()

        total_paid = self.db.query(
            func.coalesce(func.sum(SalesInvoice.paid_amount), 0)
        ).filter(SalesInvoice.customer_id == customer_id).scalar()

        return {
            "customer_id": customer.customer_id,
            "customer_name": customer.customer_name,
            "phone_number": customer.phone_number,
            "address": customer.address,
            "current_balance": str(customer.current_balance),
            "credit_limit": str(customer.credit_limit),
            "total_purchases": str(total_purchases),
            "total_paid": str(total_paid),
            "invoice_count": invoice_count,
            "last_transaction": str(last_invoice.invoice_date) if last_invoice else None,
            "avg_invoice_value": str(round(float(total_purchases) / invoice_count, 2)) if invoice_count > 0 else "0",
            "member_since": str(customer.created_date) if customer.created_date else None,
        }

    def customer_activity(self, customer_id: int, limit: int = 50) -> dict:
        invoices = self.db.query(SalesInvoice).filter(
            SalesInvoice.customer_id == customer_id
        ).order_by(SalesInvoice.invoice_date.desc()).limit(limit).all()

        payments = self.db.query(CashTransaction).filter(
            CashTransaction.entity_type == "customer",
            CashTransaction.entity_id == customer_id,
        ).order_by(CashTransaction.transaction_date.desc()).limit(limit).all()

        invoice_items = [
            {
                "type": "invoice",
                "date": str(inv.invoice_date),
                "reference": inv.invoice_number,
                "amount": str(inv.total_amount),
                "status": inv.payment_status,
            }
            for inv in invoices
        ]

        payment_items = [
            {
                "type": "payment",
                "date": str(p.transaction_date),
                "reference": p.reference_number or "",
                "amount": str(p.amount),
                "status": "completed",
            }
            for p in payments
        ]

        all_activity = sorted(
            invoice_items + payment_items,
            key=lambda x: x["date"],
            reverse=True,
        )

        return {
            "customer_id": customer_id,
            "total_invoices": len(invoice_items),
            "total_payments": len(payment_items),
            "activity": all_activity[:limit],
        }

    def customer_segmentation(self) -> dict:
        all_customers = self.db.query(Customer).all()

        thirty_days_ago = date.today() - timedelta(days=30)
        active_ids = set(
            r[0] for r in self.db.query(SalesInvoice.customer_id).filter(
                func.date(SalesInvoice.invoice_date) >= thirty_days_ago,
                SalesInvoice.customer_id.isnot(None),
            ).distinct().all()
        )

        ninety_days_ago = date.today() - timedelta(days=90)
        recent_ids = set(
            r[0] for r in self.db.query(SalesInvoice.customer_id).filter(
                func.date(SalesInvoice.invoice_date) >= ninety_days_ago,
                SalesInvoice.customer_id.isnot(None),
            ).distinct().all()
        )

        top_spenders = self.db.query(
            SalesInvoice.customer_id,
            func.sum(SalesInvoice.total_amount).label("total"),
        ).filter(
            SalesInvoice.customer_id.isnot(None),
        ).group_by(SalesInvoice.customer_id
        ).order_by(func.sum(SalesInvoice.total_amount).desc()).limit(10).all()
        vip_ids = set(r[0] for r in top_spenders)

        vip = []
        active = []
        inactive = []
        high_debt = []

        for c in all_customers:
            entry = {
                "customer_id": c.customer_id,
                "customer_name": c.customer_name,
                "current_balance": str(c.current_balance),
                "credit_limit": str(c.credit_limit),
            }
            if c.current_balance > 0 and (c.credit_limit == 0 or c.current_balance >= c.credit_limit * Decimal("0.8")):
                high_debt.append(entry)
            if c.customer_id in vip_ids:
                total = next((float(r.total) for r in top_spenders if r[0] == c.customer_id), 0)
                entry["total_purchases"] = str(total)
                vip.append(entry)
            if c.customer_id in active_ids:
                active.append(entry)
            elif c.customer_id not in recent_ids:
                inactive.append(entry)

        return {
            "total_customers": len(all_customers),
            "vip_customers": {"count": len(vip), "customers": vip},
            "active_customers": {"count": len(active), "customers": active},
            "inactive_customers": {"count": len(inactive), "customers": inactive},
            "high_debt_customers": {"count": len(high_debt), "customers": high_debt},
        }
