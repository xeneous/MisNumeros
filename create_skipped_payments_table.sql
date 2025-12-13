-- EJECUTAR EN SUPABASE SQL EDITOR
-- Crear tabla para registrar pagos de gastos fijos que fueron salteados

-- 1. Crear la tabla skipped_payments
CREATE TABLE IF NOT EXISTS skipped_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fixed_expense_id UUID NOT NULL REFERENCES fixed_expenses(id) ON DELETE CASCADE,
  skipped_date DATE NOT NULL,
  reason TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

  -- Evitar duplicados: no se puede saltear el mismo gasto en la misma fecha dos veces
  UNIQUE(fixed_expense_id, skipped_date)
);

-- 2. Crear índices para mejor performance
CREATE INDEX idx_skipped_payments_user_id ON skipped_payments(user_id);
CREATE INDEX idx_skipped_payments_fixed_expense_id ON skipped_payments(fixed_expense_id);
CREATE INDEX idx_skipped_payments_skipped_date ON skipped_payments(skipped_date);

-- 3. Habilitar RLS (Row Level Security)
ALTER TABLE skipped_payments ENABLE ROW LEVEL SECURITY;

-- 4. Crear políticas de RLS
-- Usuarios solo pueden ver sus propios registros
CREATE POLICY "Users can view their own skipped payments"
  ON skipped_payments FOR SELECT
  USING (auth.uid() = user_id);

-- Usuarios solo pueden insertar sus propios registros
CREATE POLICY "Users can insert their own skipped payments"
  ON skipped_payments FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Usuarios solo pueden actualizar sus propios registros
CREATE POLICY "Users can update their own skipped payments"
  ON skipped_payments FOR UPDATE
  USING (auth.uid() = user_id);

-- Usuarios solo pueden eliminar sus propios registros
CREATE POLICY "Users can delete their own skipped payments"
  ON skipped_payments FOR DELETE
  USING (auth.uid() = user_id);

-- 5. Verificar que se creó correctamente
SELECT
  table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'skipped_payments'
ORDER BY ordinal_position;

-- 6. Función helper para verificar si un pago fue salteado
CREATE OR REPLACE FUNCTION is_payment_skipped(
  p_fixed_expense_id UUID,
  p_date DATE
)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1
    FROM skipped_payments
    WHERE fixed_expense_id = p_fixed_expense_id
      AND skipped_date = p_date
      AND user_id = auth.uid()
  );
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

-- Comentarios para documentación
COMMENT ON TABLE skipped_payments IS 'Registra cuando un usuario salta/pospone un pago de gasto fijo';
COMMENT ON COLUMN skipped_payments.fixed_expense_id IS 'ID del gasto fijo que se saltó';
COMMENT ON COLUMN skipped_payments.skipped_date IS 'Fecha en la que se saltó el pago';
COMMENT ON COLUMN skipped_payments.reason IS 'Razón opcional por la que se saltó el pago';
