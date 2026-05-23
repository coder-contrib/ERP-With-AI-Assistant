from pydantic import BaseModel
from decimal import Decimal
from datetime import date


class DateRangeParams(BaseModel):
    start_date: date
    end_date: date


class DailySalesReport(BaseModel):
    date: str
    invoice_count: int
    total_sales: Decimal
    total_discount: Decimal
    cash_collected: Decimal
    credit_sales: Decimal


class MonthlyProfitReport(BaseModel):
    month: str
    revenue: Decimal
    cogs: Decimal
    gross_profit: Decimal
    gross_margin: Decimal
    expenses: Decimal
    net_profit: Decimal


class TopProductItem(BaseModel):
    product_id: int
    product_name: str
    total_quantity: Decimal
    total_revenue: Decimal


class CustomerBalanceItem(BaseModel):
    customer_id: int
    customer_name: str
    current_balance: Decimal
    credit_limit: Decimal


class SupplierBalanceItem(BaseModel):
    supplier_id: int
    supplier_name: str
    current_balance: Decimal
    payment_terms: int


class CashFlowItem(BaseModel):
    date: str
    cash_in: Decimal
    cash_out: Decimal
    net: Decimal


class WasteReportItem(BaseModel):
    product_id: int
    product_name: str
    warehouse_id: int
    total_quantity: Decimal
    total_value: Decimal
    waste_reason: str | None


class WarehouseStockItem(BaseModel):
    product_id: int
    product_name: str
    quantity: Decimal
    avg_cost: Decimal
    total_value: Decimal
