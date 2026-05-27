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
    # ═══ EXTENDED TOOLS — Opening Balances ═══
    {
        "name": "set_customer_opening_balance",
        "description": "Set the opening balance for a customer. Used for initial account setup.",
        "input_schema": {
            "type": "object",
            "properties": {
                "customer_id": {"type": "integer"},
                "amount": {"type": "number"},
                "balance_type": {"type": "string", "enum": ["debit", "credit"], "default": "debit"},
                "notes": {"type": "string"},
            },
            "required": ["customer_id", "amount"],
        },
    },
    {
        "name": "set_supplier_opening_balance",
        "description": "Set the opening balance for a supplier. Used for initial account setup.",
        "input_schema": {
            "type": "object",
            "properties": {
                "supplier_id": {"type": "integer"},
                "amount": {"type": "number"},
                "balance_type": {"type": "string", "enum": ["debit", "credit"], "default": "credit"},
                "notes": {"type": "string"},
            },
            "required": ["supplier_id", "amount"],
        },
    },
    {
        "name": "set_cash_opening_balance",
        "description": "Set the opening cash balance. Used for initial setup.",
        "input_schema": {
            "type": "object",
            "properties": {
                "amount": {"type": "number"},
                "account_name": {"type": "string", "default": "الصندوق الرئيسي"},
                "notes": {"type": "string"},
            },
            "required": ["amount"],
        },
    },
    {
        "name": "set_opening_inventory",
        "description": "Set the opening inventory for a product in a warehouse. Sets initial stock quantity and cost.",
        "input_schema": {
            "type": "object",
            "properties": {
                "product_id": {"type": "integer"},
                "warehouse_id": {"type": "integer"},
                "quantity": {"type": "number"},
                "cost_per_unit": {"type": "number"},
                "notes": {"type": "string"},
            },
            "required": ["product_id", "warehouse_id", "quantity", "cost_per_unit"],
        },
    },
    {
        "name": "get_opening_balances",
        "description": "Get all opening balances. Optionally filter by entity type.",
        "input_schema": {
            "type": "object",
            "properties": {
                "entity_type": {"type": "string", "enum": ["customer", "supplier", "cash", "inventory"]},
            },
            "required": [],
        },
    },
    # ═══ EXTENDED TOOLS — Expenses ═══
    {
        "name": "create_expense",
        "description": "Create a new expense record. Deducts from cash balance.",
        "input_schema": {
            "type": "object",
            "properties": {
                "name": {"type": "string"},
                "amount": {"type": "number"},
                "category": {"type": "string", "default": "Miscellaneous"},
                "notes": {"type": "string"},
                "expense_date": {"type": "string"},
            },
            "required": ["name", "amount"],
        },
    },
    {
        "name": "list_expenses",
        "description": "List expenses with optional filters by date range, category, or search term.",
        "input_schema": {
            "type": "object",
            "properties": {
                "date_from": {"type": "string"},
                "date_to": {"type": "string"},
                "category": {"type": "string"},
                "search": {"type": "string"},
                "limit": {"type": "integer", "default": 20},
            },
            "required": [],
        },
    },
    {
        "name": "get_expense_summary",
        "description": "Get expense summary: total today, total this month, highest spending category.",
        "input_schema": {"type": "object", "properties": {}, "required": []},
    },
    # ═══ EXTENDED TOOLS — Sales Invoice Retrieval ═══
    {
        "name": "list_sales_invoices",
        "description": "List recent sales invoices with optional status filter.",
        "input_schema": {
            "type": "object",
            "properties": {
                "limit": {"type": "integer", "default": 20},
                "status": {"type": "string", "enum": ["paid", "unpaid", "partial"]},
            },
            "required": [],
        },
    },
    {
        "name": "get_sales_invoice",
        "description": "Get full details of a specific sales invoice.",
        "input_schema": {
            "type": "object",
            "properties": {"invoice_id": {"type": "integer"}},
            "required": ["invoice_id"],
        },
    },
    {
        "name": "get_invoice_items",
        "description": "Get all line items within a specific sales invoice.",
        "input_schema": {
            "type": "object",
            "properties": {"invoice_id": {"type": "integer"}},
            "required": ["invoice_id"],
        },
    },
    {
        "name": "create_sales_return",
        "description": "Create a sales return for items from a sales invoice.",
        "input_schema": {
            "type": "object",
            "properties": {
                "invoice_id": {"type": "integer"},
                "items": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "product_id": {"type": "integer"},
                            "quantity": {"type": "number"},
                            "return_price": {"type": "number"},
                        },
                        "required": ["product_id", "quantity"],
                    },
                },
                "reason": {"type": "string"},
            },
            "required": ["invoice_id", "items"],
        },
    },
    # ═══ EXTENDED TOOLS — Purchase Invoices ═══
    {
        "name": "list_purchase_invoices",
        "description": "List recent purchase invoices from suppliers.",
        "input_schema": {
            "type": "object",
            "properties": {"limit": {"type": "integer", "default": 20}},
            "required": [],
        },
    },
    {
        "name": "get_purchase_invoice",
        "description": "Get full details of a specific purchase invoice.",
        "input_schema": {
            "type": "object",
            "properties": {"purchase_invoice_id": {"type": "integer"}},
            "required": ["purchase_invoice_id"],
        },
    },
    {
        "name": "get_purchase_items",
        "description": "Get all line items within a specific purchase invoice.",
        "input_schema": {
            "type": "object",
            "properties": {"purchase_invoice_id": {"type": "integer"}},
            "required": ["purchase_invoice_id"],
        },
    },
    {
        "name": "create_purchase_invoice",
        "description": "Create a new purchase invoice. Adds stock to inventory.",
        "input_schema": {
            "type": "object",
            "properties": {
                "supplier_id": {"type": "integer"},
                "items": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "product_id": {"type": "integer"},
                            "quantity": {"type": "number"},
                            "purchase_price": {"type": "number"},
                        },
                        "required": ["product_id", "quantity", "purchase_price"],
                    },
                },
                "payment_type": {"type": "string", "enum": ["cash", "credit", "mixed"], "default": "cash"},
                "paid_amount": {"type": "number"},
                "warehouse_id": {"type": "integer", "default": 1},
                "notes": {"type": "string"},
            },
            "required": ["supplier_id", "items"],
        },
    },
    {
        "name": "create_purchase_return",
        "description": "Create a purchase return for items from a purchase invoice.",
        "input_schema": {
            "type": "object",
            "properties": {
                "purchase_invoice_id": {"type": "integer"},
                "items": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "product_id": {"type": "integer"},
                            "quantity": {"type": "number"},
                            "return_price": {"type": "number"},
                        },
                        "required": ["product_id", "quantity"],
                    },
                },
                "reason": {"type": "string"},
            },
            "required": ["purchase_invoice_id", "items"],
        },
    },
    # ═══ EXTENDED TOOLS — Suppliers ═══
    {
        "name": "create_supplier",
        "description": "Create a new supplier.",
        "input_schema": {
            "type": "object",
            "properties": {
                "name": {"type": "string"},
                "phone": {"type": "string"},
                "address": {"type": "string"},
                "notes": {"type": "string"},
            },
            "required": ["name"],
        },
    },
    {
        "name": "update_supplier",
        "description": "Update an existing supplier's information.",
        "input_schema": {
            "type": "object",
            "properties": {
                "supplier_id": {"type": "integer"},
                "name": {"type": "string"},
                "phone": {"type": "string"},
                "address": {"type": "string"},
                "notes": {"type": "string"},
            },
            "required": ["supplier_id"],
        },
    },
    {
        "name": "search_suppliers",
        "description": "Search suppliers by name or phone number.",
        "input_schema": {
            "type": "object",
            "properties": {
                "query": {"type": "string"},
                "limit": {"type": "integer", "default": 10},
            },
            "required": ["query"],
        },
    },
    # ═══ EXTENDED TOOLS — Products ═══
    {
        "name": "create_product",
        "description": "Create a new product in the system.",
        "input_schema": {
            "type": "object",
            "properties": {
                "name": {"type": "string"},
                "sku": {"type": "string"},
                "category_id": {"type": "integer"},
                "selling_price": {"type": "number", "default": 0},
                "cost_price": {"type": "number", "default": 0},
                "base_unit": {"type": "string", "default": "meter"},
                "barcode": {"type": "string"},
                "notes": {"type": "string"},
            },
            "required": ["name"],
        },
    },
    {
        "name": "update_product",
        "description": "Update an existing product's information.",
        "input_schema": {
            "type": "object",
            "properties": {
                "product_id": {"type": "integer"},
                "name": {"type": "string"},
                "selling_price": {"type": "number"},
                "cost_price": {"type": "number"},
                "category_id": {"type": "integer"},
                "base_unit": {"type": "string"},
                "barcode": {"type": "string"},
                "notes": {"type": "string"},
            },
            "required": ["product_id"],
        },
    },
    {
        "name": "get_product",
        "description": "Get detailed product information including stock levels across all warehouses.",
        "input_schema": {
            "type": "object",
            "properties": {"product_id": {"type": "integer"}},
            "required": ["product_id"],
        },
    },
]
