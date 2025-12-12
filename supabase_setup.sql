-- ============================================
-- Supabase Database Setup Script - VERSIÓN CORREGIDA
-- ============================================
-- Este script configura la tabla users y las políticas de Row Level Security (RLS)
-- necesarias para que el login y registro funcionen correctamente.
--
-- IMPORTANTE: Ejecuta esto en el SQL Editor de tu proyecto Supabase:
-- https://pqypiajsgunsurxpomol.supabase.co/project/_/sql
--
-- CAMBIOS EN ESTA VERSIÓN:
-- - Corregida la política de INSERT para permitir creación automática
-- - Agregado trigger para crear usuarios automáticamente
-- ============================================

-- 1. Crear la tabla users si no existe
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  alias TEXT,
  display_name TEXT,
  profile_image_url TEXT,
  birth_date TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Habilitar Row Level Security (RLS)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- 3. Eliminar políticas existentes si las hay (para evitar duplicados)
DROP POLICY IF EXISTS "Users can read their own data" ON public.users;
DROP POLICY IF EXISTS "Users can insert their own data" ON public.users;
DROP POLICY IF EXISTS "Users can update their own data" ON public.users;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.users;

-- 4. Crear políticas de RLS CORREGIDAS

-- Política para permitir lectura: Los usuarios solo pueden leer su propia información
CREATE POLICY "Users can read their own data"
ON public.users
FOR SELECT
USING (auth.uid() = id);

-- Política para permitir inserción: Usuarios autenticados pueden crear su registro
-- CORRECCIÓN: Permitir a cualquier usuario autenticado insertar su propio registro
CREATE POLICY "Enable insert for authenticated users only"
ON public.users
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- Política para permitir actualización: Los usuarios solo pueden actualizar su propia información
CREATE POLICY "Users can update their own data"
ON public.users
FOR UPDATE
USING (auth.uid() = id);

-- 5. Crear función para crear perfil automáticamente cuando se registra un usuario
-- Esto evita el error de RLS al crear el perfil manualmente
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, created_at, updated_at)
  VALUES (
    NEW.id,
    NEW.email,
    NOW(),
    NOW()
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Eliminar el trigger si ya existe (para evitar duplicados)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 7. Crear trigger para ejecutar la función cuando se crea un usuario en auth.users
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- 8. Crear índice para mejorar rendimiento
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);

-- 9. Crear función para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 10. Crear trigger para actualizar updated_at automáticamente
DROP TRIGGER IF EXISTS update_users_updated_at ON public.users;
CREATE TRIGGER update_users_updated_at
BEFORE UPDATE ON public.users
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- VERIFICACIÓN
-- ============================================
-- Para verificar que todo está configurado correctamente, ejecuta:
-- 
-- 1. Ver las políticas:
-- SELECT tablename, policyname, permissive, roles, cmd, qual 
-- FROM pg_policies 
-- WHERE tablename = 'users';
-- 
-- 2. Ver los triggers:
-- SELECT trigger_name, event_manipulation, event_object_table 
-- FROM information_schema.triggers 
-- WHERE event_object_table = 'users';
-- 
-- Deberías ver:
-- - 3 políticas de RLS
-- - 2 triggers (on_auth_user_created, update_users_updated_at)
-- ============================================
