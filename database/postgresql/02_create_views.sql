-- ============================================
-- PostgreSQL Views for Posicion App
-- ============================================
-- Author: Claude Code
-- Date: 2025-11-29
-- Description: Useful views for reporting and analytics
-- ============================================

SET search_path TO posicion;

-- ============================================
-- View: v_saldos_por_cuenta
-- Description: Current balance summary by account
-- ============================================
CREATE OR REPLACE VIEW v_saldos_por_cuenta AS
SELECT
    a.id,
    a.user_id,
    a.name AS nombre_cuenta,
    a.type AS tipo_cuenta,
    a.moneda,
    a.initial_balance AS saldo_inicial,
    a.current_balance AS saldo_actual,
    (a.current_balance - a.initial_balance) AS diferencia,
    a.is_default AS es_principal,
    a.created_at AS fecha_creacion
FROM accounts a
WHERE a.is_deletable = TRUE
ORDER BY a.is_default DESC, a.created_at DESC;

COMMENT ON VIEW v_saldos_por_cuenta IS 'Vista con el resumen de saldos por cuenta';

-- ============================================
-- View: v_transacciones_recientes
-- Description: Recent transactions with category and account names
-- ============================================
CREATE OR REPLACE VIEW v_transacciones_recientes AS
SELECT
    t.id_transaccion,
    t.user_id,
    t.fecha_transaccion,
    t.tipo,
    t.monto,
    t.descripcion,
    t.moneda,
    c.nombre AS nombre_cuenta,
    cat.nombre AS nombre_categoria,
    cat.color_hex AS color_categoria,
    t.metodo_pago,
    t.notas
FROM transacciones t
INNER JOIN cuentas c ON t.id_cuenta = c.id_cuenta
INNER JOIN categorias cat ON t.id_categoria = cat.id_categoria
ORDER BY t.fecha_transaccion DESC, t.fecha_registro DESC;

COMMENT ON VIEW v_transacciones_recientes IS 'Vista de transacciones con nombres de cuenta y categoría';

-- ============================================
-- View: v_gastos_fijos_activos
-- Description: Active recurring expenses with next due date
-- ============================================
CREATE OR REPLACE VIEW v_gastos_fijos_activos AS
SELECT
    gf.id_gasto,
    gf.user_id,
    gf.nombre,
    gf.descripcion,
    gf.monto_cuotas AS monto,
    gf.frecuencia,
    gf.dia_semana,
    gf.dia_mes,
    c.nombre AS nombre_cuenta,
    cat.nombre AS nombre_categoria,
    gf.fecha_inicio,
    gf.fecha_fin,
    gf.recordatorio_dias,
    COUNT(pg.id_obligacion) AS proximos_gastos_pendientes
FROM gastos_fijos gf
INNER JOIN cuentas c ON gf.id_cuenta = c.id_cuenta
INNER JOIN categorias cat ON gf.id_categoria = cat.id_categoria
LEFT JOIN proximos_gastos pg ON gf.id_gasto = pg.id_gasto
    AND pg.estado = 'pendiente'
    AND pg.fecha_vencimiento >= CURRENT_DATE
WHERE gf.activo = TRUE
    AND (gf.fecha_fin IS NULL OR gf.fecha_fin >= CURRENT_DATE)
GROUP BY
    gf.id_gasto, gf.user_id, gf.nombre, gf.descripcion,
    gf.monto_cuotas, gf.frecuencia, gf.dia_semana, gf.dia_mes,
    c.nombre, cat.nombre, gf.fecha_inicio, gf.fecha_fin, gf.recordatorio_dias
ORDER BY gf.nombre;

COMMENT ON VIEW v_gastos_fijos_activos IS 'Vista de gastos fijos activos con conteo de próximos gastos pendientes';

-- ============================================
-- View: v_proximos_gastos_pendientes
-- Description: Upcoming expenses that haven't been paid
-- ============================================
CREATE OR REPLACE VIEW v_proximos_gastos_pendientes AS
SELECT
    pg.id_obligacion,
    pg.fecha_vencimiento,
    pg.monto_estimado,
    pg.estado,
    pg.prioridad,
    gf.nombre AS nombre_gasto,
    gf.user_id,
    c.nombre AS nombre_cuenta,
    cat.nombre AS nombre_categoria,
    CASE
        WHEN pg.fecha_vencimiento < CURRENT_DATE THEN 'VENCIDO'
        WHEN pg.fecha_vencimiento = CURRENT_DATE THEN 'HOY'
        WHEN pg.fecha_vencimiento <= CURRENT_DATE + INTERVAL '7 days' THEN 'ESTA_SEMANA'
        WHEN pg.fecha_vencimiento <= CURRENT_DATE + INTERVAL '14 days' THEN 'PROXIMA_SEMANA'
        ELSE 'MAS_DE_2_SEMANAS'
    END AS urgencia,
    (pg.fecha_vencimiento - CURRENT_DATE) AS dias_hasta_vencimiento
FROM proximos_gastos pg
INNER JOIN gastos_fijos gf ON pg.id_gasto = gf.id_gasto
INNER JOIN cuentas c ON gf.id_cuenta = c.id_cuenta
INNER JOIN categorias cat ON gf.id_categoria = cat.id_categoria
WHERE pg.estado = 'pendiente'
ORDER BY pg.fecha_vencimiento ASC;

COMMENT ON VIEW v_proximos_gastos_pendientes IS 'Vista de próximos gastos pendientes con información de urgencia';

-- ============================================
-- View: v_resumen_mensual
-- Description: Monthly summary of income and expenses
-- ============================================
CREATE OR REPLACE VIEW v_resumen_mensual AS
SELECT
    user_id,
    DATE_TRUNC('month', fecha_transaccion) AS mes,
    moneda,
    SUM(CASE WHEN tipo = 'INGRESO' THEN monto ELSE 0 END) AS total_ingresos,
    SUM(CASE WHEN tipo = 'EGRESO' THEN monto ELSE 0 END) AS total_egresos,
    SUM(CASE WHEN tipo = 'INGRESO' THEN monto ELSE -monto END) AS balance,
    COUNT(CASE WHEN tipo = 'INGRESO' THEN 1 END) AS cantidad_ingresos,
    COUNT(CASE WHEN tipo = 'EGRESO' THEN 1 END) AS cantidad_egresos
FROM transacciones
GROUP BY user_id, DATE_TRUNC('month', fecha_transaccion), moneda
ORDER BY mes DESC, user_id;

COMMENT ON VIEW v_resumen_mensual IS 'Resumen mensual de ingresos y egresos por usuario y moneda';

-- ============================================
-- View: v_gastos_por_categoria
-- Description: Expense summary by category
-- ============================================
CREATE OR REPLACE VIEW v_gastos_por_categoria AS
SELECT
    t.user_id,
    DATE_TRUNC('month', t.fecha_transaccion) AS mes,
    cat.nombre AS categoria,
    cat.color_hex,
    cat.icono,
    t.moneda,
    SUM(t.monto) AS total_gastado,
    COUNT(*) AS cantidad_transacciones,
    AVG(t.monto) AS promedio_por_transaccion
FROM transacciones t
INNER JOIN categorias cat ON t.id_categoria = cat.id_categoria
WHERE t.tipo = 'EGRESO'
GROUP BY t.user_id, DATE_TRUNC('month', t.fecha_transaccion), cat.nombre, cat.color_hex, cat.icono, t.moneda
ORDER BY mes DESC, total_gastado DESC;

COMMENT ON VIEW v_gastos_por_categoria IS 'Resumen de gastos agrupados por categoría y mes';

-- ============================================
-- View: v_disponible_por_cuenta
-- Description: Available balance considering upcoming expenses
-- ============================================
CREATE OR REPLACE VIEW v_disponible_por_cuenta AS
SELECT
    a.id,
    a.user_id,
    a.name AS nombre_cuenta,
    a.current_balance AS saldo_actual,
    a.moneda,
    COALESCE(SUM(pg.monto_estimado), 0) AS gastos_pendientes_30_dias,
    (a.current_balance - COALESCE(SUM(pg.monto_estimado), 0)) AS disponible_conservador,
    a.current_balance AS disponible_no_conservador
FROM accounts a
LEFT JOIN cuentas c ON a.user_id = c.user_id AND a.name = c.nombre
LEFT JOIN gastos_fijos gf ON c.id_cuenta = gf.id_cuenta AND gf.activo = TRUE
LEFT JOIN proximos_gastos pg ON gf.id_gasto = pg.id_gasto
    AND pg.estado = 'pendiente'
    AND pg.fecha_vencimiento <= CURRENT_DATE + INTERVAL '30 days'
GROUP BY a.id, a.user_id, a.name, a.current_balance, a.moneda
ORDER BY a.is_default DESC, a.name;

COMMENT ON VIEW v_disponible_por_cuenta IS 'Saldo disponible considerando gastos fijos pendientes';

-- ============================================
-- End of views creation
-- ============================================
