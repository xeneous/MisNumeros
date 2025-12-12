-- ============================================
-- HABILITAR ROW LEVEL SECURITY (RLS)
-- ============================================
-- Ejecuta este script DESPUÉS de que el login funcione
-- para re-activar la seguridad en la tabla users
-- ============================================

-- 1. HABILITAR Row Level Security
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- 2. Eliminar políticas existentes (si las hay)
DROP POLICY IF EXISTS "Users can read their own data" ON public.users;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.users;
DROP POLICY IF EXISTS "Users can update their own data" ON public.users;

-- 3. CREAR POLÍTICAS CORRECTAS

-- Política SELECT: Los usuarios pueden leer solo su propia información
CREATE POLICY "Users can read their own data"
ON public.users
FOR SELECT
TO authenticated
USING (auth.uid() = id);

-- Política INSERT: Usuarios autenticados pueden crear su registro
-- IMPORTANTE: TO authenticated + WITH CHECK permite al trigger funcionar
CREATE POLICY "Enable insert for authenticated users only"
ON public.users
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- Política UPDATE: Los usuarios pueden actualizar solo su propia información
CREATE POLICY "Users can update their own data"
ON public.users
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- ============================================
-- VERIFICACIÓN
-- ============================================
-- Ejecuta esto para verificar las políticas:
SELECT schemaname, tablename, policyname, permissive, roles, cmd 
FROM pg_policies 
WHERE tablename = 'users';

-- Deberías ver 3 políticas, todas con roles = {authenticated}
-- ============================================
