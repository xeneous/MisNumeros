-- ============================================
-- PostgreSQL Database Schema for Posicion App
-- ============================================
-- Author: Claude Code
-- Date: 2025-11-29
-- Description: Database schema migration from SQLite to PostgreSQL
-- ============================================

-- Create schema
CREATE SCHEMA IF NOT EXISTS posicion;
SET search_path TO posicion;

-- ============================================
-- Table: usuarios
-- Description: User accounts and authentication
-- ============================================
CREATE TABLE usuarios (
    id_usuario SERIAL PRIMARY KEY,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    alias VARCHAR(30) NOT NULL,
    nombre VARCHAR(50),
    fecha_nacimiento DATE,
    telefono VARCHAR(20),
    foto_url TEXT,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    moneda_preferencia VARCHAR(3) NOT NULL DEFAULT 'ARS'
);

-- Indexes for usuarios
CREATE INDEX idx_usuarios_email ON usuarios(email);
CREATE INDEX idx_usuarios_activo ON usuarios(activo);

-- ============================================
-- Table: cuentas
-- Description: User bank accounts and wallets (legacy table)
-- ============================================
CREATE TABLE cuentas (
    id_cuenta SERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    nombre VARCHAR(50) NOT NULL,
    tipo VARCHAR(20) NOT NULL,
    numero_cuenta VARCHAR(50),
    banco_entidad VARCHAR(50),
    moneda VARCHAR(3) NOT NULL DEFAULT 'ARS',
    color_hex VARCHAR(7) NOT NULL DEFAULT '#2196F3',
    icono VARCHAR(30) NOT NULL DEFAULT 'credit_card',
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    es_principal BOOLEAN NOT NULL DEFAULT FALSE
);

-- Indexes for cuentas
CREATE INDEX idx_cuentas_user_id ON cuentas(user_id);
CREATE INDEX idx_cuentas_activa ON cuentas(activa);
CREATE INDEX idx_cuentas_es_principal ON cuentas(es_principal);

-- ============================================
-- Table: accounts
-- Description: New accounts table with UUID primary keys
-- ============================================
CREATE TABLE accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    alias TEXT,
    type TEXT NOT NULL CHECK (type IN ('cash', 'debit', 'digital', 'credit')),
    moneda VARCHAR(3) NOT NULL DEFAULT 'ARS',
    initial_balance DECIMAL(15,2) NOT NULL DEFAULT 0,
    current_balance DECIMAL(15,2) NOT NULL DEFAULT 0,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    is_deletable BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for accounts
CREATE INDEX idx_accounts_user_id ON accounts(user_id);
CREATE INDEX idx_accounts_is_default ON accounts(is_default);
CREATE INDEX idx_accounts_type ON accounts(type);

-- ============================================
-- Table: credit_cards
-- Description: Credit card accounts
-- ============================================
CREATE TABLE credit_cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    alias TEXT,
    credit_limit DECIMAL(15,2) NOT NULL,
    closing_day INTEGER NOT NULL CHECK (closing_day BETWEEN 1 AND 31),
    current_balance DECIMAL(15,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for credit_cards
CREATE INDEX idx_credit_cards_user_id ON credit_cards(user_id);
CREATE INDEX idx_credit_cards_closing_day ON credit_cards(closing_day);

-- ============================================
-- Table: categorias
-- Description: Transaction categories
-- ============================================
CREATE TABLE categorias (
    id_categoria SERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    nombre VARCHAR(50) NOT NULL,
    tipo VARCHAR(10) NOT NULL CHECK (tipo IN ('INGRESO', 'EGRESO')),
    color_hex VARCHAR(7) NOT NULL DEFAULT '#6B73FF',
    icono VARCHAR(30) NOT NULL DEFAULT 'category',
    descripcion TEXT,
    padre_id INTEGER,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    FOREIGN KEY (padre_id) REFERENCES categorias(id_categoria) ON DELETE SET NULL
);

-- Indexes for categorias
CREATE INDEX idx_categorias_user_id ON categorias(user_id);
CREATE INDEX idx_categorias_tipo ON categorias(tipo);
CREATE INDEX idx_categorias_activa ON categorias(activa);
CREATE INDEX idx_categorias_padre_id ON categorias(padre_id);

-- ============================================
-- Table: transacciones
-- Description: Financial transactions (income and expenses)
-- ============================================
CREATE TABLE transacciones (
    id_transaccion UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    id_cuenta INTEGER NOT NULL,
    id_categoria INTEGER NOT NULL,
    tipo_movimiento INTEGER NOT NULL DEFAULT 2,
    signo INTEGER NOT NULL DEFAULT -1 CHECK (signo IN (-1, 1)),
    moneda VARCHAR(3) NOT NULL DEFAULT 'ARS',
    tipo VARCHAR(10) NOT NULL CHECK (tipo IN ('INGRESO', 'EGRESO')),
    monto DECIMAL(15,2) NOT NULL CHECK (monto >= 0),
    descripcion TEXT,
    fecha_transaccion TIMESTAMP NOT NULL,
    fecha_registro TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    metodo_pago VARCHAR(20),
    referencia VARCHAR(100),
    ubicacion TEXT,
    imagen_url TEXT,
    notas TEXT,
    FOREIGN KEY (id_cuenta) REFERENCES cuentas(id_cuenta) ON DELETE RESTRICT,
    FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria) ON DELETE RESTRICT
);

-- Indexes for transacciones
CREATE INDEX idx_transacciones_user_id ON transacciones(user_id);
CREATE INDEX idx_transacciones_id_cuenta ON transacciones(id_cuenta);
CREATE INDEX idx_transacciones_id_categoria ON transacciones(id_categoria);
CREATE INDEX idx_transacciones_tipo ON transacciones(tipo);
CREATE INDEX idx_transacciones_fecha_transaccion ON transacciones(fecha_transaccion DESC);
CREATE INDEX idx_transacciones_fecha_registro ON transacciones(fecha_registro DESC);
CREATE INDEX idx_transacciones_monto ON transacciones(monto);

-- ============================================
-- Table: gastos_fijos
-- Description: Recurring/fixed expenses
-- ============================================
CREATE TABLE gastos_fijos (
    id_gasto SERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    id_cuenta INTEGER NOT NULL,
    id_categoria INTEGER NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    monto_total DECIMAL(15,2) NOT NULL CHECK (monto_total >= 0),
    cuotas INTEGER CHECK (cuotas IS NULL OR cuotas > 0),
    monto_cuotas DECIMAL(15,2) NOT NULL CHECK (monto_cuotas >= 0),
    frecuencia VARCHAR(10) NOT NULL CHECK (frecuencia IN ('SEMANAL', 'MENSUAL')),
    dia_semana INTEGER CHECK (dia_semana IS NULL OR dia_semana BETWEEN 0 AND 6),
    dia_mes INTEGER CHECK (dia_mes IS NULL OR dia_mes BETWEEN 1 AND 31),
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    recordatorio_dias INTEGER DEFAULT 3 CHECK (recordatorio_dias >= 0),
    FOREIGN KEY (id_cuenta) REFERENCES cuentas(id_cuenta) ON DELETE RESTRICT,
    FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria) ON DELETE RESTRICT,
    CHECK (
        (frecuencia = 'SEMANAL' AND dia_semana IS NOT NULL AND dia_mes IS NULL) OR
        (frecuencia = 'MENSUAL' AND dia_mes IS NOT NULL AND dia_semana IS NULL)
    ),
    CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio)
);

-- Indexes for gastos_fijos
CREATE INDEX idx_gastos_fijos_user_id ON gastos_fijos(user_id);
CREATE INDEX idx_gastos_fijos_id_cuenta ON gastos_fijos(id_cuenta);
CREATE INDEX idx_gastos_fijos_id_categoria ON gastos_fijos(id_categoria);
CREATE INDEX idx_gastos_fijos_activo ON gastos_fijos(activo);
CREATE INDEX idx_gastos_fijos_frecuencia ON gastos_fijos(frecuencia);

-- ============================================
-- Table: proximos_gastos
-- Description: Upcoming scheduled expenses
-- ============================================
CREATE TABLE proximos_gastos (
    id_obligacion SERIAL PRIMARY KEY,
    id_gasto INTEGER NOT NULL,
    monto_estimado DECIMAL(15,2) NOT NULL CHECK (monto_estimado >= 0),
    monto_real DECIMAL(15,2) CHECK (monto_real IS NULL OR monto_real >= 0),
    fecha_vencimiento DATE NOT NULL,
    fecha_pago DATE,
    estado VARCHAR(15) NOT NULL DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'pagado', 'cancelado')),
    prioridad VARCHAR(10) NOT NULL DEFAULT 'media' CHECK (prioridad IN ('baja', 'media', 'alta')),
    recordatorio BOOLEAN NOT NULL DEFAULT TRUE,
    id_transaccion UUID,
    FOREIGN KEY (id_gasto) REFERENCES gastos_fijos(id_gasto) ON DELETE CASCADE,
    FOREIGN KEY (id_transaccion) REFERENCES transacciones(id_transaccion) ON DELETE SET NULL
);

-- Indexes for proximos_gastos
CREATE INDEX idx_proximos_gastos_id_gasto ON proximos_gastos(id_gasto);
CREATE INDEX idx_proximos_gastos_estado ON proximos_gastos(estado);
CREATE INDEX idx_proximos_gastos_fecha_vencimiento ON proximos_gastos(fecha_vencimiento);
CREATE INDEX idx_proximos_gastos_prioridad ON proximos_gastos(prioridad);

-- ============================================
-- Table: contactos
-- Description: Contact book for transfers and payments
-- ============================================
CREATE TABLE contactos (
    id_contacto SERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    nombre VARCHAR(50) NOT NULL,
    email VARCHAR(100),
    telefono VARCHAR(20),
    banco VARCHAR(50),
    cuenta_destino VARCHAR(50),
    notas TEXT,
    favorito BOOLEAN NOT NULL DEFAULT FALSE
);

-- Indexes for contactos
CREATE INDEX idx_contactos_user_id ON contactos(user_id);
CREATE INDEX idx_contactos_favorito ON contactos(favorito);
CREATE INDEX idx_contactos_nombre ON contactos(nombre);

-- ============================================
-- Table: contactos_transacciones
-- Description: Junction table linking contacts to transactions
-- ============================================
CREATE TABLE contactos_transacciones (
    id_transaccion UUID NOT NULL,
    id_contacto INTEGER NOT NULL,
    PRIMARY KEY (id_transaccion, id_contacto),
    FOREIGN KEY (id_transaccion) REFERENCES transacciones(id_transaccion) ON DELETE CASCADE,
    FOREIGN KEY (id_contacto) REFERENCES contactos(id_contacto) ON DELETE CASCADE
);

-- Indexes for contactos_transacciones
CREATE INDEX idx_contactos_transacciones_id_transaccion ON contactos_transacciones(id_transaccion);
CREATE INDEX idx_contactos_transacciones_id_contacto ON contactos_transacciones(id_contacto);

-- ============================================
-- Triggers for updated_at timestamps
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for tables with updated_at
CREATE TRIGGER update_usuarios_updated_at
    BEFORE UPDATE ON usuarios
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_accounts_updated_at
    BEFORE UPDATE ON accounts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_credit_cards_updated_at
    BEFORE UPDATE ON credit_cards
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- Comments on tables
-- ============================================
COMMENT ON TABLE usuarios IS 'User accounts and authentication information';
COMMENT ON TABLE cuentas IS 'Legacy bank accounts and wallets table (for backward compatibility)';
COMMENT ON TABLE accounts IS 'New accounts table with UUID primary keys for better integration';
COMMENT ON TABLE credit_cards IS 'Credit card accounts with limit and closing day information';
COMMENT ON TABLE categorias IS 'Transaction categories for income and expenses';
COMMENT ON TABLE transacciones IS 'Financial transactions including income and expenses';
COMMENT ON TABLE gastos_fijos IS 'Recurring/fixed expenses (weekly or monthly)';
COMMENT ON TABLE proximos_gastos IS 'Upcoming scheduled expenses generated from fixed expenses';
COMMENT ON TABLE contactos IS 'Contact book for transfers and payments';
COMMENT ON TABLE contactos_transacciones IS 'Junction table linking contacts to transactions';

-- ============================================
-- End of schema creation
-- ============================================
