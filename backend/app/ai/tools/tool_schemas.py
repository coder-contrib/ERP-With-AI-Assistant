"""Tool schemas for the Manager Agent.
These define WHAT tools exist (for Claude to plan with).
Execution is handled separately by ToolExecutor.
"""

TOOL_SCHEMAS = [
    # ─── Read: Sales ──────────────────────────────────────────────────
    {
        "name": "get_today_sales",
        "description": "Get today's sales summary including invoice count, total amount, and cash collected",
        "input_schema": {"type": "object", "properties": {}, "required": []},
    },
    {
        "name": "get_customer_info",
        "description": "Get customer details including name, balance, credit limit, and payment terms",
        "input_schema": {"type": "object", "properties": {"customer_id": {"type": "integer"}}, "required": ["customer_id"]},
    },
    {
        "name": "get_customer_history",
        "description": "Get recent purchase history for a customer",
        "input_schema": {"type": "object", "properties": {"customer_id": {"type": "integer"}, "limit": {"type": "integer", "default": 10}}, "required": ["customer_id"]},
    },
    {
        "name": "get_top_selling_products",
        "description": "Get top selling products by revenue or quantity",
        "input_schema": {"type": "object", "properties": {"limit": {"type": "integer", "default": 10}, "by": {"type": "string", "enum": ["quantity", "revenue"], "default": "revenue"}}, "required": []},
    },
    {
        "name": "get_unpaid_invoices",
        "description": "Get list of unpaid or partially paid invoices",
        "input_schema": {"type": "object", "properties": {"customer_id": {"type": "integer", "description": "Optional filter by customer"}}, "required": []},
    },
    # ─── Read: Inventory ───────────────────────────────────────────────
    {
        "name": "get_stock_level",
        "description": "Get current stock level for a product across warehouses",
        "input_schema": {"type": "object", "properties": {"product_id": {"type": "integer"}, "warehouse_id": {"type": "integer", "description": "Optional warehouse filter"}}, "required": ["product_id"]},
    },
    {
        "name": "get_low_stock_items",
        "description": "Get products with stock below a threshold",
        "input_schema": {"type": "object", "properties": {"threshold": {"type": "number", "default": 10}}, "required": []},
    },
    {
        "name": "get_stock_movement_history",
        "description": "Get recent stock movements for a product",
        "input_schema": {"type": "object", "properties": {"product_id": {"type": "integer"}, "limit": {"type": "integer", "default": 20}}, "required": ["product_id"]},
    },
    {
        "name": "get_warehouse_summary",
        "description": "Get stock summary for a warehouse",
        "input_schema": {"type": "object", "properties": {"warehouse_id": {"type": "integer"}}, "required": ["warehouse_id"]},
    },
    {
        "name": "get_dead_stock",
        "description": "Get products with no movement in X days",
        "input_schema": {"type": "object", "properties": {"days": {"type": "integer", "default": 30}}, "required": []},
    },
    {
        "name": "get_stock_valuation",
        "description": "Get inventory valuation by warehouse",
        "input_schema": {"type": "object", "properties": {"warehouse_id": {"type": "integer"}}, "required": []},
    },
    # ─── Read: Finance ─────────────────────────────────────────────────
    {
        "name": "get_profit_and_loss",
        "description": "Get profit and loss report for a date range",
        "input_schema": {"type": "object", "properties": {"start_date": {"type": "string", "description": "YYYY-MM-DD"}, "end_date": {"type": "string", "description": "YYYY-MM-DD"}}, "required": ["start_date", "end_date"]},
    },
    {
        "name": "get_cash_balance",
        "description": "Get current cash balance",
        "input_schema": {"type": "object", "properties": {}, "required": []},
    },
    {
        "name": "get_receivables_summary",
        "description": "Get accounts receivable summary with top debtors",
        "input_schema": {"type": "object", "properties": {}, "required": []},
    },
    {
        "name": "get_payables_summary",
        "description": "Get accounts payable summary with top creditors",
        "input_schema": {"type": "object", "properties": {}, "required": []},
    },
    {
        "name": "get_expense_breakdown",
        "description": "Get expenses grouped by category for a period",
        "input_schema": {"type": "object", "properties": {"start_date": {"type": "string"}, "end_date": {"type": "string"}}, "required": ["start_date", "end_date"]},
    },
    {
        "name": "get_daily_revenue",
        "description": "Get daily revenue trend for a period",
        "input_schema": {"type": "object", "properties": {"start_date": {"type": "string"}, "end_date": {"type": "string"}}, "required": ["start_date", "end_date"]},
    },
    {
        "name": "demand_forecast",
        "description": "Predict demand and days until stockout for a product",
        "input_schema": {"type": "object", "properties": {"product_id": {"type": "integer"}, "days_back": {"type": "integer", "default": 30}}, "required": ["product_id"]},
    },
    # ─── Read: Search ───────────────────────────────────────────────────
    {
        "name": "search_products",
        "description": "Search products by name",
        "input_schema": {"type": "object", "properties": {"query": {"type": "string"}}, "required": ["query"]},
    },
    {
        "name": "search_customers",
        "description": "Search customers by name",
        "input_schema": {"type": "object", "properties": {"query": {"type": "string"}}, "required": ["query"]},
    },
    # ─── Write: Sales ──────────────────────────────────────────────────
    {
        "name": "create_invoice",
        "description": "Create a new sales invoice. Validates stock, deducts inventory, creates ledger entries, records payment.",
        "input_schema": {
            "type": "object",
            "properties": {
                "customer_id": {"type": "integer", "description": "Customer ID (null for walk-in)"},
                "items": {
                    "type": "array",
                    "description": "Items to sell",
                    "items": {
                        "type": "object",
                        "properties": {
                            "product_id": {"type": "integer"},
                            "quantity": {"type": "number"},
                            "unit_price": {"type": "number"},
                            "unit_type": {"type": "string", "default": "meter"},
                            "discount": {"type": "number", "default": 0},
                        },
                        "required": ["product_id", "quantity"],
                    },
                },
                "payment_type": {"type": "string", "enum": ["cash", "credit", "mixed"], "default": "cash"},
                "warehouse_id": {"type": "integer", "default": 1},
                "discount": {"type": "number", "default": 0},
                "paid_amount": {"type": "number"},
                "notes": {"type": "string"},
            },
            "required": ["items"],
        },
    },
    {
        "name": "cancel_invoice",
        "description": "Cancel a sales invoice. Restores stock, reverses cash, updates customer balance.",
        "input_schema": {
            "type": "object",
            "properties": {
                "invoice_id": {"type": "integer"},
                "reason": {"type": "string"},
            },
            "required": ["invoice_id"],
        },
    },
    {
        "name": "apply_discount",
        "description": "Apply or change discount on an existing invoice.",
        "input_schema": {
            "type": "object",
            "properties": {
                "invoice_id": {"type": "integer"},
                "discount_amount": {"type": "number"},
            },
            "required": ["invoice_id", "discount_amount"],
        },
    },
    # ─── Write: Payments ───────────────────────────────────────────────
    {
        "name": "record_payment",
        "description": "Record a customer payment against an invoice.",
        "input_schema": {
            "type": "object",
            "properties": {
                "customer_id": {"type": "integer"},
                "invoice_id": {"type": "integer"},
                "amount": {"type": "number"},
                "notes": {"type": "string"},
            },
            "required": ["customer_id", "invoice_id", "amount"],
        },
    },
    {
        "name": "refund_payment",
        "description": "Refund money to customer for an invoice.",
        "input_schema": {
            "type": "object",
            "properties": {
                "invoice_id": {"type": "integer"},
                "amount": {"type": "number"},
                "reason": {"type": "string"},
            },
            "required": ["invoice_id", "amount"],
        },
    },
    # ─── Write: Inventory ───────────────────────────────────────────────
    {
        "name": "update_stock",
        "description": "Add stock (receive goods) for a product in a warehouse.",
        "input_schema": {
            "type": "object",
            "properties": {
                "product_id": {"type": "integer"},
                "warehouse_id": {"type": "integer"},
                "quantity": {"type": "number"},
                "cost_per_unit": {"type": "number", "default": 0},
                "notes": {"type": "string"},
            },
            "required": ["product_id", "warehouse_id", "quantity"],
        },
    },
    {
        "name": "transfer_stock",
        "description": "Transfer stock between warehouses.",
        "input_schema": {
            "type": "object",
            "properties": {
                "product_id": {"type": "integer"},
                "from_warehouse_id": {"type": "integer"},
                "to_warehouse_id": {"type": "integer"},
                "quantity": {"type": "number"},
                "notes": {"type": "string"},
            },
            "required": ["product_id", "from_warehouse_id", "to_warehouse_id", "quantity"],
        },
    },
    {
        "name": "adjust_stock",
        "description": "Set stock to a specific quantity (manual correction).",
        "input_schema": {
            "type": "object",
            "properties": {
                "product_id": {"type": "integer"},
                "warehouse_id": {"type": "integer"},
                "new_quantity": {"type": "number"},
                "reason": {"type": "string"},
            },
            "required": ["product_id", "warehouse_id", "new_quantity"],
        },
    },
    # ─── Write: CRM ────────────────────────────────────────────────────
    {
        "name": "create_customer",
        "description": "Create a new customer record.",
        "input_schema": {
            "type": "object",
            "properties": {
                "name": {"type": "string"},
                "phone": {"type": "string"},
                "address": {"type": "string"},
                "credit_limit": {"type": "number", "default": 0},
                "payment_terms": {"type": "integer", "default": 0},
                "notes": {"type": "string"},
            },
            "required": ["name"],
        },
    },
    {
        "name": "update_customer",
        "description": "Update an existing customer's information.",
        "input_schema": {
            "type": "object",
            "properties": {
                "customer_id": {"type": "integer"},
                "name": {"type": "string"},
                "phone": {"type": "string"},
                "address": {"type": "string"},
                "credit_limit": {"type": "number"},
                "payment_terms": {"type": "integer"},
                "notes": {"type": "string"},
            },
            "required": ["customer_id"],
        },
    },
]
