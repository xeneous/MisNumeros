-- EJECUTAR ESTE SQL EN SUPABASE SQL EDITOR
-- Esto actualiza las cuentas existentes para que tengan account_purpose='available'

-- Actualizar todas las cuentas que tienen account_purpose NULL a 'available'
UPDATE accounts
SET account_purpose = 'available'
WHERE account_purpose IS NULL;

-- Verificar los resultados
SELECT
  id,
  name,
  account_purpose,
  moneda,
  initial_balance
FROM accounts
ORDER BY created_at DESC
LIMIT 10;
