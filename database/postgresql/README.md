# PostgreSQL Database Scripts - Posicion App

## Descripción

Scripts SQL para migrar la base de datos de Posicion de SQLite a PostgreSQL. Estos scripts crean el esquema completo, vistas, funciones y datos iniciales.

## Estructura de Archivos

```
database/postgresql/
├── 01_create_schema.sql      # Esquema principal (tablas, índices, triggers)
├── 02_create_views.sql        # Vistas útiles para reporting
├── 03_create_functions.sql    # Funciones de negocio
├── 04_seed_data.sql           # Datos iniciales y funciones de mantenimiento
└── README.md                  # Este archivo
```

## Requisitos

- PostgreSQL 12 o superior (recomendado 14+)
- Usuario con privilegios para crear schemas, tablas y funciones
- Extensión `uuid-ossp` o PostgreSQL 13+ (para `gen_random_uuid()`)

## Instalación

### Opción 1: Ejecutar todos los scripts en orden

```bash
# Conectarse a la base de datos
psql -U your_user -d posicion_db

# Ejecutar scripts en orden
\i 01_create_schema.sql
\i 02_create_views.sql
\i 03_create_functions.sql
\i 04_seed_data.sql
```

### Opción 2: Script único

```bash
# Combinar todos los scripts
cat 01_create_schema.sql 02_create_views.sql 03_create_functions.sql 04_seed_data.sql > combined_setup.sql

# Ejecutar
psql -U your_user -d posicion_db -f combined_setup.sql
```

### Opción 3: Desde línea de comandos

```bash
psql -U your_user -d posicion_db -f 01_create_schema.sql
psql -U your_user -d posicion_db -f 02_create_views.sql
psql -U your_user -d posicion_db -f 03_create_functions.sql
psql -U your_user -d posicion_db -f 04_seed_data.sql
```

## Estructura del Schema

### Tablas Principales

#### `usuarios`
- Cuentas de usuario y autenticación
- Información de perfil

#### `accounts` (Nueva)
- Cuentas/billeteras con UUID como PK
- Diseño moderno para integración con Firebase

#### `cuentas` (Legacy)
- Tabla antigua para compatibilidad
- Se mantiene por el bridge con `gastos_fijos`

#### `credit_cards`
- Tarjetas de crédito
- Información de límite y fecha de cierre

#### `categorias`
- Categorías de ingresos y egresos
- Soporte para categorías anidadas

#### `transacciones`
- Transacciones financieras
- Ingresos y egresos

#### `gastos_fijos`
- Gastos recurrentes (semanales/mensuales)
- Configuración de frecuencia y fechas

#### `proximos_gastos`
- Gastos programados pendientes
- Generados automáticamente desde `gastos_fijos`

#### `contactos`
- Agenda de contactos para transferencias

#### `contactos_transacciones`
- Relación muchos a muchos entre contactos y transacciones

## Vistas Disponibles

### `v_saldos_por_cuenta`
Resumen de saldos actuales por cuenta

```sql
SELECT * FROM posicion.v_saldos_por_cuenta WHERE user_id = 'firebase_uid';
```

### `v_transacciones_recientes`
Transacciones con nombres de cuenta y categoría

```sql
SELECT * FROM posicion.v_transacciones_recientes
WHERE user_id = 'firebase_uid'
ORDER BY fecha_transaccion DESC
LIMIT 10;
```

### `v_gastos_fijos_activos`
Gastos fijos activos con conteo de próximos gastos

```sql
SELECT * FROM posicion.v_gastos_fijos_activos WHERE user_id = 'firebase_uid';
```

### `v_proximos_gastos_pendientes`
Próximos gastos pendientes con urgencia

```sql
SELECT * FROM posicion.v_proximos_gastos_pendientes
WHERE user_id = 'firebase_uid'
ORDER BY fecha_vencimiento;
```

### `v_resumen_mensual`
Resumen mensual de ingresos y egresos

```sql
SELECT * FROM posicion.v_resumen_mensual
WHERE user_id = 'firebase_uid'
ORDER BY mes DESC;
```

### `v_gastos_por_categoria`
Gastos agrupados por categoría

```sql
SELECT * FROM posicion.v_gastos_por_categoria
WHERE user_id = 'firebase_uid'
AND mes = DATE_TRUNC('month', CURRENT_DATE);
```

### `v_disponible_por_cuenta`
Disponible conservador considerando gastos pendientes

```sql
SELECT * FROM posicion.v_disponible_por_cuenta WHERE user_id = 'firebase_uid';
```

## Funciones Disponibles

### `generar_proximos_gastos(id_gasto, meses)`
Genera próximos gastos para un gasto fijo

```sql
SELECT generar_proximos_gastos(1, 3); -- Genera 3 meses adelante
```

### `marcar_gasto_pagado(id_obligacion, monto_real)`
Marca un gasto como pagado y crea la transacción

```sql
SELECT marcar_gasto_pagado(123, 5000.00);
```

### `obtener_disponible_conservador(user_id, dias)`
Obtiene disponible conservador por cuenta

```sql
SELECT * FROM obtener_disponible_conservador('firebase_uid', 30);
```

### `calcular_limite_diario(user_id, dias_mes)`
Calcula límite de gasto diario

```sql
SELECT calcular_limite_diario('firebase_uid', 30);
```

### `crear_categorias_default_usuario(user_id)`
Crea categorías por defecto para nuevo usuario

```sql
SELECT crear_categorias_default_usuario('firebase_uid');
```

### `generar_todos_proximos_gastos(meses)`
Genera próximos gastos para todos los gastos fijos activos

```sql
SELECT * FROM generar_todos_proximos_gastos(3);
```

### `limpiar_proximos_gastos_antiguos()`
Limpia próximos gastos antiguos (>1 año)

```sql
SELECT limpiar_proximos_gastos_antiguos();
```

## Migraciones desde SQLite

### Exportar datos de SQLite

```bash
# Exportar a CSV
sqlite3 posicion.db <<EOF
.headers on
.mode csv
.output usuarios.csv
SELECT * FROM usuarios;
.output cuentas.csv
SELECT * FROM cuentas;
-- Repetir para cada tabla
EOF
```

### Importar a PostgreSQL

```sql
-- Ejemplo para tabla usuarios
COPY posicion.usuarios FROM '/path/to/usuarios.csv' WITH CSV HEADER;
```

## Configuración de Deployment

### Supabase

1. Crear proyecto en [Supabase](https://supabase.com)
2. Ir a SQL Editor
3. Ejecutar scripts en orden

### AWS RDS PostgreSQL

```bash
# Crear base de datos
aws rds create-db-instance \
  --db-instance-identifier posicion-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --master-username admin \
  --master-user-password your_password \
  --allocated-storage 20

# Conectar y ejecutar scripts
psql -h your-rds-endpoint.amazonaws.com -U admin -d postgres -f combined_setup.sql
```

### Heroku Postgres

```bash
# Agregar addon
heroku addons:create heroku-postgresql:mini

# Ejecutar scripts
heroku pg:psql < combined_setup.sql
```

### Docker Compose

```yaml
version: '3.8'
services:
  postgres:
    image: postgres:14
    environment:
      POSTGRES_DB: posicion_db
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: your_password
    ports:
      - "5432:5432"
    volumes:
      - ./postgresql:/docker-entrypoint-initdb.d
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

## Mantenimiento

### Generar próximos gastos automáticamente

```sql
-- Ejecutar mensualmente (agregar a cron)
SELECT * FROM generar_todos_proximos_gastos(3);
```

### Limpiar datos antiguos

```sql
-- Ejecutar trimestralmente
SELECT limpiar_proximos_gastos_antiguos();
```

### Actualizar saldos de cuentas

```sql
-- Recalcular saldos si es necesario
UPDATE accounts a
SET current_balance = (
    SELECT calcular_saldo_cuenta(c.id_cuenta)
    FROM cuentas c
    WHERE c.user_id = a.user_id
    AND c.nombre = a.name
)
WHERE user_id = 'firebase_uid';
```

## Índices y Performance

Los índices están optimizados para:
- Búsquedas por `user_id` (más frecuente)
- Filtros por fecha
- Joins entre tablas relacionadas
- Ordenamiento por fecha descendente

### Monitoreo de queries lentas

```sql
-- Habilitar log de queries lentas
ALTER DATABASE posicion_db SET log_min_duration_statement = 1000; -- 1 segundo

-- Ver queries lentas
SELECT * FROM pg_stat_statements
ORDER BY total_time DESC
LIMIT 10;
```

## Backup y Restore

### Backup

```bash
# Backup completo
pg_dump -U admin -d posicion_db -F c -f posicion_backup.dump

# Backup solo schema
pg_dump -U admin -d posicion_db -s -f posicion_schema.sql

# Backup solo datos
pg_dump -U admin -d posicion_db -a -f posicion_data.sql
```

### Restore

```bash
# Restore desde dump
pg_restore -U admin -d posicion_db posicion_backup.dump

# Restore desde SQL
psql -U admin -d posicion_db -f posicion_schema.sql
```

## Seguridad

### Row Level Security (RLS)

```sql
-- Habilitar RLS en tablas sensibles
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE transacciones ENABLE ROW LEVEL SECURITY;

-- Política: usuarios solo ven sus propios datos
CREATE POLICY user_isolation ON accounts
    FOR ALL
    TO authenticated
    USING (user_id = current_setting('app.current_user_id'));

CREATE POLICY user_isolation ON transacciones
    FOR ALL
    TO authenticated
    USING (user_id = current_setting('app.current_user_id'));
```

### Roles y Permisos

```sql
-- Crear rol para la aplicación
CREATE ROLE posicion_app WITH LOGIN PASSWORD 'secure_password';

-- Otorgar permisos
GRANT USAGE ON SCHEMA posicion TO posicion_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA posicion TO posicion_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA posicion TO posicion_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA posicion TO posicion_app;
```

## Troubleshooting

### Error: "schema posicion does not exist"

```sql
CREATE SCHEMA posicion;
SET search_path TO posicion;
```

### Error: "function gen_random_uuid() does not exist"

```sql
-- PostgreSQL < 13
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- Luego reemplazar gen_random_uuid() por uuid_generate_v4()
```

### Error: "permission denied for schema"

```sql
GRANT ALL ON SCHEMA posicion TO your_user;
```

## Contacto y Soporte

Para reportar issues o sugerencias, crear un issue en el repositorio del proyecto.

## Licencia

Estos scripts son parte del proyecto Posicion App.
