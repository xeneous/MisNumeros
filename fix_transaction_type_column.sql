-- EJECUTAR ESTE SQL EN SUPABASE SQL EDITOR
-- Esto arregla el error: "null value in column transaction_type violates not-null constraint"

-- Paso 1: Eliminar la restricción NOT NULL de la columna vieja transaction_type
ALTER TABLE transactions
ALTER COLUMN transaction_type DROP NOT NULL;

-- Paso 2 (OPCIONAL - Recomendado): Eliminar completamente la columna vieja
-- Esto es seguro porque ya estamos usando transaction_type_id
-- Puedes comentar esta línea si prefieres mantener la columna por ahora
ALTER TABLE transactions
DROP COLUMN IF EXISTS transaction_type;

-- Verificar que todo funcione
SELECT
  id,
  transaction_type_id,
  amount,
  description,
  account_id
FROM transactions
LIMIT 5;
