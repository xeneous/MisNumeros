-- EJECUTAR EN SUPABASE SQL EDITOR
-- Ver el constraint actual de day_of_week

SELECT pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conname = 'fixed_expenses_day_of_week_check';

-- Si el constraint está mal (ej: CHECK day_of_week >= 1 AND day_of_week <= 6)
-- Necesitamos cambiarlo para aceptar NULL y valores 1-7

-- OPCIÓN 1: Eliminar el constraint viejo y crear uno nuevo
ALTER TABLE fixed_expenses
DROP CONSTRAINT IF EXISTS fixed_expenses_day_of_week_check;

ALTER TABLE fixed_expenses
ADD CONSTRAINT fixed_expenses_day_of_week_check
CHECK (day_of_week IS NULL OR (day_of_week >= 1 AND day_of_week <= 7));

-- Verificar que funcionó
SELECT pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conname = 'fixed_expenses_day_of_week_check';
