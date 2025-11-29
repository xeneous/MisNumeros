-- ============================================
-- PostgreSQL Functions for Posicion App
-- ============================================
-- Author: Claude Code
-- Date: 2025-11-29
-- Description: Useful functions for business logic
-- ============================================

SET search_path TO posicion;

-- ============================================
-- Function: calcular_saldo_cuenta
-- Description: Calculate current balance for an account
-- ============================================
CREATE OR REPLACE FUNCTION calcular_saldo_cuenta(
    p_id_cuenta INTEGER
)
RETURNS DECIMAL(15,2) AS $$
DECLARE
    v_saldo_inicial DECIMAL(15,2);
    v_movimientos DECIMAL(15,2);
BEGIN
    -- Get initial balance from accounts table (via cuentas bridge)
    SELECT COALESCE(a.initial_balance, 0)
    INTO v_saldo_inicial
    FROM cuentas c
    INNER JOIN accounts a ON c.user_id = a.user_id AND c.nombre = a.name
    WHERE c.id_cuenta = p_id_cuenta
    LIMIT 1;

    -- Calculate sum of all transactions
    SELECT COALESCE(SUM(monto * signo), 0)
    INTO v_movimientos
    FROM transacciones
    WHERE id_cuenta = p_id_cuenta;

    RETURN v_saldo_inicial + v_movimientos;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION calcular_saldo_cuenta IS 'Calcula el saldo actual de una cuenta basado en saldo inicial y transacciones';

-- ============================================
-- Function: generar_proximos_gastos
-- Description: Generate upcoming expenses for a fixed expense
-- ============================================
CREATE OR REPLACE FUNCTION generar_proximos_gastos(
    p_id_gasto INTEGER,
    p_meses_adelante INTEGER DEFAULT 3
)
RETURNS INTEGER AS $$
DECLARE
    v_gasto RECORD;
    v_fecha_actual DATE := CURRENT_DATE;
    v_fecha_vencimiento DATE;
    v_contador INTEGER := 0;
BEGIN
    -- Get fixed expense details
    SELECT *
    INTO v_gasto
    FROM gastos_fijos
    WHERE id_gasto = p_id_gasto
    AND activo = TRUE;

    IF NOT FOUND THEN
        RETURN 0;
    END IF;

    -- Generate expenses based on frequency
    IF v_gasto.frecuencia = 'MENSUAL' THEN
        -- Monthly expenses
        FOR i IN 0..p_meses_adelante LOOP
            v_fecha_vencimiento := DATE_TRUNC('month', v_fecha_actual + (i || ' months')::INTERVAL) + (v_gasto.dia_mes - 1 || ' days')::INTERVAL;

            -- Check if this date already exists
            IF NOT EXISTS (
                SELECT 1 FROM proximos_gastos
                WHERE id_gasto = p_id_gasto
                AND fecha_vencimiento = v_fecha_vencimiento
            ) AND (v_gasto.fecha_fin IS NULL OR v_fecha_vencimiento <= v_gasto.fecha_fin) THEN
                INSERT INTO proximos_gastos (
                    id_gasto,
                    monto_estimado,
                    fecha_vencimiento,
                    estado,
                    prioridad,
                    recordatorio
                ) VALUES (
                    p_id_gasto,
                    v_gasto.monto_cuotas,
                    v_fecha_vencimiento,
                    'pendiente',
                    'media',
                    TRUE
                );
                v_contador := v_contador + 1;
            END IF;
        END LOOP;
    ELSIF v_gasto.frecuencia = 'SEMANAL' THEN
        -- Weekly expenses
        FOR i IN 0..(p_meses_adelante * 4) LOOP
            v_fecha_vencimiento := DATE_TRUNC('week', v_fecha_actual) + (v_gasto.dia_semana || ' days')::INTERVAL + (i || ' weeks')::INTERVAL;

            IF NOT EXISTS (
                SELECT 1 FROM proximos_gastos
                WHERE id_gasto = p_id_gasto
                AND fecha_vencimiento = v_fecha_vencimiento
            ) AND (v_gasto.fecha_fin IS NULL OR v_fecha_vencimiento <= v_gasto.fecha_fin) THEN
                INSERT INTO proximos_gastos (
                    id_gasto,
                    monto_estimado,
                    fecha_vencimiento,
                    estado,
                    prioridad,
                    recordatorio
                ) VALUES (
                    p_id_gasto,
                    v_gasto.monto_cuotas,
                    v_fecha_vencimiento,
                    'pendiente',
                    'media',
                    TRUE
                );
                v_contador := v_contador + 1;
            END IF;
        END LOOP;
    END IF;

    RETURN v_contador;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION generar_proximos_gastos IS 'Genera los próximos gastos para un gasto fijo determinado';

-- ============================================
-- Function: marcar_gasto_pagado
-- Description: Mark an upcoming expense as paid and create transaction
-- ============================================
CREATE OR REPLACE FUNCTION marcar_gasto_pagado(
    p_id_obligacion INTEGER,
    p_monto_real DECIMAL(15,2) DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_proximo_gasto RECORD;
    v_gasto_fijo RECORD;
    v_id_transaccion UUID;
BEGIN
    -- Get upcoming expense details
    SELECT *
    INTO v_proximo_gasto
    FROM proximos_gastos
    WHERE id_obligacion = p_id_obligacion;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Próximo gasto no encontrado: %', p_id_obligacion;
    END IF;

    -- Get fixed expense details
    SELECT *
    INTO v_gasto_fijo
    FROM gastos_fijos
    WHERE id_gasto = v_proximo_gasto.id_gasto;

    -- Create transaction
    INSERT INTO transacciones (
        user_id,
        id_cuenta,
        id_categoria,
        tipo,
        tipo_movimiento,
        signo,
        monto,
        descripcion,
        fecha_transaccion,
        metodo_pago
    ) VALUES (
        v_gasto_fijo.user_id,
        v_gasto_fijo.id_cuenta,
        v_gasto_fijo.id_categoria,
        'EGRESO',
        2,
        -1,
        COALESCE(p_monto_real, v_proximo_gasto.monto_estimado),
        'Pago de: ' || v_gasto_fijo.nombre,
        CURRENT_DATE,
        'DEBITO'
    )
    RETURNING id_transaccion INTO v_id_transaccion;

    -- Update upcoming expense
    UPDATE proximos_gastos
    SET estado = 'pagado',
        fecha_pago = CURRENT_DATE,
        monto_real = COALESCE(p_monto_real, monto_estimado),
        id_transaccion = v_id_transaccion
    WHERE id_obligacion = p_id_obligacion;

    -- Update account balance
    UPDATE accounts
    SET current_balance = current_balance - COALESCE(p_monto_real, v_proximo_gasto.monto_estimado)
    WHERE user_id = v_gasto_fijo.user_id
    AND id IN (
        SELECT a.id
        FROM accounts a
        INNER JOIN cuentas c ON a.user_id = c.user_id AND a.name = c.nombre
        WHERE c.id_cuenta = v_gasto_fijo.id_cuenta
    );

    RETURN v_id_transaccion;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION marcar_gasto_pagado IS 'Marca un próximo gasto como pagado y crea la transacción correspondiente';

-- ============================================
-- Function: obtener_disponible_conservador
-- Description: Get conservative available balance (current - pending expenses)
-- ============================================
CREATE OR REPLACE FUNCTION obtener_disponible_conservador(
    p_user_id TEXT,
    p_dias_adelante INTEGER DEFAULT 30
)
RETURNS TABLE (
    cuenta_id UUID,
    nombre_cuenta TEXT,
    saldo_actual DECIMAL(15,2),
    gastos_pendientes DECIMAL(15,2),
    disponible_conservador DECIMAL(15,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        a.id,
        a.name,
        a.current_balance,
        COALESCE(SUM(pg.monto_estimado), 0) AS gastos_pendientes,
        (a.current_balance - COALESCE(SUM(pg.monto_estimado), 0)) AS disponible_conservador
    FROM accounts a
    LEFT JOIN cuentas c ON a.user_id = c.user_id AND a.name = c.nombre
    LEFT JOIN gastos_fijos gf ON c.id_cuenta = gf.id_cuenta AND gf.activo = TRUE
    LEFT JOIN proximos_gastos pg ON gf.id_gasto = pg.id_gasto
        AND pg.estado = 'pendiente'
        AND pg.fecha_vencimiento <= CURRENT_DATE + (p_dias_adelante || ' days')::INTERVAL
    WHERE a.user_id = p_user_id
    GROUP BY a.id, a.name, a.current_balance
    ORDER BY a.is_default DESC, a.name;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION obtener_disponible_conservador IS 'Obtiene el disponible conservador por cuenta (saldo - gastos pendientes)';

-- ============================================
-- Function: calcular_limite_diario
-- Description: Calculate daily spending limit based on available balance
-- ============================================
CREATE OR REPLACE FUNCTION calcular_limite_diario(
    p_user_id TEXT,
    p_dias_mes INTEGER DEFAULT 30
)
RETURNS DECIMAL(15,2) AS $$
DECLARE
    v_disponible_total DECIMAL(15,2);
    v_gastos_pendientes DECIMAL(15,2);
    v_dias_restantes INTEGER;
    v_limite_diario DECIMAL(15,2);
BEGIN
    -- Get total available balance
    SELECT COALESCE(SUM(current_balance), 0)
    INTO v_disponible_total
    FROM accounts
    WHERE user_id = p_user_id;

    -- Get pending expenses for the month
    SELECT COALESCE(SUM(pg.monto_estimado), 0)
    INTO v_gastos_pendientes
    FROM proximos_gastos pg
    INNER JOIN gastos_fijos gf ON pg.id_gasto = gf.id_gasto
    WHERE gf.user_id = p_user_id
    AND pg.estado = 'pendiente'
    AND pg.fecha_vencimiento <= CURRENT_DATE + INTERVAL '30 days';

    -- Calculate remaining days in month
    v_dias_restantes := p_dias_mes - EXTRACT(DAY FROM CURRENT_DATE) + 1;

    IF v_dias_restantes <= 0 THEN
        v_dias_restantes := 1;
    END IF;

    -- Calculate daily limit
    v_limite_diario := (v_disponible_total - v_gastos_pendientes) / v_dias_restantes;

    -- Return 0 if negative
    IF v_limite_diario < 0 THEN
        RETURN 0;
    END IF;

    RETURN v_limite_diario;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION calcular_limite_diario IS 'Calcula el límite de gasto diario basado en disponible y gastos pendientes';

-- ============================================
-- Function: crear_categoria_default
-- Description: Create default category if it doesn't exist
-- ============================================
CREATE OR REPLACE FUNCTION crear_categoria_default(
    p_user_id TEXT,
    p_tipo VARCHAR(10)
)
RETURNS INTEGER AS $$
DECLARE
    v_id_categoria INTEGER;
BEGIN
    -- Check if default category exists
    SELECT id_categoria
    INTO v_id_categoria
    FROM categorias
    WHERE user_id = p_user_id
    AND tipo = p_tipo
    AND nombre = 'General'
    LIMIT 1;

    -- Create if doesn't exist
    IF v_id_categoria IS NULL THEN
        INSERT INTO categorias (
            user_id,
            nombre,
            tipo,
            color_hex,
            icono,
            descripcion,
            activa
        ) VALUES (
            p_user_id,
            'General',
            p_tipo,
            CASE WHEN p_tipo = 'INGRESO' THEN '#4CAF50' ELSE '#6B73FF' END,
            'category',
            'Categoría por defecto',
            TRUE
        )
        RETURNING id_categoria INTO v_id_categoria;
    END IF;

    RETURN v_id_categoria;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION crear_categoria_default IS 'Crea una categoría por defecto si no existe';

-- ============================================
-- End of functions creation
-- ============================================
