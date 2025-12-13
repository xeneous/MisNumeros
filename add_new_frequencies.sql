-- EJECUTAR EN SUPABASE SQL EDITOR
-- Agregar soporte para frecuencias Bimestral y Única vez

-- 1. Agregar columna due_date para gastos de única vez
ALTER TABLE fixed_expenses
ADD COLUMN IF NOT EXISTS due_date DATE;

-- 2. Crear comentario para la nueva columna
COMMENT ON COLUMN fixed_expenses.due_date IS 'Fecha de vencimiento para gastos de única vez';

-- 3. Ver constraint actual de frequency
SELECT pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conname = 'fixed_expenses_frequency_check';

-- 4. Eliminar constraint viejo de frequency si existe
ALTER TABLE fixed_expenses
DROP CONSTRAINT IF EXISTS fixed_expenses_frequency_check;

-- 5. Crear nuevo constraint que acepta las 4 frecuencias
ALTER TABLE fixed_expenses
ADD CONSTRAINT fixed_expenses_frequency_check
CHECK (frequency IN ('weekly', 'monthly', 'bimonthly', 'oneTime'));

-- 6. Crear constraint para validar que due_date es requerido para one_time
ALTER TABLE fixed_expenses
ADD CONSTRAINT fixed_expenses_due_date_check
CHECK (
  (frequency = 'oneTime' AND due_date IS NOT NULL) OR
  (frequency != 'oneTime' AND due_date IS NULL)
);

-- 7. Verificar que funcionó
SELECT
  table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'fixed_expenses'
  AND column_name IN ('frequency', 'due_date')
ORDER BY ordinal_position;

-- 8. Ver los constraints
SELECT
  conname AS constraint_name,
  pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'fixed_expenses'::regclass
  AND conname LIKE '%frequency%' OR conname LIKE '%due_date%';
