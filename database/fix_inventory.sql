-- Fix: Add missing purchase inventory transactions that caused negative stock
-- Products 3, 11, 12 had purchase invoice items but no matching inventory IN transactions

INSERT INTO inventory_transactions (product_id, warehouse_id, transaction_type, direction, quantity, unit_type, cost_per_unit, reference_type, reference_id, created_by) VALUES
    (11, 1, 'purchase', 'IN', 100, 'meter', 4500, 'purchase_invoice', 2, 1),
    (3, 1, 'purchase', 'IN', 80, 'meter', 15000, 'purchase_invoice', 3, 1),
    (12, 1, 'purchase', 'IN', 100, 'piece', 9000, 'purchase_invoice', 3, 1);
