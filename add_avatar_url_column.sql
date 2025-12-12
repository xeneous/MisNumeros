-- ============================================
-- Agregar columna avatar_url a la tabla users
-- ============================================
-- Ejecuta esto en el SQL Editor de Supabase:
-- https://supabase.com/dashboard/project/pqypiajsgunsurxpomol/sql/new
-- ============================================

-- Agregar la columna avatar_url si no existe
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Copiar datos de profile_image_url a avatar_url si existen
UPDATE public.users
SET avatar_url = profile_image_url
WHERE profile_image_url IS NOT NULL
  AND (avatar_url IS NULL OR avatar_url = '');

-- Verificar que la columna se agregó correctamente
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'users'
  AND column_name = 'avatar_url';

-- ============================================
-- Resultado esperado:
-- column_name  | data_type | is_nullable
-- avatar_url   | text      | YES
-- ============================================
