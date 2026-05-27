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
