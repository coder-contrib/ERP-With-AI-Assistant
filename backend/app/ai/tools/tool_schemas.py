"""Tool schemas for the Manager Agent.
These define WHAT tools exist (for Claude to plan with).
Execution is handled separately by ToolExecutor.
"""

TOOL_SCHEMAS = [
    # ─── Read: Sales ─────────────────────────────────────────────────────────────
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
    # ─── Read: Inventory ───────────────────────────────────────────────────────────
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
    # ─── Read: Finance ─────────────────────────────────────────────────────────────
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
    # ─── Read: Search ───────────────────────────────────────────────────────────────
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
    # ─── Write: Sales ──────────────────────────────────────────────────────────────
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
    # ─── Write: Payments ───────────────────────────────────────────────────────────
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
    # ─── Write: Inventory ───────────────────────────────────────────────────────────
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
    # ─── Write: CRM ────────────────────────────────────────────────────────────────
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
    # ═══ ADMIN TOOLS — Categories ═══
    {
        "name": "list_categories",
        "description": "List all product categories.",
        "input_schema": {"type": "object", "properties": {}, "required": []},
    },
    {
        "name": "create_category",
        "description": "Create a new product category.",
        "input_schema": {
            "type": "object",
            "properties": {
                "name": {"type": "string"},
                "description": {"type": "string"},
            },
            "required": ["name"],
        },
    },
    {
        "name": "update_category",
        "description": "Update an existing product category's name or description.",
        "input_schema": {
            "type": "object",
            "properties": {
                "category_id": {"type": "integer"},
                "name": {"type": "string"},
                "description": {"type": "string"},
            },
            "required": ["category_id"],
        },
    },
    {
        "name": "delete_category",
        "description": "Delete a product category.",
        "input_schema": {
            "type": "object",
            "properties": {"category_id": {"type": "integer"}},
            "required": ["category_id"],
        },
    },
    # ═══ ADMIN TOOLS — Reports ═══
    {
        "name": "get_monthly_profit",
        "description": "Get monthly profit/loss breakdown for a year. Shows revenue, COGS, gross profit, expenses, net profit per month.",
        "input_schema": {
            "type": "object",
            "properties": {"year": {"type": "integer", "description": "Year (defaults to current year)"}},
            "required": [],
        },
    },
    {
        "name": "get_cash_flow",
        "description": "Get cash flow report showing daily cash in/out and net flow for a date range.",
        "input_schema": {
            "type": "object",
            "properties": {
                "start_date": {"type": "string", "description": "YYYY-MM-DD"},
                "end_date": {"type": "string", "description": "YYYY-MM-DD"},
            },
            "required": ["start_date", "end_date"],
        },
    },
    {
        "name": "get_waste_report",
        "description": "Get waste/spoilage report showing damaged or lost products for a date range.",
        "input_schema": {
            "type": "object",
            "properties": {
                "start_date": {"type": "string", "description": "YYYY-MM-DD (defaults to 30 days ago)"},
                "end_date": {"type": "string", "description": "YYYY-MM-DD (defaults to today)"},
            },
            "required": [],
        },
    },
    # ═══ ADMIN TOOLS — Notifications ═══
    {
        "name": "get_notifications",
        "description": "Get system notifications (low stock alerts, credit limit warnings, overdue payments).",
        "input_schema": {
            "type": "object",
            "properties": {
                "unread_only": {"type": "boolean", "default": False},
                "limit": {"type": "integer", "default": 50},
            },
            "required": [],
        },
    },
    {
        "name": "mark_notification_read",
        "description": "Mark a specific notification as read.",
        "input_schema": {
            "type": "object",
            "properties": {"notification_id": {"type": "integer"}},
            "required": ["notification_id"],
        },
    },
    {
        "name": "mark_all_notifications_read",
        "description": "Mark all notifications as read.",
        "input_schema": {"type": "object", "properties": {}, "required": []},
    },
    # ═══ ADMIN TOOLS — Alerts ═══
    {
        "name": "check_low_stock_alerts",
        "description": "Scan inventory and generate low stock alerts for products below threshold.",
        "input_schema": {
            "type": "object",
            "properties": {"threshold": {"type": "number", "default": 10.0}},
            "required": [],
        },
    },
    {
        "name": "check_credit_limit_alerts",
        "description": "Check all customers and generate alerts for those who exceeded their credit limit.",
        "input_schema": {"type": "object", "properties": {}, "required": []},
    },
    {
        "name": "check_overdue_supplier_alerts",
        "description": "Check for overdue supplier payments and generate alerts.",
        "input_schema": {"type": "object", "properties": {}, "required": []},
    },
    # ═══ ADMIN TOOLS — Anomaly Detection ═══
    {
        "name": "scan_anomalies",
        "description": "Run full anomaly scan across revenue, expenses, and profit using z-scores and rolling averages.",
        "input_schema": {"type": "object", "properties": {}, "required": []},
    },
    {
        "name": "detect_revenue_anomaly",
        "description": "Check if revenue for a specific date is anomalous compared to historical baselines.",
        "input_schema": {
            "type": "object",
            "properties": {"target_date": {"type": "string", "description": "YYYY-MM-DD (defaults to today)"}},
            "required": [],
        },
    },
    {
        "name": "detect_expense_anomaly",
        "description": "Check if expenses for a specific date are anomalous compared to historical baselines.",
        "input_schema": {
            "type": "object",
            "properties": {"target_date": {"type": "string", "description": "YYYY-MM-DD (defaults to today)"}},
            "required": [],
        },
    },
    # ═══ ADMIN TOOLS — Business Insights ═══
    {
        "name": "get_business_insights",
        "description": "Get AI-powered business insights: risks, opportunities, and anomalies with severity levels.",
        "input_schema": {"type": "object", "properties": {}, "required": []},
    },
    {
        "name": "why_profit_dropped",
        "description": "Detailed analysis of why profit dropped: compares periods, identifies causes, gives recommendations.",
        "input_schema": {"type": "object", "properties": {}, "required": []},
    },
    {
        "name": "get_top_risks",
        "description": "Get top business risks (stock risks, credit risks, anomalies) sorted by severity.",
        "input_schema": {
            "type": "object",
            "properties": {"limit": {"type": "integer", "default": 5}},
            "required": [],
        },
    },
    # ═══ ADMIN TOOLS — Dashboard ═══
    {
        "name": "get_dashboard_summary",
        "description": "Get full dashboard summary: today's sales/purchases/expenses, monthly revenue/profit, cash balance, receivables, payables, low stock count.",
        "input_schema": {"type": "object", "properties": {}, "required": []},
    },
    # ═══ ADMIN TOOLS — Accounting Tasks ═══
    {
        "name": "refresh_daily_summary",
        "description": "Refresh the daily financial summary (recalculate revenue, COGS, profit for a date).",
        "input_schema": {
            "type": "object",
            "properties": {"target_date": {"type": "string", "description": "YYYY-MM-DD (defaults to today)"}},
            "required": [],
        },
    },
    {
        "name": "refresh_summary_range",
        "description": "Refresh financial summaries for a date range.",
        "input_schema": {
            "type": "object",
            "properties": {
                "start_date": {"type": "string", "description": "YYYY-MM-DD"},
                "end_date": {"type": "string", "description": "YYYY-MM-DD (defaults to today)"},
            },
            "required": ["start_date"],
        },
    },
    # ═══ ADMIN TOOLS — User Management ═══
    {
        "name": "list_users",
        "description": "List all system users with their roles and active status.",
        "input_schema": {"type": "object", "properties": {}, "required": []},
    },
    {
        "name": "create_user",
        "description": "Create a new system user with a role.",
        "input_schema": {
            "type": "object",
            "properties": {
                "full_name": {"type": "string"},
                "username": {"type": "string"},
                "password": {"type": "string"},
                "role": {"type": "string", "enum": ["admin", "manager", "cashier", "warehouse_employee", "accountant"]},
            },
            "required": ["full_name", "username", "password", "role"],
        },
    },
    {
        "name": "deactivate_user",
        "description": "Deactivate a user account (prevents login).",
        "input_schema": {
            "type": "object",
            "properties": {"user_id": {"type": "integer"}},
            "required": ["user_id"],
        },
    },
    {
        "name": "activate_user",
        "description": "Reactivate a previously deactivated user account.",
        "input_schema": {
            "type": "object",
            "properties": {"user_id": {"type": "integer"}},
            "required": ["user_id"],
        },
    },
    {
        "name": "reset_user_password",
        "description": "Reset a user's password to default (123456). They should change it on next login.",
        "input_schema": {
            "type": "object",
            "properties": {"user_id": {"type": "integer"}},
            "required": ["user_id"],
        },
    },
    # ═══ ADMIN TOOLS — Ledger ═══
    {
        "name": "get_ledger_entries",
        "description": "Get journal/ledger entries. Can filter by entity type (sales_invoice, purchase_invoice, expense, etc.) and entity ID.",
        "input_schema": {
            "type": "object",
            "properties": {
                "entity_type": {"type": "string", "description": "Filter by type: sales_invoice, purchase_invoice, customer_payment, supplier_payment, expense, sales_return, purchase_return"},
                "entity_id": {"type": "integer", "description": "Filter by specific entity ID"},
                "limit": {"type": "integer", "default": 50},
            },
            "required": [],
        },
    },
    {
        "name": "get_account_balance",
        "description": "Get the total debit, credit, and net balance for a specific ledger account (1=cash, 2=receivables, 3=inventory, 4=payables, 5=equity, 6=revenue, 7=sales_returns, 8=cogs, 9=purchase_returns, 10=expenses).",
        "input_schema": {
            "type": "object",
            "properties": {"account_id": {"type": "integer"}},
            "required": ["account_id"],
        },
    },
    {
        "name": "get_trial_balance",
        "description": "Get the full trial balance showing all accounts with their debit/credit totals. Verifies if books are balanced.",
        "input_schema": {"type": "object", "properties": {}, "required": []},
    },
    # ═══ WHATSAPP TOOLS ═══
    {
        "name": "send_whatsapp_message",
        "description": "Send a WhatsApp message to a phone number. Use for individual notifications or one-off communications.",
        "input_schema": {
            "type": "object",
            "properties": {
                "to": {"type": "string", "description": "Phone number in international format (e.g., 201234567890)"},
                "message": {"type": "string", "description": "Message text to send"},
            },
            "required": ["to", "message"],
        },
    },
    {
        "name": "send_overdue_reminders",
        "description": "Send bulk WhatsApp reminders to all customers with overdue payments (older than 7 days). REQUIRES CONFIRMATION as this is a bulk operation.",
        "input_schema": {"type": "object", "properties": {}, "required": []},
    },
    {
        "name": "send_daily_sales_report",
        "description": "Send today's sales summary report via WhatsApp to a specified phone number. Includes invoice count, revenue, cash collected, expenses, and net profit.",
        "input_schema": {
            "type": "object",
            "properties": {
                "to": {"type": "string", "description": "Phone number in international format (e.g., 201234567890)"},
            },
            "required": ["to"],
        },
    },
    {
        "name": "send_report_to_owner",
        "description": "Send any report to the owner's WhatsApp number. Supports: daily_operations, daily_sales, monthly_profit, top_products, low_stock, cash_flow, customer_balances, supplier_balances, profit_loss, expense_by_category, inventory_valuation, dead_stock, stock_movement. The owner phone is pre-configured in settings.",
        "input_schema": {
            "type": "object",
            "properties": {
                "report_type": {"type": "string", "enum": ["daily_operations", "daily_sales", "monthly_profit", "top_products", "low_stock", "cash_flow", "customer_balances", "supplier_balances", "profit_loss", "expense_by_category", "inventory_valuation", "dead_stock", "stock_movement"], "default": "daily_operations", "description": "Type of report to send"},
            },
            "required": [],
        },
    },
    {
        "name": "get_daily_operations_report",
        "description": "Get comprehensive daily operations summary including sales (count, total, cash, credit), purchases, expenses, returns, and net cash position. Perfect for voice readback of today's business activity.",
        "input_schema": {"type": "object", "properties": {}, "required": []},
    },
    # ═══ WORKFLOW TOOLS (Composite Operations) ═══
    {
        "name": "create_invoice_and_notify",
        "description": "Creates a sales invoice AND sends it to the customer via WhatsApp in one atomic operation. Use this instead of calling create_invoice + send_whatsapp_message separately. Guarantees both actions complete together.",
        "input_schema": {
            "type": "object",
            "properties": {
                "customer_id": {"type": "integer", "description": "Customer ID (required for WhatsApp delivery)"},
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
                "paid_amount": {"type": "number", "description": "Amount paid now (for cash/mixed payments)"},
                "notes": {"type": "string"},
                "message_template": {"type": "string", "description": "Optional custom WhatsApp message template. Use {invoice_number}, {total}, {customer_name} as placeholders."},
            },
            "required": ["customer_id", "items"],
        },
    },
]
