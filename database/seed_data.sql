-- ============================================================
-- Ceramic Showroom ERP - Sample/Seed Data
-- Run this AFTER schema.sql has been applied.
-- ============================================================

-- ============================================================
-- Admin User (password: admin123 - bcrypt hashed)
-- ============================================================
INSERT INTO users (full_name, username, password, role, active_status) VALUES
    ('Ahmed Ali', 'admin', '$2b$12$LQv3c1yqBo9SkvXS7QTJPOoGz2EzfLhZyOcvGtNIPebPxZkK2FjmG', 'admin', TRUE),
    ('Mohammed Hassan', 'cashier1', '$2b$12$LQv3c1yqBo9SkvXS7QTJPOoGz2EzfLhZyOcvGtNIPebPxZkK2FjmG', 'cashier', TRUE),
    ('Sara Khalid', 'accountant1', '$2b$12$LQv3c1yqBo9SkvXS7QTJPOoGz2EzfLhZyOcvGtNIPebPxZkK2FjmG', 'accountant', TRUE),
    ('Omar Nasser', 'warehouse1', '$2b$12$LQv3c1yqBo9SkvXS7QTJPOoGz2EzfLhZyOcvGtNIPebPxZkK2FjmG', 'warehouse_employee', TRUE)
ON CONFLICT (username) DO NOTHING;

-- ============================================================
-- Products
-- ============================================================
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
    ('Hexagon Mosaic Sheet', 4, FALSE, TRUE, FALSE, 'piece', 8000, 13000, 'HM-SH-012', TRUE, 'Hexagonal mosaic sheet 30x30')
ON CONFLICT DO NOTHING;

-- ============================================================
-- Product Unit Conversions
-- ============================================================
INSERT INTO product_unit_conversions (product_id, from_unit, to_unit, factor) VALUES
    (1, 'carton', 'meter', 1.44),
    (2, 'carton', 'meter', 1.08),
    (3, 'carton', 'meter', 1.28),
    (5, 'carton', 'piece', 48),
    (6, 'carton', 'meter', 1.50),
    (7, 'carton', 'meter', 1.44),
    (8, 'carton', 'meter', 1.44),
    (10, 'carton', 'piece', 20),
    (11, 'carton', 'meter', 1.62)
ON CONFLICT DO NOTHING;

-- ============================================================
-- Customers
-- ============================================================
INSERT INTO customers (customer_name, phone_number, address, current_balance, credit_limit, payment_terms, notes) VALUES
    ('Ahmed Construction Co.', '07701234567', 'Baghdad, Mansour District', 2500000, 5000000, 30, 'Major contractor, reliable payments'),
    ('Ali Home Decor', '07709876543', 'Baghdad, Karrada', 850000, 2000000, 15, 'Interior design shop'),
    ('Hassan Building Materials', '07705551234', 'Basra, Center', 1200000, 3000000, 30, 'Wholesale buyer'),
    ('Fatima Tiles Shop', '07708887777', 'Erbil, Ankawa', 0, 1000000, 7, 'Small retail shop'),
    ('Baghdad Royal Hotel', '07701112222', 'Baghdad, Jadiriyah', 4500000, 10000000, 45, 'Large hotel renovation project'),
    ('Noor Contracting', '07703334444', 'Najaf, City Center', 350000, 2000000, 30, 'New customer, building projects'),
    ('Zain Interiors', '07706665555', 'Sulaymaniyah', 0, 500000, 7, 'Cash customer mostly')
ON CONFLICT DO NOTHING;

-- ============================================================
-- Suppliers
-- ============================================================
INSERT INTO suppliers (supplier_name, phone_number, address, current_balance, payment_terms, notes) VALUES
    ('RAK Ceramics Iraq', '07801234567', 'UAE - Dubai Office', 8500000, 60, 'Main supplier for premium tiles'),
    ('China Tiles Import Co.', '07809876543', 'Guangzhou, China', 3200000, 45, 'Budget and mid-range tiles'),
    ('Turkish Ceramic Factory', '07805551234', 'Istanbul, Turkey', 5000000, 30, 'Porcelain and decorative tiles'),
    ('Local Adhesive Factory', '07808887777', 'Baghdad Industrial Zone', 450000, 15, 'Adhesive and grout supplier'),
    ('Italian Marble Imports', '07801112222', 'Milan, Italy', 12000000, 90, 'Premium marble-look porcelain')
ON CONFLICT DO NOTHING;

-- ============================================================
-- Opening Stock (Inventory Transactions)
-- ============================================================
INSERT INTO inventory_transactions (product_id, warehouse_id, transaction_type, direction, quantity, unit_type, cost_per_unit, notes, created_by) VALUES
    (1, 1, 'opening_stock', 'IN', 250.0000, 'meter', 8500, 'Opening stock - Royal Gold', 1),
    (1, 2, 'opening_stock', 'IN', 80.0000, 'meter', 8500, 'Opening stock - Royal Gold (secondary)', 1),
    (2, 1, 'opening_stock', 'IN', 400.0000, 'meter', 4500, 'Opening stock - Classic White', 1),
    (3, 1, 'opening_stock', 'IN', 120.0000, 'meter', 15000, 'Opening stock - Marble Effect', 1),
    (4, 1, 'opening_stock', 'IN', 500.0000, 'piece', 3500, 'Opening stock - Mosaic Decorative', 1),
    (5, 1, 'opening_stock', 'IN', 200.0000, 'piece', 12000, 'Opening stock - Tile Adhesive', 1),
    (5, 2, 'opening_stock', 'IN', 50.0000, 'piece', 12000, 'Opening stock - Tile Adhesive (secondary)', 1),
    (6, 1, 'opening_stock', 'IN', 180.0000, 'meter', 6000, 'Opening stock - Blue Ocean', 1),
    (7, 1, 'opening_stock', 'IN', 90.0000, 'meter', 18000, 'Opening stock - Granite Look', 1),
    (8, 1, 'opening_stock', 'IN', 150.0000, 'meter', 14000, 'Opening stock - Rustic Wood', 1),
    (9, 1, 'opening_stock', 'IN', 300.0000, 'piece', 2000, 'Opening stock - Border Strip', 1),
    (10, 1, 'opening_stock', 'IN', 100.0000, 'piece', 5000, 'Opening stock - Tile Grout', 1),
    (11, 1, 'opening_stock', 'IN', 200.0000, 'meter', 5500, 'Opening stock - Beige Matte', 1),
    (12, 1, 'opening_stock', 'IN', 150.0000, 'piece', 8000, 'Opening stock - Hexagon Mosaic', 1);

-- ============================================================
-- Purchase Invoices
-- ============================================================
INSERT INTO purchase_invoices (supplier_id, invoice_number, purchase_date, total_amount, paid_amount, remaining_amount, payment_status, notes) VALUES
    (1, 'PI-2026-001', '2026-05-01', 5100000, 2000000, 3100000, 'partial', 'RAK Ceramics monthly order'),
    (2, 'PI-2026-002', '2026-05-05', 2700000, 2700000, 0, 'paid', 'China Tiles bulk order'),
    (3, 'PI-2026-003', '2026-05-10', 4200000, 0, 4200000, 'unpaid', 'Turkish porcelain shipment'),
    (4, 'PI-2026-004', '2026-05-15', 960000, 960000, 0, 'paid', 'Adhesive and grout restock'),
    (1, 'PI-2026-005', '2026-05-20', 3600000, 1800000, 1800000, 'partial', 'RAK premium collection');

-- ============================================================
-- Purchase Invoice Items
-- ============================================================
INSERT INTO purchase_invoice_items (purchase_invoice_id, product_id, purchased_quantity, purchase_price, total_cost) VALUES
    (1, 1, 200.0000, 8500, 1700000),
    (1, 3, 100.0000, 15000, 1500000),
    (1, 7, 50.0000, 18000, 900000),
    (1, 11, 100.0000, 5500, 550000),
    (2, 2, 300.0000, 4500, 1350000),
    (2, 6, 150.0000, 6000, 900000),
    (2, 11, 100.0000, 4500, 450000),
    (3, 8, 150.0000, 14000, 2100000),
    (3, 3, 80.0000, 15000, 1200000),
    (3, 12, 100.0000, 9000, 900000),
    (4, 5, 60.0000, 12000, 720000),
    (4, 10, 48.0000, 5000, 240000),
    (5, 1, 150.0000, 8500, 1275000),
    (5, 7, 75.0000, 18000, 1350000),
    (5, 9, 200.0000, 2000, 400000);

-- Record purchase transactions in inventory
INSERT INTO inventory_transactions (product_id, warehouse_id, transaction_type, direction, quantity, unit_type, cost_per_unit, reference_type, reference_id, created_by) VALUES
    (1, 1, 'purchase', 'IN', 200.0000, 'meter', 8500, 'purchase_invoice', 1, 1),
    (3, 1, 'purchase', 'IN', 100.0000, 'meter', 15000, 'purchase_invoice', 1, 1),
    (7, 1, 'purchase', 'IN', 50.0000, 'meter', 18000, 'purchase_invoice', 1, 1),
    (2, 1, 'purchase', 'IN', 300.0000, 'meter', 4500, 'purchase_invoice', 2, 1),
    (6, 1, 'purchase', 'IN', 150.0000, 'meter', 6000, 'purchase_invoice', 2, 1),
    (8, 1, 'purchase', 'IN', 150.0000, 'meter', 14000, 'purchase_invoice', 3, 1),
    (5, 1, 'purchase', 'IN', 60.0000, 'piece', 12000, 'purchase_invoice', 4, 1),
    (10, 1, 'purchase', 'IN', 48.0000, 'piece', 5000, 'purchase_invoice', 4, 1),
    (1, 1, 'purchase', 'IN', 150.0000, 'meter', 8500, 'purchase_invoice', 5, 1),
    (7, 1, 'purchase', 'IN', 75.0000, 'meter', 18000, 'purchase_invoice', 5, 1);

-- ============================================================
-- Sales Invoices
-- ============================================================
INSERT INTO sales_invoices (customer_id, invoice_number, invoice_type, invoice_date, total_amount, discount_amount, paid_amount, remaining_amount, payment_status, warehouse_id, notes) VALUES
    (1, 'INV-2026-0001', 'credit', '2026-05-02', 3360000, 0, 1000000, 2360000, 'partial', 1, 'Ahmed Construction - floor tiles'),
    (2, 'INV-2026-0002', 'cash', '2026-05-03', 1050000, 50000, 1050000, 0, 'paid', 1, 'Ali Home Decor - wall tiles'),
    (5, 'INV-2026-0003', 'credit', '2026-05-07', 8910000, 0, 4000000, 4910000, 'partial', 1, 'Baghdad Royal Hotel - large order'),
    (3, 'INV-2026-0004', 'credit', '2026-05-10', 2160000, 0, 0, 2160000, 'unpaid', 1, 'Hassan Building - wholesale'),
    (4, 'INV-2026-0005', 'cash', '2026-05-12', 440000, 0, 440000, 0, 'paid', 1, 'Fatima Tiles - small order'),
    (6, 'INV-2026-0006', 'credit', '2026-05-15', 1800000, 0, 900000, 900000, 'partial', 1, 'Noor Contracting - project supply'),
    (1, 'INV-2026-0007', 'credit', '2026-05-18', 2700000, 0, 2700000, 0, 'paid', 1, 'Ahmed Construction - porcelain'),
    (7, 'INV-2026-0008', 'cash', '2026-05-20', 585000, 15000, 585000, 0, 'paid', 1, 'Zain Interiors - decor tiles'),
    (2, 'INV-2026-0009', 'cash', '2026-05-22', 720000, 0, 720000, 0, 'paid', 1, 'Ali Home Decor - reorder'),
    (5, 'INV-2026-0010', 'credit', '2026-05-24', 5400000, 0, 2000000, 3400000, 'partial', 1, 'Baghdad Royal Hotel - phase 2');

-- ============================================================
-- Sales Invoice Items
-- ============================================================
INSERT INTO sales_invoice_items (invoice_id, product_id, sold_quantity, unit_type, unit_price, cost_at_sale, discount, total_price) VALUES
    (1, 1, 120.0000, 'meter', 12000, 8500, 0, 1440000),
    (1, 11, 80.0000, 'meter', 8500, 5500, 0, 680000),
    (1, 5, 20.0000, 'piece', 18000, 12000, 0, 360000),
    (1, 10, 10.0000, 'piece', 8000, 5000, 0, 80000),
    (2, 2, 100.0000, 'meter', 7000, 4500, 0, 700000),
    (2, 6, 50.0000, 'meter', 9500, 6000, 50000, 425000),
    (3, 3, 80.0000, 'meter', 22000, 15000, 0, 1760000),
    (3, 7, 90.0000, 'meter', 27000, 18000, 0, 2430000),
    (3, 8, 100.0000, 'meter', 20000, 14000, 0, 2000000),
    (3, 1, 60.0000, 'meter', 12000, 8500, 0, 720000),
    (3, 12, 100.0000, 'piece', 13000, 8000, 0, 1300000),
    (3, 5, 50.0000, 'piece', 18000, 12000, 0, 900000),
    (4, 2, 200.0000, 'meter', 7000, 4500, 0, 1400000),
    (4, 6, 80.0000, 'meter', 9500, 6000, 0, 760000),
    (5, 4, 50.0000, 'piece', 5500, 3500, 0, 275000),
    (5, 9, 30.0000, 'piece', 3500, 2000, 0, 105000),
    (5, 10, 5.0000, 'piece', 8000, 5000, 0, 40000),
    (6, 1, 100.0000, 'meter', 12000, 8500, 0, 1200000),
    (6, 5, 30.0000, 'piece', 18000, 12000, 0, 540000),
    (7, 3, 50.0000, 'meter', 22000, 15000, 0, 1100000),
    (7, 7, 40.0000, 'meter', 27000, 18000, 0, 1080000),
    (7, 8, 30.0000, 'meter', 20000, 14000, 0, 600000),
    (8, 4, 30.0000, 'piece', 5500, 3500, 0, 165000),
    (8, 12, 20.0000, 'piece', 13000, 8000, 0, 260000),
    (8, 9, 50.0000, 'piece', 3500, 2000, 15000, 160000),
    (9, 6, 80.0000, 'meter', 9500, 6000, 0, 760000),
    (10, 3, 100.0000, 'meter', 22000, 15000, 0, 2200000),
    (10, 7, 60.0000, 'meter', 27000, 18000, 0, 1620000),
    (10, 8, 80.0000, 'meter', 20000, 14000, 0, 1600000);

-- Record sales in inventory (OUT transactions)
INSERT INTO inventory_transactions (product_id, warehouse_id, transaction_type, direction, quantity, unit_type, cost_per_unit, reference_type, reference_id, created_by) VALUES
    (1, 1, 'sale', 'OUT', 120.0000, 'meter', 8500, 'sales_invoice', 1, 2),
    (11, 1, 'sale', 'OUT', 80.0000, 'meter', 5500, 'sales_invoice', 1, 2),
    (2, 1, 'sale', 'OUT', 100.0000, 'meter', 4500, 'sales_invoice', 2, 2),
    (6, 1, 'sale', 'OUT', 50.0000, 'meter', 6000, 'sales_invoice', 2, 2),
    (3, 1, 'sale', 'OUT', 80.0000, 'meter', 15000, 'sales_invoice', 3, 2),
    (7, 1, 'sale', 'OUT', 90.0000, 'meter', 18000, 'sales_invoice', 3, 2),
    (8, 1, 'sale', 'OUT', 100.0000, 'meter', 14000, 'sales_invoice', 3, 2),
    (1, 1, 'sale', 'OUT', 60.0000, 'meter', 8500, 'sales_invoice', 3, 2),
    (2, 1, 'sale', 'OUT', 200.0000, 'meter', 4500, 'sales_invoice', 4, 2),
    (6, 1, 'sale', 'OUT', 80.0000, 'meter', 6000, 'sales_invoice', 4, 2),
    (1, 1, 'sale', 'OUT', 100.0000, 'meter', 8500, 'sales_invoice', 6, 2),
    (3, 1, 'sale', 'OUT', 50.0000, 'meter', 15000, 'sales_invoice', 7, 2),
    (7, 1, 'sale', 'OUT', 40.0000, 'meter', 18000, 'sales_invoice', 7, 2),
    (3, 1, 'sale', 'OUT', 100.0000, 'meter', 15000, 'sales_invoice', 10, 2),
    (7, 1, 'sale', 'OUT', 60.0000, 'meter', 18000, 'sales_invoice', 10, 2),
    (8, 1, 'sale', 'OUT', 80.0000, 'meter', 14000, 'sales_invoice', 10, 2);

-- ============================================================
-- Customer Payments
-- ============================================================
INSERT INTO customer_payments (customer_id, related_invoice_id, payment_amount, payment_date, notes) VALUES
    (1, 1, 1000000, '2026-05-05', 'Partial payment - check #4521'),
    (5, 3, 4000000, '2026-05-12', 'Wire transfer - first installment'),
    (6, 6, 900000, '2026-05-18', 'Cash payment'),
    (1, 7, 2700000, '2026-05-19', 'Full payment - bank transfer'),
    (5, 10, 2000000, '2026-05-24', 'Phase 2 advance payment');

-- ============================================================
-- Cash Transactions
-- ============================================================
INSERT INTO cash_transactions (transaction_type, amount, entity_type, entity_id, description, created_by, transaction_date) VALUES
    ('cash_in', 15000000, 'opening_balance', 0, 'Opening cash balance', 1, '2026-05-01'),
    ('cash_in', 1050000, 'sales_invoice', 2, 'Cash sale - Ali Home Decor', 2, '2026-05-03'),
    ('cash_in', 1000000, 'customer_payment', 1, 'Ahmed Construction partial payment', 2, '2026-05-05'),
    ('cash_out', 2700000, 'purchase_invoice', 2, 'China Tiles payment', 1, '2026-05-06'),
    ('cash_in', 4000000, 'customer_payment', 2, 'Baghdad Royal Hotel payment', 2, '2026-05-12'),
    ('cash_in', 440000, 'sales_invoice', 5, 'Cash sale - Fatima Tiles', 2, '2026-05-12'),
    ('cash_out', 960000, 'purchase_invoice', 4, 'Local Adhesive Factory payment', 1, '2026-05-14'),
    ('cash_in', 900000, 'customer_payment', 3, 'Noor Contracting payment', 2, '2026-05-18'),
    ('cash_in', 2700000, 'customer_payment', 4, 'Ahmed Construction full payment', 2, '2026-05-19'),
    ('cash_in', 585000, 'sales_invoice', 8, 'Cash sale - Zain Interiors', 2, '2026-05-20'),
    ('cash_out', 2000000, 'purchase_invoice', 1, 'RAK Ceramics partial payment', 1, '2026-05-20'),
    ('cash_in', 720000, 'sales_invoice', 9, 'Cash sale - Ali Home Decor', 2, '2026-05-22'),
    ('cash_out', 1800000, 'purchase_invoice', 5, 'RAK premium collection payment', 1, '2026-05-23'),
    ('cash_in', 2000000, 'customer_payment', 5, 'Baghdad Royal Hotel phase 2', 2, '2026-05-24');

-- ============================================================
-- Expenses
-- ============================================================
INSERT INTO expenses (expense_category, expense_name, amount, payment_method, paid_by, expense_date, notes, created_by) VALUES
    ('Rent', 'Showroom rent - May 2026', 3000000, 'bank', 'Ahmed Ali', '2026-05-01', 'Monthly showroom rent', 1),
    ('Salaries', 'Staff salaries - May 2026', 8500000, 'bank', 'Ahmed Ali', '2026-05-01', '4 employees', 1),
    ('Electricity', 'Electricity bill - April', 450000, 'cash', 'Mohammed Hassan', '2026-05-03', 'April bill paid in May', 2),
    ('Water', 'Water bill - April', 75000, 'cash', 'Mohammed Hassan', '2026-05-03', NULL, 2),
    ('Internet', 'Internet + phone - May', 120000, 'bank', 'Ahmed Ali', '2026-05-05', 'Fiber internet + landline', 1),
    ('Transport', 'Delivery truck fuel', 350000, 'cash', 'Omar Nasser', '2026-05-08', 'Weekly fuel', 4),
    ('Maintenance', 'AC repair - showroom', 250000, 'cash', 'Ahmed Ali', '2026-05-10', 'Unit #3 compressor replacement', 1),
    ('Transport', 'Customer delivery - Basra', 180000, 'cash', 'Omar Nasser', '2026-05-12', 'Hassan Building delivery', 4),
    ('Packaging', 'Packaging materials', 95000, 'cash', 'Omar Nasser', '2026-05-14', 'Foam wraps and cardboard', 4),
    ('Marketing', 'Facebook ads - May', 200000, 'bank', 'Sara Khalid', '2026-05-15', 'Social media campaign', 3),
    ('Transport', 'Delivery truck fuel', 320000, 'cash', 'Omar Nasser', '2026-05-15', 'Weekly fuel', 4),
    ('Electricity', 'Warehouse electricity', 280000, 'cash', 'Mohammed Hassan', '2026-05-18', 'Secondary warehouse', 2),
    ('Miscellaneous', 'Office supplies', 45000, 'cash', 'Sara Khalid', '2026-05-19', 'Paper, pens, printer ink', 3),
    ('Transport', 'Customer delivery - Erbil', 450000, 'cash', 'Omar Nasser', '2026-05-20', 'Fatima Tiles delivery', 4),
    ('Maintenance', 'Forklift service', 180000, 'cash', 'Omar Nasser', '2026-05-22', 'Annual maintenance', 4),
    ('Transport', 'Delivery truck fuel', 290000, 'cash', 'Omar Nasser', '2026-05-22', 'Weekly fuel', 4),
    ('Marketing', 'Showroom signage update', 350000, 'cash', 'Ahmed Ali', '2026-05-23', 'New LED sign', 1);

-- Record expense cash-outs
INSERT INTO cash_transactions (transaction_type, amount, entity_type, entity_id, description, created_by, transaction_date) VALUES
    ('cash_out', 3000000, 'expense', 1, 'Rent - May', 1, '2026-05-01'),
    ('cash_out', 8500000, 'expense', 2, 'Salaries - May', 1, '2026-05-01'),
    ('cash_out', 450000, 'expense', 3, 'Electricity', 2, '2026-05-03'),
    ('cash_out', 75000, 'expense', 4, 'Water', 2, '2026-05-03'),
    ('cash_out', 120000, 'expense', 5, 'Internet', 1, '2026-05-05'),
    ('cash_out', 350000, 'expense', 6, 'Transport fuel', 4, '2026-05-08'),
    ('cash_out', 250000, 'expense', 7, 'AC repair', 1, '2026-05-10'),
    ('cash_out', 180000, 'expense', 8, 'Delivery Basra', 4, '2026-05-12'),
    ('cash_out', 95000, 'expense', 9, 'Packaging', 4, '2026-05-14'),
    ('cash_out', 200000, 'expense', 10, 'Facebook ads', 3, '2026-05-15'),
    ('cash_out', 320000, 'expense', 11, 'Transport fuel', 4, '2026-05-15'),
    ('cash_out', 280000, 'expense', 12, 'Warehouse electricity', 2, '2026-05-18'),
    ('cash_out', 45000, 'expense', 13, 'Office supplies', 3, '2026-05-19'),
    ('cash_out', 450000, 'expense', 14, 'Delivery Erbil', 4, '2026-05-20'),
    ('cash_out', 180000, 'expense', 15, 'Forklift service', 4, '2026-05-22'),
    ('cash_out', 290000, 'expense', 16, 'Transport fuel', 4, '2026-05-22'),
    ('cash_out', 350000, 'expense', 17, 'Signage', 1, '2026-05-23');

-- ============================================================
-- Ledger Entries (Double-Entry for major transactions)
-- ============================================================
-- Opening balance entries
INSERT INTO ledger_entries (account_id, debit, credit, entity_type, entity_id, description) VALUES
    (1, 15000000, 0, 'opening_balance', 0, 'Opening cash balance'),
    (5, 0, 15000000, 'opening_balance', 0, 'Owner equity from opening cash'),
    (2, 2500000, 0, 'opening_balance', 1, 'Opening balance (receivable) for customer: Ahmed Construction Co.'),
    (2, 850000, 0, 'opening_balance', 2, 'Opening balance (receivable) for customer: Ali Home Decor'),
    (2, 1200000, 0, 'opening_balance', 3, 'Opening balance (receivable) for customer: Hassan Building Materials'),
    (2, 4500000, 0, 'opening_balance', 5, 'Opening balance (receivable) for customer: Baghdad Royal Hotel'),
    (4, 0, 8500000, 'opening_balance', 1, 'Opening balance (payable) for supplier: RAK Ceramics Iraq'),
    (4, 0, 3200000, 'opening_balance', 2, 'Opening balance (payable) for supplier: China Tiles Import Co.'),
    (4, 0, 5000000, 'opening_balance', 3, 'Opening balance (payable) for supplier: Turkish Ceramic Factory'),
    (4, 0, 450000, 'opening_balance', 4, 'Opening balance (payable) for supplier: Local Adhesive Factory');

-- Sales revenue entries
INSERT INTO ledger_entries (account_id, debit, credit, entity_type, entity_id, description) VALUES
    (1, 1050000, 0, 'sales_invoice', 2, 'Cash from sale'),
    (6, 0, 1050000, 'sales_invoice', 2, 'Sales revenue'),
    (2, 3360000, 0, 'sales_invoice', 1, 'Credit sale receivable'),
    (6, 0, 3360000, 'sales_invoice', 1, 'Sales revenue'),
    (2, 8910000, 0, 'sales_invoice', 3, 'Credit sale receivable'),
    (6, 0, 8910000, 'sales_invoice', 3, 'Sales revenue'),
    (1, 440000, 0, 'sales_invoice', 5, 'Cash from sale'),
    (6, 0, 440000, 'sales_invoice', 5, 'Sales revenue'),
    (1, 585000, 0, 'sales_invoice', 8, 'Cash from sale'),
    (6, 0, 585000, 'sales_invoice', 8, 'Sales revenue');

-- Expense entries
INSERT INTO ledger_entries (account_id, debit, credit, entity_type, entity_id, description) VALUES
    (10, 3000000, 0, 'expense', 1, 'Expense: Rent'),
    (1, 0, 3000000, 'expense', 1, 'Cash out: Rent'),
    (10, 8500000, 0, 'expense', 2, 'Expense: Salaries'),
    (1, 0, 8500000, 'expense', 2, 'Cash out: Salaries'),
    (10, 450000, 0, 'expense', 3, 'Expense: Electricity'),
    (1, 0, 450000, 'expense', 3, 'Cash out: Electricity'),
    (10, 350000, 0, 'expense', 6, 'Expense: Transport'),
    (1, 0, 350000, 'expense', 6, 'Cash out: Transport'),
    (10, 250000, 0, 'expense', 7, 'Expense: Maintenance'),
    (1, 0, 250000, 'expense', 7, 'Cash out: Maintenance');

-- ============================================================
-- Supplier Payments
-- ============================================================
INSERT INTO supplier_payments (supplier_id, related_purchase_invoice_id, payment_amount, payment_date, notes) VALUES
    (2, 2, 2700000, '2026-05-06', 'Full payment - wire transfer'),
    (4, 4, 960000, '2026-05-14', 'Full payment - cash'),
    (1, 1, 2000000, '2026-05-20', 'Partial payment - check'),
    (1, 5, 1800000, '2026-05-23', 'Partial payment - bank transfer');

-- ============================================================
-- Daily Financial Summary (precomputed for dashboard)
-- ============================================================
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
    ('2026-05-24', 5400000, 3740000, 1660000, 0, 1660000, 1, 0)
ON CONFLICT (summary_date) DO UPDATE SET
    revenue = EXCLUDED.revenue,
    cogs = EXCLUDED.cogs,
    gross_profit = EXCLUDED.gross_profit,
    expenses = EXCLUDED.expenses,
    net_profit = EXCLUDED.net_profit,
    sales_count = EXCLUDED.sales_count;
