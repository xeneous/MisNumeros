-- EJECUTAR EN SUPABASE SQL EDITOR
-- Ver las constraints de la tabla fixed_expenses

SELECT
  conname AS constraint_name,
  contype AS constraint_type,
  pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'fixed_expenses'::regclass
ORDER BY conname;

-- Ver la estructura de la tabla
SELECT
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'fixed_expenses'
ORDER BY ordinal_position;
