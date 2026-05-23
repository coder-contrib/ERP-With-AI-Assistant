-- ============================================================
-- Ceramic Showroom ERP Database Structure
-- PostgreSQL Schema
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
-- ============================================================

-- ============================================================
-- ENGINE 1: INVENTORY ENGINE
-- Tables: products, warehouses, inventory_transactions, inventory_cache
-- Views: v_current_stock, v_product_avg_cost, v_product_details
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
    purchase_cost_per_meter DECIMAL(12, 2) NOT NULL DEFAULT 0,
    selling_price DECIMAL(12, 2) NOT NULL DEFAULT 0,
    pieces_per_carton INTEGER,
    meters_per_carton DECIMAL(10, 4),
    meters_per_piece DECIMAL(10, 4),
    barcode VARCHAR(100),
    product_image TEXT,
    active_status BOOLEAN NOT NULL DEFAULT TRUE,
    created_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes TEXT
);

-- 3. Warehouses Table
CREATE TABLE warehouses (
    warehouse_id SERIAL PRIMARY KEY,
    warehouse_name VARCHAR(100) NOT NULL,
    warehouse_location VARCHAR(255),
    notes TEXT
);

-- 4. Inventory Transactions Table (SOURCE OF TRUTH)
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

-- 5. Inventory Cache Table (AUTO-UPDATED, NOT MANUALLY EDITED)
CREATE TABLE inventory_cache (
    inventory_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    warehouse_id INTEGER NOT NULL REFERENCES warehouses(warehouse_id),
    cached_quantity DECIMAL(14, 4) NOT NULL DEFAULT 0,
    cached_avg_cost DECIMAL(12, 2) NOT NULL DEFAULT 0,
    last_updated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (product_id, warehouse_id)
);

-- ============================================================
-- View: Real-time stock calculated from transactions
-- ============================================================
CREATE OR REPLACE VIEW v_current_stock AS
SELECT
    product_id,
    warehouse_id,
    COALESCE(SUM(CASE WHEN direction = 'IN' THEN quantity ELSE 0 END), 0)
    - COALESCE(SUM(CASE WHEN direction = 'OUT' THEN quantity ELSE 0 END), 0) AS available_quantity,
    MAX(created_date) AS last_transaction_date
FROM inventory_transactions
GROUP BY product_id, warehouse_id;

-- ============================================================
-- View: Weighted average cost per product per warehouse (COGS basis)
-- ============================================================
CREATE OR REPLACE VIEW v_product_avg_cost AS
SELECT
    product_id,
    warehouse_id,
    CASE
        WHEN SUM(CASE WHEN direction = 'IN' THEN quantity ELSE 0 END) > 0
        THEN SUM(CASE WHEN direction = 'IN' THEN quantity * cost_per_unit ELSE 0 END)
             / SUM(CASE WHEN direction = 'IN' THEN quantity ELSE 0 END)
        ELSE 0
    END AS weighted_avg_cost,
    SUM(CASE WHEN direction = 'IN' THEN quantity * cost_per_unit ELSE 0 END) AS total_cost_in,
    SUM(CASE WHEN direction = 'IN' THEN quantity ELSE 0 END) AS total_qty_in
FROM inventory_transactions
GROUP BY product_id, warehouse_id;

-- ============================================================
-- View: Product with category and conversion info
-- ============================================================
CREATE OR REPLACE VIEW v_product_details AS
SELECT
    p.product_id,
    p.product_name,
    p.category_id,
    c.category_name,
    p.is_meter_based,
    p.allow_piece_sale,
    p.allow_carton_display,
    p.purchase_cost_per_meter,
    p.selling_price,
    p.pieces_per_carton,
    p.meters_per_carton,
    p.meters_per_piece,
    p.barcode,
    p.active_status
FROM products p
LEFT JOIN categories c ON c.category_id = p.category_id;

-- ============================================================
-- Trigger: Auto-update inventory_cache after each transaction
-- ============================================================
CREATE OR REPLACE FUNCTION fn_update_inventory_cache()
RETURNS TRIGGER AS $$
DECLARE
    v_avg_cost DECIMAL(12, 2);
BEGIN
    SELECT CASE
        WHEN SUM(CASE WHEN direction = 'IN' THEN quantity ELSE 0 END) > 0
        THEN SUM(CASE WHEN direction = 'IN' THEN quantity * cost_per_unit ELSE 0 END)
             / SUM(CASE WHEN direction = 'IN' THEN quantity ELSE 0 END)
        ELSE 0
    END INTO v_avg_cost
    FROM inventory_transactions
    WHERE product_id = NEW.product_id AND warehouse_id = NEW.warehouse_id;

    INSERT INTO inventory_cache (product_id, warehouse_id, cached_quantity, cached_avg_cost, last_updated)
    SELECT
        NEW.product_id,
        NEW.warehouse_id,
        COALESCE(SUM(CASE WHEN direction = 'IN' THEN quantity ELSE 0 END), 0)
        - COALESCE(SUM(CASE WHEN direction = 'OUT' THEN quantity ELSE 0 END), 0),
        v_avg_cost,
        NOW()
    FROM inventory_transactions
    WHERE product_id = NEW.product_id AND warehouse_id = NEW.warehouse_id
    ON CONFLICT (product_id, warehouse_id)
    DO UPDATE SET
        cached_quantity = EXCLUDED.cached_quantity,
        cached_avg_cost = EXCLUDED.cached_avg_cost,
        last_updated = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_inventory_cache
AFTER INSERT ON inventory_transactions
FOR EACH ROW
EXECUTE FUNCTION fn_update_inventory_cache();

-- ============================================================
-- Function: Full cache refresh (run periodically or on demand)
-- ============================================================
CREATE OR REPLACE FUNCTION fn_refresh_inventory_cache()
RETURNS VOID AS $$
BEGIN
    TRUNCATE inventory_cache;
    INSERT INTO inventory_cache (product_id, warehouse_id, cached_quantity, cached_avg_cost, last_updated)
    SELECT
        product_id,
        warehouse_id,
        COALESCE(SUM(CASE WHEN direction = 'IN' THEN quantity ELSE 0 END), 0)
        - COALESCE(SUM(CASE WHEN direction = 'OUT' THEN quantity ELSE 0 END), 0),
        CASE
            WHEN SUM(CASE WHEN direction = 'IN' THEN quantity ELSE 0 END) > 0
            THEN SUM(CASE WHEN direction = 'IN' THEN quantity * cost_per_unit ELSE 0 END)
                 / SUM(CASE WHEN direction = 'IN' THEN quantity ELSE 0 END)
            ELSE 0
        END,
        NOW()
    FROM inventory_transactions
    GROUP BY product_id, warehouse_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- ENGINE 2: CASH ENGINE
-- Tables: cash_transactions, customer_payments, supplier_payments
-- Views: v_cash_balance
-- ============================================================

-- 6. Customers Table
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

-- 7. Suppliers Table
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

-- 8. Sales Invoices Table
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
    CONSTRAINT chk_credit_requires_customer CHECK (
        invoice_type = 'cash' OR (invoice_type = 'credit' AND customer_id IS NOT NULL)
    )
);

-- 9. Sales Invoice Items Table
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

-- 10. Sales Returns Table
CREATE TABLE sales_returns (
    return_id SERIAL PRIMARY KEY,
    original_invoice_id INTEGER NOT NULL REFERENCES sales_invoices(invoice_id),
    customer_id INTEGER REFERENCES customers(customer_id),
    return_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    returned_amount DECIMAL(14, 2) NOT NULL DEFAULT 0,
    refund_amount DECIMAL(14, 2) NOT NULL DEFAULT 0,
    notes TEXT
);

-- 11. Sales Return Items Table
CREATE TABLE sales_return_items (
    item_id SERIAL PRIMARY KEY,
    return_id INTEGER NOT NULL REFERENCES sales_returns(return_id),
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    returned_quantity DECIMAL(14, 4) NOT NULL,
    unit_price DECIMAL(12, 2) NOT NULL,
    total DECIMAL(14, 2) NOT NULL
);

-- 12. Purchase Invoices Table
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

-- 13. Purchase Invoice Items Table
CREATE TABLE purchase_invoice_items (
    item_id SERIAL PRIMARY KEY,
    purchase_invoice_id INTEGER NOT NULL REFERENCES purchase_invoices(purchase_invoice_id),
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    purchased_quantity DECIMAL(14, 4) NOT NULL,
    purchase_price DECIMAL(12, 2) NOT NULL,
    total_cost DECIMAL(14, 2) NOT NULL
);

-- 14. Purchase Returns Table
CREATE TABLE purchase_returns (
    return_id SERIAL PRIMARY KEY,
    original_purchase_invoice_id INTEGER NOT NULL REFERENCES purchase_invoices(purchase_invoice_id),
    supplier_id INTEGER NOT NULL REFERENCES suppliers(supplier_id),
    return_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    returned_amount DECIMAL(14, 2) NOT NULL DEFAULT 0,
    notes TEXT
);

-- 15. Purchase Return Items Table
CREATE TABLE purchase_return_items (
    item_id SERIAL PRIMARY KEY,
    return_id INTEGER NOT NULL REFERENCES purchase_returns(return_id),
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    returned_quantity DECIMAL(14, 4) NOT NULL,
    unit_cost DECIMAL(12, 2) NOT NULL,
    total DECIMAL(14, 2) NOT NULL
);

-- 16. Customer Payments Table
CREATE TABLE customer_payments (
    payment_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    related_invoice_id INTEGER REFERENCES sales_invoices(invoice_id),
    payment_amount DECIMAL(14, 2) NOT NULL,
    payment_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes TEXT
);

-- 17. Supplier Payments Table
CREATE TABLE supplier_payments (
    payment_id SERIAL PRIMARY KEY,
    supplier_id INTEGER NOT NULL REFERENCES suppliers(supplier_id),
    related_purchase_invoice_id INTEGER REFERENCES purchase_invoices(purchase_invoice_id),
    payment_amount DECIMAL(14, 2) NOT NULL,
    payment_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes TEXT
);

-- 18. Cash Transactions Table
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

-- ============================================================
-- View: Cash balance
-- ============================================================
CREATE OR REPLACE VIEW v_cash_balance AS
SELECT
    COALESCE(SUM(CASE WHEN transaction_type = 'cash_in' THEN amount ELSE 0 END), 0)
    - COALESCE(SUM(CASE WHEN transaction_type = 'cash_out' THEN amount ELSE 0 END), 0) AS current_balance,
    COUNT(*) AS total_transactions,
    MAX(transaction_date) AS last_transaction_date
FROM cash_transactions;

-- ============================================================
-- View: Customers exceeding credit limit
-- ============================================================
CREATE OR REPLACE VIEW v_customers_over_limit AS
SELECT
    customer_id,
    customer_name,
    current_balance,
    credit_limit,
    (current_balance - credit_limit) AS over_limit_amount
FROM customers
WHERE credit_limit > 0 AND current_balance > credit_limit;

-- ============================================================
-- View: Suppliers with overdue payments
-- ============================================================
CREATE OR REPLACE VIEW v_suppliers_overdue AS
SELECT
    s.supplier_id,
    s.supplier_name,
    s.current_balance,
    s.payment_terms,
    s.last_payment_date,
    CASE
        WHEN s.last_payment_date IS NOT NULL
        THEN CURRENT_DATE - s.last_payment_date::date
        ELSE NULL
    END AS days_since_last_payment
FROM suppliers s
WHERE s.current_balance > 0
  AND s.payment_terms > 0
  AND (
    s.last_payment_date IS NULL
    OR (CURRENT_DATE - s.last_payment_date::date) > s.payment_terms
  );

-- 19. Expenses Table
CREATE TABLE expenses (
    expense_id SERIAL PRIMARY KEY,
    expense_category VARCHAR(100) NOT NULL,
    expense_name VARCHAR(200) NOT NULL,
    amount DECIMAL(14, 2) NOT NULL,
    expense_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes TEXT
);

-- 20. Waste Table
CREATE TABLE waste (
    waste_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    warehouse_id INTEGER NOT NULL REFERENCES warehouses(warehouse_id),
    quantity DECIMAL(14, 4) NOT NULL,
    waste_reason VARCHAR(200),
    waste_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes TEXT
);

-- 21. Warehouse Transfers Table
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
-- ENGINE 3: ACCOUNTING ENGINE (Profit & Loss + Ledger)
-- Tables: accounts, ledger_entries
-- Views: v_sales_profit, v_profit_and_loss, v_account_balances
-- ============================================================

-- 22. Chart of Accounts Table
CREATE TABLE accounts (
    account_id SERIAL PRIMARY KEY,
    account_code VARCHAR(20) NOT NULL UNIQUE,
    account_name VARCHAR(200) NOT NULL,
    account_type VARCHAR(20) NOT NULL CHECK (account_type IN (
        'asset', 'liability', 'equity', 'revenue', 'expense'
    )),
    parent_account_id INTEGER REFERENCES accounts(account_id),
    is_system BOOLEAN NOT NULL DEFAULT FALSE,
    active_status BOOLEAN NOT NULL DEFAULT TRUE,
    notes TEXT
);

-- 23. Ledger Entries Table (Double-Entry Audit Trail)
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
    CONSTRAINT chk_debit_or_credit CHECK (
        (debit > 0 AND credit = 0) OR (debit = 0 AND credit > 0)
    )
);

-- ============================================================
-- View: Account balances
-- ============================================================
CREATE OR REPLACE VIEW v_account_balances AS
SELECT
    a.account_id,
    a.account_code,
    a.account_name,
    a.account_type,
    COALESCE(SUM(le.debit), 0) AS total_debit,
    COALESCE(SUM(le.credit), 0) AS total_credit,
    CASE
        WHEN a.account_type IN ('asset', 'expense')
        THEN COALESCE(SUM(le.debit), 0) - COALESCE(SUM(le.credit), 0)
        ELSE COALESCE(SUM(le.credit), 0) - COALESCE(SUM(le.debit), 0)
    END AS balance
FROM accounts a
LEFT JOIN ledger_entries le ON le.account_id = a.account_id
GROUP BY a.account_id, a.account_code, a.account_name, a.account_type;

-- ============================================================
-- View: Profit per sales invoice item
-- Revenue - COGS = Gross Profit
-- ============================================================
CREATE OR REPLACE VIEW v_sales_profit AS
SELECT
    si.invoice_id,
    si.invoice_number,
    si.invoice_date,
    sii.item_id,
    sii.product_id,
    p.product_name,
    sii.sold_quantity,
    sii.unit_price,
    sii.total_price AS revenue,
    sii.cost_at_sale,
    (sii.sold_quantity * sii.cost_at_sale) AS cogs,
    sii.total_price - (sii.sold_quantity * sii.cost_at_sale) AS gross_profit
FROM sales_invoice_items sii
JOIN sales_invoices si ON si.invoice_id = sii.invoice_id
JOIN products p ON p.product_id = sii.product_id;

-- ============================================================
-- View: Profit & Loss Summary (for a period, use WHERE on dates)
-- ============================================================
CREATE OR REPLACE VIEW v_profit_and_loss AS
SELECT
    COALESCE((SELECT SUM(total_price) FROM sales_invoice_items sii
              JOIN sales_invoices si ON si.invoice_id = sii.invoice_id), 0) AS total_revenue,
    COALESCE((SELECT SUM(sold_quantity * cost_at_sale) FROM sales_invoice_items sii
              JOIN sales_invoices si ON si.invoice_id = sii.invoice_id), 0) AS total_cogs,
    COALESCE((SELECT SUM(total_price) FROM sales_invoice_items sii
              JOIN sales_invoices si ON si.invoice_id = sii.invoice_id), 0)
    - COALESCE((SELECT SUM(sold_quantity * cost_at_sale) FROM sales_invoice_items sii
              JOIN sales_invoices si ON si.invoice_id = sii.invoice_id), 0) AS gross_profit,
    COALESCE((SELECT SUM(amount) FROM expenses), 0) AS total_expenses,
    COALESCE((SELECT SUM(total_price) FROM sales_invoice_items sii
              JOIN sales_invoices si ON si.invoice_id = sii.invoice_id), 0)
    - COALESCE((SELECT SUM(sold_quantity * cost_at_sale) FROM sales_invoice_items sii
              JOIN sales_invoices si ON si.invoice_id = sii.invoice_id), 0)
    - COALESCE((SELECT SUM(amount) FROM expenses), 0) AS net_profit;

-- 24. Users Table
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    full_name VARCHAR(200) NOT NULL,
    username VARCHAR(100) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(30) NOT NULL CHECK (role IN ('admin', 'cashier', 'warehouse_employee', 'accountant')),
    active_status BOOLEAN NOT NULL DEFAULT TRUE,
    last_login TIMESTAMP
);

-- 25. Activity Logs Table
CREATE TABLE activity_logs (
    log_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id),
    action_type VARCHAR(100) NOT NULL,
    table_name VARCHAR(100),
    record_id INTEGER,
    action_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- Indexes for Performance
-- ============================================================

CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_barcode ON products(barcode);
CREATE INDEX idx_products_meter_based ON products(is_meter_based);
CREATE INDEX idx_inventory_cache_product ON inventory_cache(product_id);
CREATE INDEX idx_inventory_cache_warehouse ON inventory_cache(warehouse_id);
CREATE INDEX idx_inventory_transactions_product ON inventory_transactions(product_id);
CREATE INDEX idx_inventory_transactions_warehouse ON inventory_transactions(warehouse_id);
CREATE INDEX idx_inventory_transactions_type ON inventory_transactions(transaction_type);
CREATE INDEX idx_inventory_transactions_direction ON inventory_transactions(direction);
CREATE INDEX idx_inventory_transactions_product_warehouse ON inventory_transactions(product_id, warehouse_id);
CREATE INDEX idx_inventory_transactions_cost ON inventory_transactions(cost_per_unit);
CREATE INDEX idx_inventory_transactions_warehouse_from ON inventory_transactions(warehouse_from);
CREATE INDEX idx_inventory_transactions_warehouse_to ON inventory_transactions(warehouse_to);
CREATE INDEX idx_sales_invoices_customer ON sales_invoices(customer_id);
CREATE INDEX idx_sales_invoices_date ON sales_invoices(invoice_date);
CREATE INDEX idx_sales_invoices_type ON sales_invoices(invoice_type);
CREATE INDEX idx_sales_invoices_warehouse ON sales_invoices(warehouse_id);
CREATE INDEX idx_sales_invoice_items_invoice ON sales_invoice_items(invoice_id);
CREATE INDEX idx_sales_invoice_items_product ON sales_invoice_items(product_id);
CREATE INDEX idx_purchase_invoices_supplier ON purchase_invoices(supplier_id);
CREATE INDEX idx_purchase_invoice_items_invoice ON purchase_invoice_items(purchase_invoice_id);
CREATE INDEX idx_customer_payments_customer ON customer_payments(customer_id);
CREATE INDEX idx_supplier_payments_supplier ON supplier_payments(supplier_id);
CREATE INDEX idx_cash_transactions_type ON cash_transactions(transaction_type);
CREATE INDEX idx_cash_transactions_date ON cash_transactions(transaction_date);
CREATE INDEX idx_cash_transactions_entity ON cash_transactions(entity_type, entity_id);
CREATE INDEX idx_ledger_entries_account ON ledger_entries(account_id);
CREATE INDEX idx_ledger_entries_date ON ledger_entries(entry_date);
CREATE INDEX idx_ledger_entries_entity ON ledger_entries(entity_type, entity_id);
CREATE INDEX idx_activity_logs_user ON activity_logs(user_id);
CREATE INDEX idx_activity_logs_date ON activity_logs(action_date);

-- ============================================================
-- Sample Data: Categories
-- ============================================================

INSERT INTO categories (category_name, description) VALUES
    ('Floor Tiles', 'Ceramic and porcelain floor tiles'),
    ('Wall Tiles', 'Ceramic and porcelain wall tiles'),
    ('Porcelain', 'Premium porcelain products'),
    ('Decoration', 'Decorative ceramic items'),
    ('Accessories', 'Installation accessories and tools');

-- ============================================================
-- Sample Data: Warehouses
-- ============================================================

INSERT INTO warehouses (warehouse_name, warehouse_location, notes) VALUES
    ('Main Warehouse', 'Main Branch', 'Primary storage facility'),
    ('Secondary Warehouse', 'Secondary Branch', 'Overflow storage');

-- ============================================================
-- Sample Data: Chart of Accounts (Default Accounts)
-- ============================================================

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
    ('6100', 'Rent Expense', 'expense', FALSE),
    ('6200', 'Salaries Expense', 'expense', FALSE),
    ('6300', 'Utilities Expense', 'expense', FALSE),
    ('6400', 'Transportation Expense', 'expense', FALSE),
    ('6500', 'Maintenance Expense', 'expense', FALSE),
    ('7000', 'Waste & Loss', 'expense', TRUE);
