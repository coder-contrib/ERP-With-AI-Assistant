-- ============================================================
-- Ceramic Showroom ERP Database Structure + Seed Data
-- PostgreSQL Schema (Single File - Drop & Recreate)
-- ============================================================
-- DESIGN PRINCIPLES:
-- 1. inventory_transactions is the SOURCE OF TRUTH for all stock.
-- 2. Opening stock uses transaction_type = 'opening_stock' (no separate table).
-- 3. Opening cash/customer/supplier balances use cash_transactions and
--    entity_type = 'opening_balance'.
-- 4. The inventory_cache table is only a performance cache.
-- 5. cost_per_unit on every transaction enables accurate COGS and profit.
-- 6. Three engines: Inventory Engine, Cash Engine, Accounting Engine.
-- 7. Ledger entries provide full double-entry audit trail.
-- 8. Cache trigger uses DELTA logic (O(1) per insert, not full re-scan).
-- 9. Unit conversions are per-product via product_unit_conversions table.
-- 10. Financial summaries use precomputed daily_financial_summary table.
-- ============================================================

-- Drop all tables in reverse dependency order
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS activity_logs CASCADE;
DROP TABLE IF EXISTS daily_financial_summary CASCADE;
DROP TABLE IF EXISTS ledger_entries CASCADE;
DROP TABLE IF EXISTS accounts CASCADE;
DROP TABLE IF EXISTS warehouse_transfers CASCADE;
DROP TABLE IF EXISTS waste CASCADE;
DROP TABLE IF EXISTS expenses CASCADE;
DROP TABLE IF EXISTS expense_categories CASCADE;
DROP TABLE IF EXISTS cash_transactions CASCADE;
DROP TABLE IF EXISTS supplier_payments CASCADE;
DROP TABLE IF EXISTS customer_payments CASCADE;
DROP TABLE IF EXISTS purchase_return_items CASCADE;
DROP TABLE IF EXISTS purchase_returns CASCADE;
DROP TABLE IF EXISTS purchase_invoice_items CASCADE;
DROP TABLE IF EXISTS purchase_invoices CASCADE;
DROP TABLE IF EXISTS sales_return_items CASCADE;
DROP TABLE IF EXISTS sales_returns CASCADE;
DROP TABLE IF EXISTS sales_invoice_items CASCADE;
DROP TABLE IF EXISTS sales_invoices CASCADE;
DROP TABLE IF EXISTS suppliers CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS inventory_cache CASCADE;
DROP TABLE IF EXISTS inventory_transactions CASCADE;
DROP TABLE IF EXISTS warehouses CASCADE;
DROP TABLE IF EXISTS product_unit_conversions CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Drop views
DROP VIEW IF EXISTS v_current_stock CASCADE;
DROP VIEW IF EXISTS v_product_avg_cost CASCADE;
DROP VIEW IF EXISTS v_product_details CASCADE;
DROP VIEW IF EXISTS v_product_conversions CASCADE;
DROP VIEW IF EXISTS v_cash_balance CASCADE;
DROP VIEW IF EXISTS v_customers_over_limit CASCADE;
DROP VIEW IF EXISTS v_suppliers_overdue CASCADE;
DROP VIEW IF EXISTS v_profit_and_loss CASCADE;
DROP VIEW IF EXISTS v_account_balances CASCADE;
DROP VIEW IF EXISTS v_sales_profit CASCADE;

-- Drop functions and triggers
DROP TRIGGER IF EXISTS trg_update_inventory_cache ON inventory_transactions;
DROP FUNCTION IF EXISTS fn_update_inventory_cache();
DROP FUNCTION IF EXISTS fn_refresh_inventory_cache();
DROP FUNCTION IF EXISTS fn_convert_unit(INTEGER, DECIMAL, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS fn_refresh_daily_financial_summary(DATE);
DROP FUNCTION IF EXISTS fn_refresh_financial_summary_range(DATE, DATE);

-- ============================================================
-- ENGINE 1: INVENTORY ENGINE
-- ============================================================

-- 1. Categories Table
CREATE TABLE categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    description TEXT
);

-- 2. Products Table
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL,
    category_id INTEGER REFERENCES categories(category_id),
    is_meter_based BOOLEAN NOT NULL DEFAULT TRUE,
    allow_piece_sale BOOLEAN NOT NULL DEFAULT FALSE,
    allow_carton_display BOOLEAN NOT NULL DEFAULT TRUE,
    base_unit VARCHAR(20) NOT NULL CHECK (base_unit IN ('meter', 'piece')) DEFAULT 'meter',
    purchase_cost_per_meter DECIMAL(12, 2) NOT NULL DEFAULT 0,
    selling_price DECIMAL(12, 2) NOT NULL DEFAULT 0,
    barcode VARCHAR(100),
    product_image TEXT,
    active_status BOOLEAN NOT NULL DEFAULT TRUE,
    created_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes TEXT
);

-- 3. Product Unit Conversions Table
CREATE TABLE product_unit_conversions (
    conversion_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    from_unit VARCHAR(20) NOT NULL CHECK (from_unit IN ('meter', 'piece', 'carton')),
    to_unit VARCHAR(20) NOT NULL CHECK (to_unit IN ('meter', 'piece', 'carton')),
    factor DECIMAL(10, 4) NOT NULL CHECK (factor > 0),
    UNIQUE (product_id, from_unit, to_unit),
    CONSTRAINT chk_different_units CHECK (from_unit != to_unit)
);

-- Function: Convert quantity between units
CREATE OR REPLACE FUNCTION fn_convert_unit(
    p_product_id INTEGER,
    p_quantity DECIMAL(14, 4),
    p_from_unit VARCHAR(20),
    p_to_unit VARCHAR(20)
) RETURNS DECIMAL(14, 4) AS $$
DECLARE
    v_factor DECIMAL(10, 4);
    v_result DECIMAL(14, 4);
BEGIN
    IF p_from_unit = p_to_unit THEN RETURN p_quantity; END IF;
    SELECT factor INTO v_factor FROM product_unit_conversions WHERE product_id = p_product_id AND from_unit = p_from_unit AND to_unit = p_to_unit;
    IF v_factor IS NOT NULL THEN RETURN p_quantity * v_factor; END IF;
    SELECT factor INTO v_factor FROM product_unit_conversions WHERE product_id = p_product_id AND from_unit = p_to_unit AND to_unit = p_from_unit;
    IF v_factor IS NOT NULL AND v_factor > 0 THEN RETURN p_quantity / v_factor; END IF;
    SELECT (p_quantity * c1.factor * c2.factor) INTO v_result FROM product_unit_conversions c1 JOIN product_unit_conversions c2 ON c2.product_id = c1.product_id AND c2.from_unit = c1.to_unit WHERE c1.product_id = p_product_id AND c1.from_unit = p_from_unit AND c2.to_unit = p_to_unit LIMIT 1;
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- 4. Warehouses Table
CREATE TABLE warehouses (
    warehouse_id SERIAL PRIMARY KEY,
    warehouse_name VARCHAR(100) NOT NULL,
    warehouse_location VARCHAR(255),
    notes TEXT
);

-- 5. Inventory Transactions Table (SOURCE OF TRUTH)
CREATE TABLE inventory_transactions (
    transaction_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    warehouse_id INTEGER NOT NULL REFERENCES warehouses(warehouse_id),
    transaction_type VARCHAR(30) NOT NULL CHECK (transaction_type IN (
        'opening_stock', 'purchase', 'sale', 'sales_return',
        'purchase_return', 'waste', 'warehouse_transfer'
    )),
    direction VARCHAR(3) NOT NULL CHECK (direction IN ('IN', 'OUT')),
    quantity DECIMAL(14, 4) NOT NULL CHECK (quantity > 0),
    unit_type VARCHAR(20) NOT NULL CHECK (unit_type IN ('meter', 'piece', 'carton')),
    cost_per_unit DECIMAL(12, 2) NOT NULL DEFAULT 0,
    warehouse_from INTEGER REFERENCES warehouses(warehouse_id),
    warehouse_to INTEGER REFERENCES warehouses(warehouse_id),
    reference_type VARCHAR(50),
    reference_id INTEGER,
    notes TEXT,
    created_by INTEGER,
    created_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_transfer_warehouses CHECK (
        (transaction_type = 'warehouse_transfer' AND warehouse_from IS NOT NULL AND warehouse_to IS NOT NULL)
        OR (transaction_type != 'warehouse_transfer' AND warehouse_from IS NULL AND warehouse_to IS NULL)
    )
);

-- 6. Inventory Cache Table
CREATE TABLE inventory_cache (
    inventory_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    warehouse_id INTEGER NOT NULL REFERENCES warehouses(warehouse_id),
    cached_quantity DECIMAL(14, 4) NOT NULL DEFAULT 0,
    cached_avg_cost DECIMAL(12, 2) NOT NULL DEFAULT 0,
    cached_total_cost_in DECIMAL(16, 2) NOT NULL DEFAULT 0,
    cached_total_qty_in DECIMAL(14, 4) NOT NULL DEFAULT 0,
    last_updated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (product_id, warehouse_id)
);

-- Views
CREATE OR REPLACE VIEW v_current_stock AS
SELECT product_id, warehouse_id,
    COALESCE(SUM(CASE WHEN direction = 'IN' THEN quantity ELSE 0 END), 0)
    - COALESCE(SUM(CASE WHEN direction = 'OUT' THEN quantity ELSE 0 END), 0) AS available_quantity,
    MAX(created_date) AS last_transaction_date
FROM inventory_transactions GROUP BY product_id, warehouse_id;

CREATE OR REPLACE VIEW v_product_avg_cost AS
SELECT product_id, warehouse_id,
    CASE WHEN SUM(CASE WHEN direction = 'IN' THEN quantity ELSE 0 END) > 0
        THEN SUM(CASE WHEN direction = 'IN' THEN quantity * cost_per_unit ELSE 0 END) / SUM(CASE WHEN direction = 'IN' THEN quantity ELSE 0 END)
        ELSE 0 END AS weighted_avg_cost,
    SUM(CASE WHEN direction = 'IN' THEN quantity * cost_per_unit ELSE 0 END) AS total_cost_in,
    SUM(CASE WHEN direction = 'IN' THEN quantity ELSE 0 END) AS total_qty_in
FROM inventory_transactions GROUP BY product_id, warehouse_id;

CREATE OR REPLACE VIEW v_product_details AS
SELECT p.product_id, p.product_name, p.category_id, c.category_name, p.is_meter_based, p.base_unit, p.allow_piece_sale, p.allow_carton_display, p.purchase_cost_per_meter, p.selling_price, p.barcode, p.active_status
FROM products p LEFT JOIN categories c ON c.category_id = p.category_id;

CREATE OR REPLACE VIEW v_product_conversions AS
SELECT puc.conversion_id, puc.product_id, p.product_name, puc.from_unit, puc.to_unit, puc.factor
FROM product_unit_conversions puc JOIN products p ON p.product_id = puc.product_id;

-- Trigger: DELTA-BASED inventory_cache update
CREATE OR REPLACE FUNCTION fn_update_inventory_cache()
RETURNS TRIGGER AS $$
DECLARE v_delta DECIMAL(14, 4);
BEGIN
    IF NEW.direction = 'IN' THEN v_delta := NEW.quantity; ELSE v_delta := -NEW.quantity; END IF;
    INSERT INTO inventory_cache (product_id, warehouse_id, cached_quantity, cached_total_cost_in, cached_total_qty_in, cached_avg_cost, last_updated)
    VALUES (NEW.product_id, NEW.warehouse_id, v_delta,
        CASE WHEN NEW.direction = 'IN' THEN NEW.quantity * NEW.cost_per_unit ELSE 0 END,
        CASE WHEN NEW.direction = 'IN' THEN NEW.quantity ELSE 0 END,
        CASE WHEN NEW.direction = 'IN' THEN NEW.cost_per_unit ELSE 0 END, NOW())
    ON CONFLICT (product_id, warehouse_id) DO UPDATE SET
        cached_quantity = inventory_cache.cached_quantity + v_delta,
        cached_total_cost_in = inventory_cache.cached_total_cost_in + CASE WHEN NEW.direction = 'IN' THEN NEW.quantity * NEW.cost_per_unit ELSE 0 END,
        cached_total_qty_in = inventory_cache.cached_total_qty_in + CASE WHEN NEW.direction = 'IN' THEN NEW.quantity ELSE 0 END,
        cached_avg_cost = CASE
            WHEN (inventory_cache.cached_total_qty_in + CASE WHEN NEW.direction = 'IN' THEN NEW.quantity ELSE 0 END) > 0
            THEN (inventory_cache.cached_total_cost_in + CASE WHEN NEW.direction = 'IN' THEN NEW.quantity * NEW.cost_per_unit ELSE 0 END)
                 / (inventory_cache.cached_total_qty_in + CASE WHEN NEW.direction = 'IN' THEN NEW.quantity ELSE 0 END)
            ELSE inventory_cache.cached_avg_cost END,
        last_updated = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_inventory_cache AFTER INSERT ON inventory_transactions FOR EACH ROW EXECUTE FUNCTION fn_update_inventory_cache();

-- Function: Full cache refresh
CREATE OR REPLACE FUNCTION fn_refresh_inventory_cache() RETURNS VOID AS $$
BEGIN
    TRUNCATE inventory_cache;
    INSERT INTO inventory_cache (product_id, warehouse_id, cached_quantity, cached_total_cost_in, cached_total_qty_in, cached_avg_cost, last_updated)
    SELECT product_id, warehouse_id,
        COALESCE(SUM(CASE WHEN direction = 'IN' THEN quantity ELSE 0 END), 0) - COALESCE(SUM(CASE WHEN direction = 'OUT' THEN quantity ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN direction = 'IN' THEN quantity * cost_per_unit ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN direction = 'IN' THEN quantity ELSE 0 END), 0),
        CASE WHEN SUM(CASE WHEN direction = 'IN' THEN quantity ELSE 0 END) > 0
            THEN SUM(CASE WHEN direction = 'IN' THEN quantity * cost_per_unit ELSE 0 END) / SUM(CASE WHEN direction = 'IN' THEN quantity ELSE 0 END)
            ELSE 0 END, NOW()
    FROM inventory_transactions GROUP BY product_id, warehouse_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- ENGINE 2: CASH ENGINE
-- ============================================================

-- 7. Customers Table
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    customer_name VARCHAR(200) NOT NULL,
    phone_number VARCHAR(30),
    address TEXT,
    current_balance DECIMAL(14, 2) NOT NULL DEFAULT 0,
    credit_limit DECIMAL(14, 2) NOT NULL DEFAULT 0,
    payment_terms INTEGER NOT NULL DEFAULT 0,
    notes TEXT,
    created_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 8. Suppliers Table
CREATE TABLE suppliers (
    supplier_id SERIAL PRIMARY KEY,
    supplier_name VARCHAR(200) NOT NULL,
    phone_number VARCHAR(30),
    address TEXT,
    current_balance DECIMAL(14, 2) NOT NULL DEFAULT 0,
    payment_terms INTEGER NOT NULL DEFAULT 0,
    last_payment_date TIMESTAMP,
    notes TEXT
);

-- 9. Sales Invoices Table
CREATE TABLE sales_invoices (
    invoice_id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id),
    invoice_number VARCHAR(50) NOT NULL UNIQUE,
    invoice_type VARCHAR(10) NOT NULL CHECK (invoice_type IN ('cash', 'credit')) DEFAULT 'cash',
    invoice_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total_amount DECIMAL(14, 2) NOT NULL DEFAULT 0,
    discount_amount DECIMAL(14, 2) NOT NULL DEFAULT 0,
    paid_amount DECIMAL(14, 2) NOT NULL DEFAULT 0,
    remaining_amount DECIMAL(14, 2) NOT NULL DEFAULT 0,
    payment_status VARCHAR(20) NOT NULL CHECK (payment_status IN ('paid', 'partial', 'unpaid')) DEFAULT 'unpaid',
    warehouse_id INTEGER NOT NULL REFERENCES warehouses(warehouse_id),
    warehouse_notes TEXT,
    notes TEXT,
    CONSTRAINT chk_credit_requires_customer CHECK (invoice_type = 'cash' OR (invoice_type IN ('credit', 'mixed') AND customer_id IS NOT NULL))
);

-- 10. Sales Invoice Items
CREATE TABLE sales_invoice_items (
    item_id SERIAL PRIMARY KEY,
    invoice_id INTEGER NOT NULL REFERENCES sales_invoices(invoice_id),
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    sold_quantity DECIMAL(14, 4) NOT NULL,
    unit_type VARCHAR(20) NOT NULL CHECK (unit_type IN ('meter', 'piece', 'carton')),
    conversion_factor_used DECIMAL(10, 4),
    carton_count DECIMAL(10, 2),
    piece_count DECIMAL(10, 2),
    unit_price DECIMAL(12, 2) NOT NULL,
    cost_at_sale DECIMAL(12, 2) NOT NULL DEFAULT 0,
    discount DECIMAL(12, 2) NOT NULL DEFAULT 0,
    total_price DECIMAL(14, 2) NOT NULL,
    notes TEXT
);

-- 11-12. Sales Returns
CREATE TABLE sales_returns (
    return_id SERIAL PRIMARY KEY,
    original_invoice_id INTEGER NOT NULL REFERENCES sales_invoices(invoice_id),
    customer_id INTEGER REFERENCES customers(customer_id),
    return_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    returned_amount DECIMAL(14, 2) NOT NULL DEFAULT 0,
    refund_amount DECIMAL(14, 2) NOT NULL DEFAULT 0,
    notes TEXT
);

CREATE TABLE sales_return_items (
    item_id SERIAL PRIMARY KEY,
    return_id INTEGER NOT NULL REFERENCES sales_returns(return_id),
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    returned_quantity DECIMAL(14, 4) NOT NULL,
    unit_price DECIMAL(12, 2) NOT NULL,
    total DECIMAL(14, 2) NOT NULL
);

-- 13-14. Purchase Invoices
CREATE TABLE purchase_invoices (
    purchase_invoice_id SERIAL PRIMARY KEY,
    supplier_id INTEGER NOT NULL REFERENCES suppliers(supplier_id),
    invoice_number VARCHAR(50) NOT NULL,
    purchase_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total_amount DECIMAL(14, 2) NOT NULL DEFAULT 0,
    paid_amount DECIMAL(14, 2) NOT NULL DEFAULT 0,
    remaining_amount DECIMAL(14, 2) NOT NULL DEFAULT 0,
    payment_status VARCHAR(20) NOT NULL CHECK (payment_status IN ('paid', 'partial', 'unpaid')) DEFAULT 'unpaid',
    notes TEXT
);

CREATE TABLE purchase_invoice_items (
    item_id SERIAL PRIMARY KEY,
    purchase_invoice_id INTEGER NOT NULL REFERENCES purchase_invoices(purchase_invoice_id),
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    purchased_quantity DECIMAL(14, 4) NOT NULL,
    purchase_price DECIMAL(12, 2) NOT NULL,
    total_cost DECIMAL(14, 2) NOT NULL
);

-- 15-16. Purchase Returns
CREATE TABLE purchase_returns (
    return_id SERIAL PRIMARY KEY,
    original_purchase_invoice_id INTEGER NOT NULL REFERENCES purchase_invoices(purchase_invoice_id),
    supplier_id INTEGER NOT NULL REFERENCES suppliers(supplier_id),
    return_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    returned_amount DECIMAL(14, 2) NOT NULL DEFAULT 0,
    notes TEXT
);

CREATE TABLE purchase_return_items (
    item_id SERIAL PRIMARY KEY,
    return_id INTEGER NOT NULL REFERENCES purchase_returns(return_id),
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    returned_quantity DECIMAL(14, 4) NOT NULL,
    unit_cost DECIMAL(12, 2) NOT NULL,
    total DECIMAL(14, 2) NOT NULL
);

-- 17-18. Payments
CREATE TABLE customer_payments (
    payment_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    related_invoice_id INTEGER REFERENCES sales_invoices(invoice_id),
    payment_amount DECIMAL(14, 2) NOT NULL,
    payment_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes TEXT
);

CREATE TABLE supplier_payments (
    payment_id SERIAL PRIMARY KEY,
    supplier_id INTEGER NOT NULL REFERENCES suppliers(supplier_id),
    related_purchase_invoice_id INTEGER REFERENCES purchase_invoices(purchase_invoice_id),
    payment_amount DECIMAL(14, 2) NOT NULL,
    payment_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes TEXT
);

-- 19. Cash Transactions
CREATE TABLE cash_transactions (
    transaction_id SERIAL PRIMARY KEY,
    transaction_type VARCHAR(20) NOT NULL CHECK (transaction_type IN ('cash_in', 'cash_out')),
    amount DECIMAL(14, 2) NOT NULL,
    entity_type VARCHAR(30) NOT NULL CHECK (entity_type IN (
        'sales_invoice', 'purchase_invoice', 'customer_payment',
        'supplier_payment', 'expense', 'sales_return', 'purchase_return',
        'opening_balance'
    )),
    entity_id INTEGER,
    description TEXT,
    created_by INTEGER,
    transaction_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Cash Views
CREATE OR REPLACE VIEW v_cash_balance AS
SELECT
    COALESCE(SUM(CASE WHEN transaction_type = 'cash_in' THEN amount ELSE 0 END), 0)
    - COALESCE(SUM(CASE WHEN transaction_type = 'cash_out' THEN amount ELSE 0 END), 0) AS current_balance,
    COUNT(*) AS total_transactions, MAX(transaction_date) AS last_transaction_date
FROM cash_transactions;

CREATE OR REPLACE VIEW v_customers_over_limit AS
SELECT customer_id, customer_name, current_balance, credit_limit, (current_balance - credit_limit) AS over_limit_amount
FROM customers WHERE credit_limit > 0 AND current_balance > credit_limit;

CREATE OR REPLACE VIEW v_suppliers_overdue AS
SELECT s.supplier_id, s.supplier_name, s.current_balance, s.payment_terms, s.last_payment_date,
    CASE WHEN s.last_payment_date IS NOT NULL THEN CURRENT_DATE - s.last_payment_date::date ELSE NULL END AS days_since_last_payment
FROM suppliers s WHERE s.current_balance > 0 AND s.payment_terms > 0
    AND (s.last_payment_date IS NULL OR (CURRENT_DATE - s.last_payment_date::date) > s.payment_terms);

-- 20. Expense Categories
CREATE TABLE expense_categories (
    category_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT
);

-- 21. Expenses
CREATE TABLE expenses (
    expense_id SERIAL PRIMARY KEY,
    expense_category VARCHAR(100) NOT NULL,
    expense_name VARCHAR(200) NOT NULL,
    amount DECIMAL(14, 2) NOT NULL,
    payment_method VARCHAR(30) DEFAULT 'cash',
    paid_by VARCHAR(100),
    receipt_number VARCHAR(50),
    expense_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    created_by INTEGER
);

-- 22. Waste
CREATE TABLE waste (
    waste_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    warehouse_id INTEGER NOT NULL REFERENCES warehouses(warehouse_id),
    quantity DECIMAL(14, 4) NOT NULL,
    waste_reason VARCHAR(200),
    waste_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes TEXT
);

-- 23. Warehouse Transfers
CREATE TABLE warehouse_transfers (
    transfer_id SERIAL PRIMARY KEY,
    from_warehouse_id INTEGER NOT NULL REFERENCES warehouses(warehouse_id),
    to_warehouse_id INTEGER NOT NULL REFERENCES warehouses(warehouse_id),
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    quantity DECIMAL(14, 4) NOT NULL,
    transfer_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes TEXT
);

-- ============================================================
-- ENGINE 3: ACCOUNTING ENGINE
-- ============================================================

-- 24. Chart of Accounts
CREATE TABLE accounts (
    account_id SERIAL PRIMARY KEY,
    account_code VARCHAR(20) NOT NULL UNIQUE,
    account_name VARCHAR(200) NOT NULL,
    account_type VARCHAR(20) NOT NULL CHECK (account_type IN ('asset', 'liability', 'equity', 'revenue', 'expense')),
    parent_account_id INTEGER REFERENCES accounts(account_id),
    is_system BOOLEAN NOT NULL DEFAULT FALSE,
    active_status BOOLEAN NOT NULL DEFAULT TRUE,
    notes TEXT
);

-- 25. Ledger Entries
CREATE TABLE ledger_entries (
    entry_id SERIAL PRIMARY KEY,
    entry_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    account_id INTEGER NOT NULL REFERENCES accounts(account_id),
    debit DECIMAL(14, 2) NOT NULL DEFAULT 0,
    credit DECIMAL(14, 2) NOT NULL DEFAULT 0,
    entity_type VARCHAR(30) NOT NULL,
    entity_id INTEGER NOT NULL,
    description TEXT,
    created_by INTEGER,
    created_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_debit_or_credit CHECK ((debit > 0 AND credit = 0) OR (debit = 0 AND credit > 0))
);

-- 26. Daily Financial Summary
CREATE TABLE daily_financial_summary (
    summary_id SERIAL PRIMARY KEY,
    summary_date DATE NOT NULL UNIQUE,
    revenue DECIMAL(14, 2) NOT NULL DEFAULT 0,
    cogs DECIMAL(14, 2) NOT NULL DEFAULT 0,
    gross_profit DECIMAL(14, 2) NOT NULL DEFAULT 0,
    expenses DECIMAL(14, 2) NOT NULL DEFAULT 0,
    net_profit DECIMAL(14, 2) NOT NULL DEFAULT 0,
    sales_count INTEGER NOT NULL DEFAULT 0,
    returns_amount DECIMAL(14, 2) NOT NULL DEFAULT 0,
    last_updated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Financial Functions
CREATE OR REPLACE FUNCTION fn_refresh_daily_financial_summary(p_date DATE DEFAULT CURRENT_DATE) RETURNS VOID AS $$
DECLARE v_revenue DECIMAL(14,2); v_cogs DECIMAL(14,2); v_expenses DECIMAL(14,2); v_returns DECIMAL(14,2); v_sales_count INTEGER;
BEGIN
    SELECT COALESCE(SUM(sii.total_price),0), COALESCE(SUM(sii.sold_quantity * sii.cost_at_sale),0), COUNT(DISTINCT si.invoice_id)
    INTO v_revenue, v_cogs, v_sales_count FROM sales_invoice_items sii JOIN sales_invoices si ON si.invoice_id = sii.invoice_id WHERE si.invoice_date::date = p_date;
    SELECT COALESCE(SUM(amount),0) INTO v_expenses FROM expenses WHERE expense_date::date = p_date;
    SELECT COALESCE(SUM(returned_amount),0) INTO v_returns FROM sales_returns WHERE return_date::date = p_date;
    INSERT INTO daily_financial_summary (summary_date, revenue, cogs, gross_profit, expenses, net_profit, sales_count, returns_amount, last_updated)
    VALUES (p_date, v_revenue, v_cogs, v_revenue - v_cogs, v_expenses, (v_revenue - v_cogs) - v_expenses, v_sales_count, v_returns, NOW())
    ON CONFLICT (summary_date) DO UPDATE SET revenue=EXCLUDED.revenue, cogs=EXCLUDED.cogs, gross_profit=EXCLUDED.gross_profit, expenses=EXCLUDED.expenses, net_profit=EXCLUDED.net_profit, sales_count=EXCLUDED.sales_count, returns_amount=EXCLUDED.returns_amount, last_updated=NOW();
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_refresh_financial_summary_range(p_start_date DATE, p_end_date DATE DEFAULT CURRENT_DATE) RETURNS VOID AS $$
DECLARE v_date DATE;
BEGIN v_date := p_start_date; WHILE v_date <= p_end_date LOOP PERFORM fn_refresh_daily_financial_summary(v_date); v_date := v_date + 1; END LOOP; END;
$$ LANGUAGE plpgsql;

-- Accounting Views
CREATE OR REPLACE VIEW v_profit_and_loss AS
SELECT summary_date, revenue, cogs, gross_profit, expenses, net_profit, sales_count, returns_amount FROM daily_financial_summary ORDER BY summary_date DESC;

CREATE OR REPLACE VIEW v_account_balances AS
SELECT a.account_id, a.account_code, a.account_name, a.account_type,
    COALESCE(SUM(le.debit),0) AS total_debit, COALESCE(SUM(le.credit),0) AS total_credit,
    CASE WHEN a.account_type IN ('asset','expense') THEN COALESCE(SUM(le.debit),0) - COALESCE(SUM(le.credit),0)
         ELSE COALESCE(SUM(le.credit),0) - COALESCE(SUM(le.debit),0) END AS balance
FROM accounts a LEFT JOIN ledger_entries le ON le.account_id = a.account_id GROUP BY a.account_id, a.account_code, a.account_name, a.account_type;

CREATE OR REPLACE VIEW v_sales_profit AS
SELECT si.invoice_id, si.invoice_number, si.invoice_date, sii.item_id, sii.product_id, p.product_name, sii.sold_quantity, sii.unit_price,
    sii.total_price AS revenue, sii.cost_at_sale, (sii.sold_quantity * sii.cost_at_sale) AS cogs, sii.total_price - (sii.sold_quantity * sii.cost_at_sale) AS gross_profit
FROM sales_invoice_items sii JOIN sales_invoices si ON si.invoice_id = sii.invoice_id JOIN products p ON p.product_id = sii.product_id;

-- 27. Users
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    full_name VARCHAR(200) NOT NULL,
    username VARCHAR(100) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(30) NOT NULL CHECK (role IN ('admin', 'cashier', 'warehouse_employee', 'accountant')),
    active_status BOOLEAN NOT NULL DEFAULT TRUE,
    last_login TIMESTAMP
);

-- 28. Activity Logs
CREATE TABLE activity_logs (
    log_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id),
    action_type VARCHAR(100) NOT NULL,
    table_name VARCHAR(100),
    record_id INTEGER,
    action_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 29. Notifications
CREATE TABLE notifications (
    notification_id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(user_id),
    notification_type VARCHAR(50) NOT NULL,
    severity VARCHAR(20) NOT NULL DEFAULT 'info',
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    entity_type VARCHAR(50),
    entity_id INTEGER,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_barcode ON products(barcode);
CREATE INDEX idx_product_conversions_product ON product_unit_conversions(product_id);
CREATE INDEX idx_inventory_cache_product ON inventory_cache(product_id);
CREATE INDEX idx_inventory_cache_warehouse ON inventory_cache(warehouse_id);
CREATE INDEX idx_inventory_transactions_product ON inventory_transactions(product_id);
CREATE INDEX idx_inventory_transactions_warehouse ON inventory_transactions(warehouse_id);
CREATE INDEX idx_inventory_transactions_type ON inventory_transactions(transaction_type);
CREATE INDEX idx_inventory_transactions_product_warehouse ON inventory_transactions(product_id, warehouse_id);
CREATE INDEX idx_sales_invoices_customer ON sales_invoices(customer_id);
CREATE INDEX idx_sales_invoices_date ON sales_invoices(invoice_date);
CREATE INDEX idx_sales_invoice_items_invoice ON sales_invoice_items(invoice_id);
CREATE INDEX idx_sales_invoice_items_product ON sales_invoice_items(product_id);
CREATE INDEX idx_purchase_invoices_supplier ON purchase_invoices(supplier_id);
CREATE INDEX idx_purchase_invoice_items_invoice ON purchase_invoice_items(purchase_invoice_id);
CREATE INDEX idx_customer_payments_customer ON customer_payments(customer_id);
CREATE INDEX idx_supplier_payments_supplier ON supplier_payments(supplier_id);
CREATE INDEX idx_cash_transactions_type ON cash_transactions(transaction_type);
CREATE INDEX idx_cash_transactions_date ON cash_transactions(transaction_date);
CREATE INDEX idx_cash_transactions_entity ON cash_transactions(entity_type, entity_id);
CREATE INDEX idx_expenses_category ON expenses(expense_category);
CREATE INDEX idx_expenses_date ON expenses(expense_date);
CREATE INDEX idx_ledger_entries_account ON ledger_entries(account_id);
CREATE INDEX idx_ledger_entries_entity ON ledger_entries(entity_type, entity_id);
CREATE INDEX idx_daily_financial_summary_date ON daily_financial_summary(summary_date);
CREATE INDEX idx_activity_logs_user ON activity_logs(user_id);
CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_read ON notifications(is_read);
CREATE INDEX idx_notifications_date ON notifications(created_date);

-- ============================================================
-- SEED DATA
-- ============================================================

-- Users (password: admin123)
INSERT INTO users (full_name, username, password, role, active_status) VALUES
    ('Ahmed Ali', 'admin', '$2b$12$LQv3c1yqBo9SkvXS7QTJPOoGz2EzfLhZyOcvGtNIPebPxZkK2FjmG', 'admin', TRUE),
    ('Mohammed Hassan', 'cashier1', '$2b$12$LQv3c1yqBo9SkvXS7QTJPOoGz2EzfLhZyOcvGtNIPebPxZkK2FjmG', 'cashier', TRUE),
    ('Sara Khalid', 'accountant1', '$2b$12$LQv3c1yqBo9SkvXS7QTJPOoGz2EzfLhZyOcvGtNIPebPxZkK2FjmG', 'accountant', TRUE),
    ('Omar Nasser', 'warehouse1', '$2b$12$LQv3c1yqBo9SkvXS7QTJPOoGz2EzfLhZyOcvGtNIPebPxZkK2FjmG', 'warehouse_employee', TRUE);

-- Categories
INSERT INTO categories (category_name, description) VALUES
    ('Floor Tiles', 'Ceramic and porcelain floor tiles'),
    ('Wall Tiles', 'Ceramic and porcelain wall tiles'),
    ('Porcelain', 'Premium porcelain products'),
    ('Decoration', 'Decorative ceramic items'),
    ('Accessories', 'Installation accessories and tools');

-- Warehouses
INSERT INTO warehouses (warehouse_name, warehouse_location, notes) VALUES
    ('Main Warehouse', 'Main Branch', 'Primary storage facility'),
    ('Secondary Warehouse', 'Secondary Branch', 'Overflow storage');

-- Chart of Accounts
INSERT INTO accounts (account_code, account_name, account_type, is_system) VALUES
    ('1000', 'Cash', 'asset', TRUE),
    ('1100', 'Accounts Receivable', 'asset', TRUE),
    ('1200', 'Inventory', 'asset', TRUE),
    ('2000', 'Accounts Payable', 'liability', TRUE),
    ('3000', 'Owner Equity', 'equity', TRUE),
    ('4000', 'Sales Revenue', 'revenue', TRUE),
    ('4100', 'Sales Returns', 'revenue', TRUE),
    ('5000', 'Cost of Goods Sold', 'expense', TRUE),
    ('5100', 'Purchase Returns', 'expense', TRUE),
    ('6000', 'Operating Expenses', 'expense', TRUE),
    ('7000', 'Waste & Loss', 'expense', TRUE);

-- Expense Categories
INSERT INTO expense_categories (name, description) VALUES
    ('Rent', 'Monthly rent payments'),
    ('Salaries', 'Employee salaries and wages'),
    ('Electricity', 'Electricity bills'),
    ('Water', 'Water bills'),
    ('Internet', 'Internet and telecom'),
    ('Transport', 'Transportation costs'),
    ('Maintenance', 'Repairs and maintenance'),
    ('Marketing', 'Marketing and advertising'),
    ('Packaging', 'Packaging materials'),
    ('Miscellaneous', 'Other uncategorized expenses');

-- Products
INSERT INTO products (product_name, category_id, is_meter_based, allow_piece_sale, allow_carton_display, base_unit, purchase_cost_per_meter, selling_price, barcode, active_status, notes) VALUES
    ('Royal Gold Floor Tile 60x60', 1, TRUE, FALSE, TRUE, 'meter', 8500, 12000, 'RG-60-001', TRUE, 'Premium gold pattern floor tile'),
    ('Classic White Wall Tile 30x60', 2, TRUE, FALSE, TRUE, 'meter', 4500, 7000, 'CW-30-002', TRUE, 'Standard white glossy wall tile'),
    ('Marble Effect Porcelain 80x80', 3, TRUE, FALSE, TRUE, 'meter', 15000, 22000, 'ME-80-003', TRUE, 'High-end marble look porcelain'),
    ('Mosaic Decorative Tile 30x30', 4, FALSE, TRUE, FALSE, 'piece', 3500, 5500, 'MD-30-004', TRUE, 'Handcrafted mosaic pieces'),
    ('Tile Adhesive 25kg Bag', 5, FALSE, TRUE, TRUE, 'piece', 12000, 18000, 'TA-25-005', TRUE, 'Professional grade adhesive'),
    ('Blue Ocean Wall Tile 25x75', 2, TRUE, FALSE, TRUE, 'meter', 6000, 9500, 'BO-25-006', TRUE, 'Blue gradient wall tile'),
    ('Granite Look Floor Tile 60x120', 1, TRUE, FALSE, TRUE, 'meter', 18000, 27000, 'GL-60-007', TRUE, 'Natural granite effect'),
    ('Rustic Wood Porcelain 20x120', 3, TRUE, FALSE, TRUE, 'meter', 14000, 20000, 'RW-20-008', TRUE, 'Wood-look porcelain plank'),
    ('Border Decorative Strip 8x60', 4, FALSE, TRUE, FALSE, 'piece', 2000, 3500, 'BD-08-009', TRUE, 'Gold border decoration'),
    ('Tile Grout 5kg White', 5, FALSE, TRUE, TRUE, 'piece', 5000, 8000, 'TG-05-010', TRUE, 'Premium white grout'),
    ('Beige Matte Floor Tile 45x45', 1, TRUE, FALSE, TRUE, 'meter', 5500, 8500, 'BM-45-011', TRUE, 'Matte beige natural look'),
    ('Hexagon Mosaic Sheet', 4, FALSE, TRUE, FALSE, 'piece', 8000, 13000, 'HM-SH-012', TRUE, 'Hexagonal mosaic sheet 30x30');

-- Unit Conversions
INSERT INTO product_unit_conversions (product_id, from_unit, to_unit, factor) VALUES
    (1, 'carton', 'meter', 1.44), (2, 'carton', 'meter', 1.08), (3, 'carton', 'meter', 1.28),
    (5, 'carton', 'piece', 48), (6, 'carton', 'meter', 1.50), (7, 'carton', 'meter', 1.44),
    (8, 'carton', 'meter', 1.44), (10, 'carton', 'piece', 20), (11, 'carton', 'meter', 1.62);

-- Customers
INSERT INTO customers (customer_name, phone_number, address, current_balance, credit_limit, payment_terms, notes) VALUES
    ('Ahmed Construction Co.', '07701234567', 'Baghdad, Mansour District', 2500000, 5000000, 30, 'Major contractor'),
    ('Ali Home Decor', '07709876543', 'Baghdad, Karrada', 850000, 2000000, 15, 'Interior design shop'),
    ('Hassan Building Materials', '07705551234', 'Basra, Center', 1200000, 3000000, 30, 'Wholesale buyer'),
    ('Fatima Tiles Shop', '07708887777', 'Erbil, Ankawa', 0, 1000000, 7, 'Small retail shop'),
    ('Baghdad Royal Hotel', '07701112222', 'Baghdad, Jadiriyah', 4500000, 10000000, 45, 'Large hotel renovation'),
    ('Noor Contracting', '07703334444', 'Najaf, City Center', 350000, 2000000, 30, 'Building projects'),
    ('Zain Interiors', '07706665555', 'Sulaymaniyah', 0, 500000, 7, 'Cash customer mostly');

-- Suppliers
INSERT INTO suppliers (supplier_name, phone_number, address, current_balance, payment_terms, notes) VALUES
    ('RAK Ceramics Iraq', '07801234567', 'UAE - Dubai Office', 8500000, 60, 'Main supplier for premium tiles'),
    ('China Tiles Import Co.', '07809876543', 'Guangzhou, China', 3200000, 45, 'Budget and mid-range tiles'),
    ('Turkish Ceramic Factory', '07805551234', 'Istanbul, Turkey', 5000000, 30, 'Porcelain and decorative tiles'),
    ('Local Adhesive Factory', '07808887777', 'Baghdad Industrial Zone', 450000, 15, 'Adhesive and grout supplier'),
    ('Italian Marble Imports', '07801112222', 'Milan, Italy', 12000000, 90, 'Premium marble-look porcelain');

-- Opening Stock
INSERT INTO inventory_transactions (product_id, warehouse_id, transaction_type, direction, quantity, unit_type, cost_per_unit, notes, created_by) VALUES
    (1, 1, 'opening_stock', 'IN', 250.0000, 'meter', 8500, 'Opening stock', 1),
    (1, 2, 'opening_stock', 'IN', 80.0000, 'meter', 8500, 'Opening stock', 1),
    (2, 1, 'opening_stock', 'IN', 400.0000, 'meter', 4500, 'Opening stock', 1),
    (3, 1, 'opening_stock', 'IN', 120.0000, 'meter', 15000, 'Opening stock', 1),
    (4, 1, 'opening_stock', 'IN', 500.0000, 'piece', 3500, 'Opening stock', 1),
    (5, 1, 'opening_stock', 'IN', 200.0000, 'piece', 12000, 'Opening stock', 1),
    (5, 2, 'opening_stock', 'IN', 50.0000, 'piece', 12000, 'Opening stock', 1),
    (6, 1, 'opening_stock', 'IN', 180.0000, 'meter', 6000, 'Opening stock', 1),
    (7, 1, 'opening_stock', 'IN', 90.0000, 'meter', 18000, 'Opening stock', 1),
    (8, 1, 'opening_stock', 'IN', 150.0000, 'meter', 14000, 'Opening stock', 1),
    (9, 1, 'opening_stock', 'IN', 300.0000, 'piece', 2000, 'Opening stock', 1),
    (10, 1, 'opening_stock', 'IN', 100.0000, 'piece', 5000, 'Opening stock', 1),
    (11, 1, 'opening_stock', 'IN', 200.0000, 'meter', 5500, 'Opening stock', 1),
    (12, 1, 'opening_stock', 'IN', 150.0000, 'piece', 8000, 'Opening stock', 1);

-- Purchase Invoices
INSERT INTO purchase_invoices (supplier_id, invoice_number, purchase_date, total_amount, paid_amount, remaining_amount, payment_status, notes) VALUES
    (1, 'PI-2026-001', '2026-05-01', 5100000, 2000000, 3100000, 'partial', 'RAK Ceramics monthly order'),
    (2, 'PI-2026-002', '2026-05-05', 2700000, 2700000, 0, 'paid', 'China Tiles bulk order'),
    (3, 'PI-2026-003', '2026-05-10', 4200000, 0, 4200000, 'unpaid', 'Turkish porcelain shipment'),
    (4, 'PI-2026-004', '2026-05-15', 960000, 960000, 0, 'paid', 'Adhesive and grout restock'),
    (1, 'PI-2026-005', '2026-05-20', 3600000, 1800000, 1800000, 'partial', 'RAK premium collection');

INSERT INTO purchase_invoice_items (purchase_invoice_id, product_id, purchased_quantity, purchase_price, total_cost) VALUES
    (1, 1, 200, 8500, 1700000), (1, 3, 100, 15000, 1500000), (1, 7, 50, 18000, 900000),
    (2, 2, 300, 4500, 1350000), (2, 6, 150, 6000, 900000), (2, 11, 100, 4500, 450000),
    (3, 8, 150, 14000, 2100000), (3, 3, 80, 15000, 1200000), (3, 12, 100, 9000, 900000),
    (4, 5, 60, 12000, 720000), (4, 10, 48, 5000, 240000),
    (5, 1, 150, 8500, 1275000), (5, 7, 75, 18000, 1350000);

-- Purchase inventory transactions
INSERT INTO inventory_transactions (product_id, warehouse_id, transaction_type, direction, quantity, unit_type, cost_per_unit, reference_type, reference_id, created_by) VALUES
    (1, 1, 'purchase', 'IN', 200, 'meter', 8500, 'purchase_invoice', 1, 1),
    (3, 1, 'purchase', 'IN', 100, 'meter', 15000, 'purchase_invoice', 1, 1),
    (7, 1, 'purchase', 'IN', 50, 'meter', 18000, 'purchase_invoice', 1, 1),
    (2, 1, 'purchase', 'IN', 300, 'meter', 4500, 'purchase_invoice', 2, 1),
    (6, 1, 'purchase', 'IN', 150, 'meter', 6000, 'purchase_invoice', 2, 1),
    (8, 1, 'purchase', 'IN', 150, 'meter', 14000, 'purchase_invoice', 3, 1),
    (5, 1, 'purchase', 'IN', 60, 'piece', 12000, 'purchase_invoice', 4, 1),
    (10, 1, 'purchase', 'IN', 48, 'piece', 5000, 'purchase_invoice', 4, 1),
    (1, 1, 'purchase', 'IN', 150, 'meter', 8500, 'purchase_invoice', 5, 1),
    (7, 1, 'purchase', 'IN', 75, 'meter', 18000, 'purchase_invoice', 5, 1);

-- Sales Invoices
INSERT INTO sales_invoices (customer_id, invoice_number, invoice_type, invoice_date, total_amount, discount_amount, paid_amount, remaining_amount, payment_status, warehouse_id, notes) VALUES
    (1, 'INV-2026-0001', 'credit', '2026-05-02', 3360000, 0, 1000000, 2360000, 'partial', 1, 'Floor tiles order'),
    (2, 'INV-2026-0002', 'cash', '2026-05-03', 1050000, 50000, 1050000, 0, 'paid', 1, 'Wall tiles'),
    (5, 'INV-2026-0003', 'credit', '2026-05-07', 8910000, 0, 4000000, 4910000, 'partial', 1, 'Hotel large order'),
    (3, 'INV-2026-0004', 'credit', '2026-05-10', 2160000, 0, 0, 2160000, 'unpaid', 1, 'Wholesale'),
    (4, 'INV-2026-0005', 'cash', '2026-05-12', 440000, 0, 440000, 0, 'paid', 1, 'Small order'),
    (6, 'INV-2026-0006', 'credit', '2026-05-15', 1800000, 0, 900000, 900000, 'partial', 1, 'Project supply'),
    (1, 'INV-2026-0007', 'credit', '2026-05-18', 2700000, 0, 2700000, 0, 'paid', 1, 'Porcelain'),
    (7, 'INV-2026-0008', 'cash', '2026-05-20', 585000, 15000, 585000, 0, 'paid', 1, 'Decor tiles'),
    (2, 'INV-2026-0009', 'cash', '2026-05-22', 720000, 0, 720000, 0, 'paid', 1, 'Reorder'),
    (5, 'INV-2026-0010', 'credit', '2026-05-24', 5400000, 0, 2000000, 3400000, 'partial', 1, 'Phase 2');

INSERT INTO sales_invoice_items (invoice_id, product_id, sold_quantity, unit_type, unit_price, cost_at_sale, discount, total_price) VALUES
    (1, 1, 120, 'meter', 12000, 8500, 0, 1440000), (1, 11, 80, 'meter', 8500, 5500, 0, 680000),
    (1, 5, 20, 'piece', 18000, 12000, 0, 360000), (1, 10, 10, 'piece', 8000, 5000, 0, 80000),
    (2, 2, 100, 'meter', 7000, 4500, 0, 700000), (2, 6, 50, 'meter', 9500, 6000, 50000, 425000),
    (3, 3, 80, 'meter', 22000, 15000, 0, 1760000), (3, 7, 90, 'meter', 27000, 18000, 0, 2430000),
    (3, 8, 100, 'meter', 20000, 14000, 0, 2000000), (3, 1, 60, 'meter', 12000, 8500, 0, 720000),
    (4, 2, 200, 'meter', 7000, 4500, 0, 1400000), (4, 6, 80, 'meter', 9500, 6000, 0, 760000),
    (5, 4, 50, 'piece', 5500, 3500, 0, 275000), (5, 9, 30, 'piece', 3500, 2000, 0, 105000),
    (6, 1, 100, 'meter', 12000, 8500, 0, 1200000), (6, 5, 30, 'piece', 18000, 12000, 0, 540000),
    (7, 3, 50, 'meter', 22000, 15000, 0, 1100000), (7, 7, 40, 'meter', 27000, 18000, 0, 1080000),
    (8, 4, 30, 'piece', 5500, 3500, 0, 165000), (8, 12, 20, 'piece', 13000, 8000, 0, 260000),
    (9, 6, 80, 'meter', 9500, 6000, 0, 760000),
    (10, 3, 100, 'meter', 22000, 15000, 0, 2200000), (10, 7, 60, 'meter', 27000, 18000, 0, 1620000), (10, 8, 80, 'meter', 20000, 14000, 0, 1600000);

-- Sale inventory transactions
INSERT INTO inventory_transactions (product_id, warehouse_id, transaction_type, direction, quantity, unit_type, cost_per_unit, reference_type, reference_id, created_by) VALUES
    (1, 1, 'sale', 'OUT', 120, 'meter', 8500, 'sales_invoice', 1, 2),
    (11, 1, 'sale', 'OUT', 80, 'meter', 5500, 'sales_invoice', 1, 2),
    (2, 1, 'sale', 'OUT', 100, 'meter', 4500, 'sales_invoice', 2, 2),
    (6, 1, 'sale', 'OUT', 50, 'meter', 6000, 'sales_invoice', 2, 2),
    (3, 1, 'sale', 'OUT', 80, 'meter', 15000, 'sales_invoice', 3, 2),
    (7, 1, 'sale', 'OUT', 90, 'meter', 18000, 'sales_invoice', 3, 2),
    (8, 1, 'sale', 'OUT', 100, 'meter', 14000, 'sales_invoice', 3, 2),
    (1, 1, 'sale', 'OUT', 60, 'meter', 8500, 'sales_invoice', 3, 2),
    (2, 1, 'sale', 'OUT', 200, 'meter', 4500, 'sales_invoice', 4, 2),
    (6, 1, 'sale', 'OUT', 80, 'meter', 6000, 'sales_invoice', 4, 2),
    (1, 1, 'sale', 'OUT', 100, 'meter', 8500, 'sales_invoice', 6, 2),
    (3, 1, 'sale', 'OUT', 50, 'meter', 15000, 'sales_invoice', 7, 2),
    (7, 1, 'sale', 'OUT', 40, 'meter', 18000, 'sales_invoice', 7, 2),
    (3, 1, 'sale', 'OUT', 100, 'meter', 15000, 'sales_invoice', 10, 2),
    (7, 1, 'sale', 'OUT', 60, 'meter', 18000, 'sales_invoice', 10, 2),
    (8, 1, 'sale', 'OUT', 80, 'meter', 14000, 'sales_invoice', 10, 2);

-- Payments
INSERT INTO customer_payments (customer_id, related_invoice_id, payment_amount, payment_date, notes) VALUES
    (1, 1, 1000000, '2026-05-05', 'Partial payment'), (5, 3, 4000000, '2026-05-12', 'Wire transfer'),
    (6, 6, 900000, '2026-05-18', 'Cash'), (1, 7, 2700000, '2026-05-19', 'Full payment'),
    (5, 10, 2000000, '2026-05-24', 'Phase 2 advance');

INSERT INTO supplier_payments (supplier_id, related_purchase_invoice_id, payment_amount, payment_date, notes) VALUES
    (2, 2, 2700000, '2026-05-06', 'Full payment'), (4, 4, 960000, '2026-05-14', 'Full payment'),
    (1, 1, 2000000, '2026-05-20', 'Partial payment'), (1, 5, 1800000, '2026-05-23', 'Partial payment');

-- Cash Transactions
INSERT INTO cash_transactions (transaction_type, amount, entity_type, entity_id, description, created_by, transaction_date) VALUES
    ('cash_in', 15000000, 'opening_balance', 0, 'Opening cash balance', 1, '2026-05-01'),
    ('cash_in', 1050000, 'sales_invoice', 2, 'Cash sale', 2, '2026-05-03'),
    ('cash_in', 1000000, 'customer_payment', 1, 'Ahmed Construction', 2, '2026-05-05'),
    ('cash_out', 2700000, 'purchase_invoice', 2, 'China Tiles payment', 1, '2026-05-06'),
    ('cash_in', 4000000, 'customer_payment', 2, 'Baghdad Royal Hotel', 2, '2026-05-12'),
    ('cash_in', 440000, 'sales_invoice', 5, 'Cash sale', 2, '2026-05-12'),
    ('cash_out', 960000, 'purchase_invoice', 4, 'Adhesive Factory', 1, '2026-05-14'),
    ('cash_in', 900000, 'customer_payment', 3, 'Noor Contracting', 2, '2026-05-18'),
    ('cash_in', 2700000, 'customer_payment', 4, 'Ahmed Construction', 2, '2026-05-19'),
    ('cash_in', 585000, 'sales_invoice', 8, 'Cash sale', 2, '2026-05-20'),
    ('cash_out', 2000000, 'purchase_invoice', 1, 'RAK Ceramics', 1, '2026-05-20'),
    ('cash_in', 720000, 'sales_invoice', 9, 'Cash sale', 2, '2026-05-22'),
    ('cash_out', 1800000, 'purchase_invoice', 5, 'RAK premium', 1, '2026-05-23'),
    ('cash_in', 2000000, 'customer_payment', 5, 'Baghdad Royal Hotel', 2, '2026-05-24');

-- Expenses
INSERT INTO expenses (expense_category, expense_name, amount, payment_method, paid_by, expense_date, notes, created_by) VALUES
    ('Rent', 'Showroom rent - May 2026', 3000000, 'bank', 'Ahmed Ali', '2026-05-01', 'Monthly showroom rent', 1),
    ('Salaries', 'Staff salaries - May 2026', 8500000, 'bank', 'Ahmed Ali', '2026-05-01', '4 employees', 1),
    ('Electricity', 'Electricity bill - April', 450000, 'cash', 'Mohammed Hassan', '2026-05-03', 'April bill', 2),
    ('Water', 'Water bill - April', 75000, 'cash', 'Mohammed Hassan', '2026-05-03', NULL, 2),
    ('Internet', 'Internet + phone - May', 120000, 'bank', 'Ahmed Ali', '2026-05-05', 'Fiber + landline', 1),
    ('Transport', 'Delivery truck fuel', 350000, 'cash', 'Omar Nasser', '2026-05-08', 'Weekly fuel', 4),
    ('Maintenance', 'AC repair - showroom', 250000, 'cash', 'Ahmed Ali', '2026-05-10', 'Compressor fix', 1),
    ('Transport', 'Customer delivery - Basra', 180000, 'cash', 'Omar Nasser', '2026-05-12', 'Hassan Building', 4),
    ('Packaging', 'Packaging materials', 95000, 'cash', 'Omar Nasser', '2026-05-14', 'Foam and cardboard', 4),
    ('Marketing', 'Facebook ads - May', 200000, 'bank', 'Sara Khalid', '2026-05-15', 'Social media', 3),
    ('Transport', 'Delivery truck fuel', 320000, 'cash', 'Omar Nasser', '2026-05-15', 'Weekly fuel', 4),
    ('Electricity', 'Warehouse electricity', 280000, 'cash', 'Mohammed Hassan', '2026-05-18', 'Secondary warehouse', 2),
    ('Miscellaneous', 'Office supplies', 45000, 'cash', 'Sara Khalid', '2026-05-19', 'Paper, pens, ink', 3),
    ('Transport', 'Customer delivery - Erbil', 450000, 'cash', 'Omar Nasser', '2026-05-20', 'Fatima Tiles', 4),
    ('Maintenance', 'Forklift service', 180000, 'cash', 'Omar Nasser', '2026-05-22', 'Annual maintenance', 4),
    ('Transport', 'Delivery truck fuel', 290000, 'cash', 'Omar Nasser', '2026-05-22', 'Weekly fuel', 4),
    ('Marketing', 'Showroom signage update', 350000, 'cash', 'Ahmed Ali', '2026-05-23', 'New LED sign', 1);

-- Expense cash-outs
INSERT INTO cash_transactions (transaction_type, amount, entity_type, entity_id, description, created_by, transaction_date) VALUES
    ('cash_out', 3000000, 'expense', 1, 'Rent', 1, '2026-05-01'),
    ('cash_out', 8500000, 'expense', 2, 'Salaries', 1, '2026-05-01'),
    ('cash_out', 450000, 'expense', 3, 'Electricity', 2, '2026-05-03'),
    ('cash_out', 75000, 'expense', 4, 'Water', 2, '2026-05-03'),
    ('cash_out', 120000, 'expense', 5, 'Internet', 1, '2026-05-05'),
    ('cash_out', 350000, 'expense', 6, 'Transport', 4, '2026-05-08'),
    ('cash_out', 250000, 'expense', 7, 'Maintenance', 1, '2026-05-10'),
    ('cash_out', 180000, 'expense', 8, 'Delivery', 4, '2026-05-12'),
    ('cash_out', 95000, 'expense', 9, 'Packaging', 4, '2026-05-14'),
    ('cash_out', 200000, 'expense', 10, 'Marketing', 3, '2026-05-15'),
    ('cash_out', 320000, 'expense', 11, 'Transport', 4, '2026-05-15'),
    ('cash_out', 280000, 'expense', 12, 'Electricity', 2, '2026-05-18'),
    ('cash_out', 45000, 'expense', 13, 'Office supplies', 3, '2026-05-19'),
    ('cash_out', 450000, 'expense', 14, 'Delivery', 4, '2026-05-20'),
    ('cash_out', 180000, 'expense', 15, 'Forklift', 4, '2026-05-22'),
    ('cash_out', 290000, 'expense', 16, 'Transport', 4, '2026-05-22'),
    ('cash_out', 350000, 'expense', 17, 'Signage', 1, '2026-05-23');

-- Ledger Entries
INSERT INTO ledger_entries (account_id, debit, credit, entity_type, entity_id, description) VALUES
    (1, 15000000, 0, 'opening_balance', 0, 'Opening cash balance'),
    (5, 0, 15000000, 'opening_balance', 0, 'Owner equity from opening cash'),
    (2, 2500000, 0, 'opening_balance', 1, 'Opening balance: Ahmed Construction Co.'),
    (2, 850000, 0, 'opening_balance', 2, 'Opening balance: Ali Home Decor'),
    (2, 1200000, 0, 'opening_balance', 3, 'Opening balance: Hassan Building Materials'),
    (2, 4500000, 0, 'opening_balance', 5, 'Opening balance: Baghdad Royal Hotel'),
    (4, 0, 8500000, 'opening_balance', 1, 'Opening balance: RAK Ceramics Iraq'),
    (4, 0, 3200000, 'opening_balance', 2, 'Opening balance: China Tiles Import Co.'),
    (4, 0, 5000000, 'opening_balance', 3, 'Opening balance: Turkish Ceramic Factory'),
    (4, 0, 450000, 'opening_balance', 4, 'Opening balance: Local Adhesive Factory'),
    (1, 1050000, 0, 'sales_invoice', 2, 'Cash sale'), (6, 0, 1050000, 'sales_invoice', 2, 'Sales revenue'),
    (2, 3360000, 0, 'sales_invoice', 1, 'Credit sale'), (6, 0, 3360000, 'sales_invoice', 1, 'Sales revenue'),
    (2, 8910000, 0, 'sales_invoice', 3, 'Credit sale'), (6, 0, 8910000, 'sales_invoice', 3, 'Sales revenue'),
    (1, 440000, 0, 'sales_invoice', 5, 'Cash sale'), (6, 0, 440000, 'sales_invoice', 5, 'Sales revenue'),
    (1, 585000, 0, 'sales_invoice', 8, 'Cash sale'), (6, 0, 585000, 'sales_invoice', 8, 'Sales revenue'),
    (10, 3000000, 0, 'expense', 1, 'Expense: Rent'), (1, 0, 3000000, 'expense', 1, 'Cash out: Rent'),
    (10, 8500000, 0, 'expense', 2, 'Expense: Salaries'), (1, 0, 8500000, 'expense', 2, 'Cash out: Salaries'),
    (10, 450000, 0, 'expense', 3, 'Expense: Electricity'), (1, 0, 450000, 'expense', 3, 'Cash out: Electricity'),
    (10, 350000, 0, 'expense', 6, 'Expense: Transport'), (1, 0, 350000, 'expense', 6, 'Cash out: Transport'),
    (10, 250000, 0, 'expense', 7, 'Expense: Maintenance'), (1, 0, 250000, 'expense', 7, 'Cash out: Maintenance');

-- Daily Financial Summary
INSERT INTO daily_financial_summary (summary_date, revenue, cogs, gross_profit, expenses, net_profit, sales_count, returns_amount) VALUES
    ('2026-05-02', 3360000, 2380000, 980000, 0, 980000, 1, 0),
    ('2026-05-03', 1050000, 750000, 300000, 525000, -225000, 1, 0),
    ('2026-05-07', 8910000, 6140000, 2770000, 0, 2770000, 1, 0),
    ('2026-05-10', 2160000, 1380000, 780000, 250000, 530000, 1, 0),
    ('2026-05-12', 440000, 250000, 190000, 180000, 10000, 1, 0),
    ('2026-05-15', 1800000, 1210000, 590000, 520000, 70000, 1, 0),
    ('2026-05-18', 2700000, 1830000, 870000, 280000, 590000, 1, 0),
    ('2026-05-20', 585000, 370000, 215000, 450000, -235000, 1, 0),
    ('2026-05-22', 720000, 480000, 240000, 470000, -230000, 1, 0),
    ('2026-05-24', 5400000, 3740000, 1660000, 0, 1660000, 1, 0);
