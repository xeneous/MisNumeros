-- Script para verificar la configuración de Google OAuth en Supabase
-- Ejecuta esto en el SQL Editor de Supabase Dashboard

-- 1. Verificar que la tabla auth.users existe
SELECT EXISTS (
    SELECT FROM information_schema.tables
    WHERE table_schema = 'auth'
    AND table_name = 'users'
) AS auth_users_exists;

-- 2. Verificar que la tabla public.users existe
SELECT EXISTS (
    SELECT FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name = 'users'
) AS public_users_exists;

-- 3. Ver las políticas RLS en public.users
SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'users';

-- 4. Verificar que RLS está habilitado
SELECT
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables
WHERE tablename = 'users' AND schemaname = 'public';

-- 5. Ver la estructura de la tabla public.users
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'users'
ORDER BY ordinal_position;
