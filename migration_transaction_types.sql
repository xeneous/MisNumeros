-- ============================================
-- MIGRATION: Transaction Types & Account Purpose
-- Description:
--   1. Create transaction_types table with income/expense logic
--   2. Add account_purpose to accounts (available vs savings)
--   3. Migrate existing transactions to use transaction_type_id
--   4. Create helper functions for balance calculations
-- ============================================

-- STEP 1: Create transaction_types table
CREATE TABLE IF NOT EXISTS transaction_types (
  id INTEGER PRIMARY KEY,
  name VARCHAR(50) NOT NULL UNIQUE,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert standard transaction types
-- Rule: ODD ids = income (suma), EVEN ids = expense (resta)
INSERT INTO transaction_types (id, name, description) VALUES
(1, 'income', 'Ingreso regular (salario, ventas, etc.)'),
(2, 'expense', 'Gasto regular (compras, servicios, etc.)'),
(11, 'transfer_in', 'Ingreso por transferencia entre cuentas propias'),
(12, 'transfer_out', 'Egreso por transferencia entre cuentas propias')
ON CONFLICT (id) DO NOTHING;

-- STEP 2: Add account_purpose to accounts table
ALTER TABLE accounts
ADD COLUMN IF NOT EXISTS account_purpose VARCHAR(20) DEFAULT 'available';

COMMENT ON COLUMN accounts.account_purpose IS 'Propósito de la cuenta: available (liquidez/disponible) o savings (ahorro/reserva)';

-- Update existing accounts to 'available' if NULL
UPDATE accounts SET account_purpose = 'available' WHERE account_purpose IS NULL;

-- STEP 3: Migrate transactions table
-- Add new columns
ALTER TABLE transactions
ADD COLUMN IF NOT EXISTS transaction_type_id INTEGER REFERENCES transaction_types(id),
ADD COLUMN IF NOT EXISTS destination_account_id UUID REFERENCES accounts(id);

COMMENT ON COLUMN transactions.transaction_type_id IS 'Tipo de transacción: impar=ingreso, par=egreso';
COMMENT ON COLUMN transactions.destination_account_id IS 'Cuenta destino para transferencias';

-- Migrate existing data: transaction_type (string) -> transaction_type_id (integer)
UPDATE transactions
SET transaction_type_id = CASE
  WHEN transaction_type = 'income' THEN 1
  WHEN transaction_type = 'expense' THEN 2
  ELSE 2  -- Default to expense for unknown types
END
WHERE transaction_type_id IS NULL;

-- Make transaction_type_id NOT NULL after migration
ALTER TABLE transactions
ALTER COLUMN transaction_type_id SET NOT NULL;

-- Add constraint to ensure amount is always positive
ALTER TABLE transactions
ADD CONSTRAINT positive_amount CHECK (amount > 0);

-- STEP 4: Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_transactions_account_type
ON transactions(account_id, transaction_type_id);

CREATE INDEX IF NOT EXISTS idx_transactions_user_date
ON transactions(user_id, transaction_date DESC);

CREATE INDEX IF NOT EXISTS idx_accounts_user_purpose
ON accounts(user_id, account_purpose);

-- STEP 5: Create helper function to calculate account balance
CREATE OR REPLACE FUNCTION get_account_balance(p_account_id UUID)
RETURNS NUMERIC AS $$
  SELECT
    COALESCE(a.initial_balance, 0) + COALESCE(SUM(
      CASE
        WHEN t.transaction_type_id % 2 = 1 THEN t.amount  -- Odd = income (add)
        ELSE -t.amount  -- Even = expense (subtract)
      END
    ), 0) as balance
  FROM accounts a
  LEFT JOIN transactions t ON t.account_id = a.id
  WHERE a.id = p_account_id
  GROUP BY a.id, a.initial_balance
$$ LANGUAGE SQL STABLE;

COMMENT ON FUNCTION get_account_balance(UUID) IS 'Calcula el balance de una cuenta sumando initial_balance + transacciones (impares suman, pares restan)';

-- STEP 6: Create function to get available balance (only 'available' accounts)
CREATE OR REPLACE FUNCTION get_available_balance(p_user_id UUID, p_currency VARCHAR(10) DEFAULT NULL)
RETURNS NUMERIC AS $$
  SELECT
    COALESCE(SUM(
      a.initial_balance + COALESCE((
        SELECT SUM(
          CASE
            WHEN t.transaction_type_id % 2 = 1 THEN t.amount
            ELSE -t.amount
          END
        )
        FROM transactions t
        WHERE t.account_id = a.id
      ), 0)
    ), 0) as total_available
  FROM accounts a
  WHERE a.user_id = p_user_id
    AND a.account_purpose = 'available'
    AND (p_currency IS NULL OR a.currency = p_currency)
$$ LANGUAGE SQL STABLE;

COMMENT ON FUNCTION get_available_balance(UUID, VARCHAR) IS 'Calcula el balance total disponible (solo cuentas con purpose=available)';

-- STEP 7: Create function to get savings balance
CREATE OR REPLACE FUNCTION get_savings_balance(p_user_id UUID, p_currency VARCHAR(10) DEFAULT NULL)
RETURNS NUMERIC AS $$
  SELECT
    COALESCE(SUM(
      a.initial_balance + COALESCE((
        SELECT SUM(
          CASE
            WHEN t.transaction_type_id % 2 = 1 THEN t.amount
            ELSE -t.amount
          END
        )
        FROM transactions t
        WHERE t.account_id = a.id
      ), 0)
    ), 0) as total_savings
  FROM accounts a
  WHERE a.user_id = p_user_id
    AND a.account_purpose = 'savings'
    AND (p_currency IS NULL OR a.currency = p_currency)
$$ LANGUAGE SQL STABLE;

COMMENT ON FUNCTION get_savings_balance(UUID, VARCHAR) IS 'Calcula el balance total en ahorro (solo cuentas con purpose=savings)';

-- STEP 8: Create view for account balances (materialized for performance)
CREATE OR REPLACE VIEW account_balances AS
SELECT
  a.id,
  a.user_id,
  a.name,
  a.account_type,
  a.currency,
  a.account_purpose,
  a.initial_balance,
  COALESCE(a.initial_balance, 0) + COALESCE(SUM(
    CASE
      WHEN t.transaction_type_id % 2 = 1 THEN t.amount
      ELSE -t.amount
    END
  ), 0) as current_balance,
  a.created_at,
  a.updated_at
FROM accounts a
LEFT JOIN transactions t ON t.account_id = a.id
GROUP BY a.id, a.user_id, a.name, a.account_type, a.currency, a.account_purpose, a.initial_balance, a.created_at, a.updated_at;

COMMENT ON VIEW account_balances IS 'Vista que muestra el balance calculado de cada cuenta';

-- STEP 9: Optional - Drop old transaction_type column (only after confirming migration works)
-- UNCOMMENT AFTER TESTING:
-- ALTER TABLE transactions DROP COLUMN IF EXISTS transaction_type;

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Check transaction types
-- SELECT * FROM transaction_types ORDER BY id;

-- Check accounts with new purpose field
-- SELECT id, name, account_purpose, currency FROM accounts WHERE user_id = 'YOUR_USER_ID';

-- Test balance calculation for a specific account
-- SELECT get_account_balance('YOUR_ACCOUNT_ID');

-- Test available balance for a user
-- SELECT get_available_balance('YOUR_USER_ID', 'ARS');

-- View all account balances
-- SELECT * FROM account_balances WHERE user_id = 'YOUR_USER_ID';
