-- ============================================
-- PostgreSQL Seed Data for Posicion App
-- ============================================
-- Author: Claude Code
-- Date: 2025-11-29
-- Description: Initial data for testing and default values
-- ============================================

SET search_path TO posicion;

-- ============================================
-- Default categories for new users
-- ============================================
-- Note: These are examples. In production, categories are created per user
-- This script shows the structure for seeding default categories

-- Example function to create default categories for a user
CREATE OR REPLACE FUNCTION crear_categorias_default_usuario(p_user_id TEXT)
RETURNS VOID AS $$
BEGIN
    -- Income categories
    INSERT INTO categorias (user_id, nombre, tipo, color_hex, icono, descripcion) VALUES
    (p_user_id, 'Salario', 'INGRESO', '#4CAF50', 'payments', 'Ingresos por salario'),
    (p_user_id, 'Freelance', 'INGRESO', '#8BC34A', 'work', 'Trabajos independientes'),
    (p_user_id, 'Inversiones', 'INGRESO', '#00BCD4', 'trending_up', 'Rendimientos de inversiones'),
    (p_user_id, 'Otros Ingresos', 'INGRESO', '#009688', 'attach_money', 'Otros ingresos varios');

    -- Expense categories
    INSERT INTO categorias (user_id, nombre, tipo, color_hex, icono, descripcion) VALUES
    (p_user_id, 'Alimentación', 'EGRESO', '#FF5722', 'restaurant', 'Comida y supermercado'),
    (p_user_id, 'Transporte', 'EGRESO', '#FF9800', 'directions_car', 'Transporte y combustible'),
    (p_user_id, 'Vivienda', 'EGRESO', '#795548', 'home', 'Alquiler, expensas, servicios'),
    (p_user_id, 'Salud', 'EGRESO', '#E91E63', 'local_hospital', 'Medicina y salud'),
    (p_user_id, 'Educación', 'EGRESO', '#9C27B0', 'school', 'Educación y cursos'),
    (p_user_id, 'Entretenimiento', 'EGRESO', '#673AB7', 'movie', 'Salidas y entretenimiento'),
    (p_user_id, 'Ropa', 'EGRESO', '#3F51B5', 'shopping_bag', 'Vestimenta y accesorios'),
    (p_user_id, 'Tecnología', 'EGRESO', '#2196F3', 'devices', 'Tecnología y electrónica'),
    (p_user_id, 'Servicios', 'EGRESO', '#00BCD4', 'build', 'Servicios varios'),
    (p_user_id, 'General', 'EGRESO', '#6B73FF', 'category', 'Gastos generales');
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION crear_categorias_default_usuario IS 'Crea las categorías por defecto para un nuevo usuario';

-- ============================================
-- Example: Create test user with default data
-- ============================================
-- Uncomment to create a test user

/*
-- Create test user
INSERT INTO usuarios (email, password_hash, alias, nombre, moneda_preferencia, activo)
VALUES (
    'test@posicion.com',
    '$2b$10$example_hash_here', -- Use proper bcrypt hash
    'test_user',
    'Usuario de Prueba',
    'ARS',
    TRUE
)
RETURNING id_usuario;

-- Assuming user_id from Firebase is 'test_firebase_uid'
DO $$
DECLARE
    v_user_id TEXT := 'test_firebase_uid';
BEGIN
    -- Create default categories
    PERFORM crear_categorias_default_usuario(v_user_id);

    -- Create default account
    INSERT INTO accounts (id, user_id, name, type, moneda, initial_balance, current_balance, is_default)
    VALUES (
        gen_random_uuid(),
        v_user_id,
        'Bolsillo',
        'cash',
        'ARS',
        0,
        0,
        TRUE
    );

    -- Create corresponding cuentas record (for backward compatibility)
    INSERT INTO cuentas (user_id, nombre, tipo, moneda, es_principal)
    VALUES (
        v_user_id,
        'Bolsillo',
        'EFECTIVO',
        'ARS',
        TRUE
    );
END $$;
*/

-- ============================================
-- Maintenance queries
-- ============================================

-- Clean up old upcoming expenses (older than 1 year and paid/cancelled)
CREATE OR REPLACE FUNCTION limpiar_proximos_gastos_antiguos()
RETURNS INTEGER AS $$
DECLARE
    v_deleted INTEGER;
BEGIN
    DELETE FROM proximos_gastos
    WHERE estado IN ('pagado', 'cancelado')
    AND fecha_vencimiento < CURRENT_DATE - INTERVAL '1 year';

    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION limpiar_proximos_gastos_antiguos IS 'Limpia próximos gastos antiguos (más de 1 año)';

-- Generate upcoming expenses for all active fixed expenses
CREATE OR REPLACE FUNCTION generar_todos_proximos_gastos(p_meses INTEGER DEFAULT 3)
RETURNS TABLE (
    id_gasto INTEGER,
    nombre_gasto VARCHAR(100),
    cantidad_generados INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        gf.id_gasto,
        gf.nombre,
        generar_proximos_gastos(gf.id_gasto, p_meses)
    FROM gastos_fijos gf
    WHERE gf.activo = TRUE
    AND (gf.fecha_fin IS NULL OR gf.fecha_fin >= CURRENT_DATE);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION generar_todos_proximos_gastos IS 'Genera próximos gastos para todos los gastos fijos activos';

-- ============================================
-- End of seed data
-- ============================================
