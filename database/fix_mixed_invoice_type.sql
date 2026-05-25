-- Fix: Allow 'mixed' invoice type in the check constraint
-- The frontend supports 'mixed' invoices (part cash, part credit) but the DB constraint only allowed 'cash' or 'credit'

ALTER TABLE sales_invoices DROP CONSTRAINT chk_credit_requires_customer;
ALTER TABLE sales_invoices ADD CONSTRAINT chk_credit_requires_customer
    CHECK (invoice_type = 'cash' OR (invoice_type IN ('credit', 'mixed') AND customer_id IS NOT NULL));
