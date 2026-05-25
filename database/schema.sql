    CONSTRAINT chk_credit_requires_customer CHECK (invoice_type = 'cash' OR (invoice_type IN ('credit', 'mixed') AND customer_id IS NOT NULL))
