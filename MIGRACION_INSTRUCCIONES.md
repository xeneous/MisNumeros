# Instrucciones de Migración - Balance con Transaction Types

## Estado Actual

✅ **Completado:**
1. Script SQL de migración creado (`migration_transaction_types.sql`)
2. Modelo `Account` actualizado con `AccountPurpose`
3. Modelo `TransactionType` creado
4. Modelo `Transaction` actualizado con `transactionTypeId` y `destinationAccountId`

⏳ **Pendiente:**
1. Ejecutar el script SQL en Supabase
2. Actualizar `SupabaseDatabaseService` para usar las nuevas funciones SQL
3. Actualizar `home_screen.dart` para filtrar por `accountPurpose`
4. Actualizar screens de agregar/editar transacciones

---

## PASO 1: Ejecutar Migración en Supabase

### 1.1 Conectarse a Supabase

1. Ir a https://supabase.com/dashboard
2. Seleccionar tu proyecto
3. Ir a **SQL Editor**

### 1.2 Ejecutar el Script

1. Abrir el archivo `migration_transaction_types.sql`
2. Copiar **TODO** el contenido
3. Pegarlo en el SQL Editor de Supabase
4. Click en **Run**

### 1.3 Verificar la Migración

Ejecutar estas queries para verificar:

```sql
-- Verificar transaction_types
SELECT * FROM transaction_types ORDER BY id;
-- Debe mostrar: 1=income, 2=expense, 11=transfer_in, 12=transfer_out

-- Verificar que accounts tiene account_purpose
SELECT id, name, account_purpose, currency FROM accounts LIMIT 5;
-- Debe mostrar la columna account_purpose con valor 'available'

-- Verificar que transactions tiene transaction_type_id
SELECT id, transaction_type_id, amount, account_id FROM transactions LIMIT 5;
-- Debe mostrar transaction_type_id con valores 1 o 2

-- Probar función de balance
SELECT get_account_balance('TU_ACCOUNT_ID_AQUI');
-- Debe retornar un número (el balance calculado)
```

---

## PASO 2: Datos de Prueba (OPCIONAL)

Si quieres probar con datos limpios, ejecuta:

```sql
-- Crear una cuenta de prueba (reemplaza 'TU_USER_ID' con tu user ID de Supabase Auth)
INSERT INTO accounts (id, user_id, name, account_type, currency, account_purpose, initial_balance, current_balance)
VALUES
  (gen_random_uuid(), 'TU_USER_ID', 'Efectivo', 'cash', 'ARS', 'available', 0, 0),
  (gen_random_uuid(), 'TU_USER_ID', 'Ahorro', 'digital', 'ARS', 'savings', 0, 0);

-- Obtener el ID de la cuenta "Efectivo"
SELECT id, name FROM accounts WHERE user_id = 'TU_USER_ID';

-- Insertar transacciones de prueba (reemplaza 'ACCOUNT_ID_EFECTIVO')
INSERT INTO transactions (id, user_id, account_id, transaction_type_id, amount, description, transaction_date)
VALUES
  (gen_random_uuid(), 'TU_USER_ID', 'ACCOUNT_ID_EFECTIVO', 1, 100000, 'Sueldo', NOW()),
  (gen_random_uuid(), 'TU_USER_ID', 'ACCOUNT_ID_EFECTIVO', 2, 5000, 'Café', NOW());

-- Verificar balance
SELECT get_account_balance('ACCOUNT_ID_EFECTIVO');
-- Debe retornar: 95000 (100000 - 5000)
```

---

## PASO 3: Actualizar el Código Flutter (YA CASI LISTO)

Los modelos ya están actualizados. Solo falta:

### 3.1 Actualizar `SupabaseDatabaseService`

El servicio necesita:
- **ELIMINAR** los métodos `_updateAccountBalance`, `insertTransaction`, `updateTransaction`, `deleteTransaction` actuales
- **REEMPLAZAR** con nuevas versiones que usen `transaction_type_id`
- **AGREGAR** métodos para:
  - `getAvailableBalance(String userId, String currency)` → llama a la función SQL
  - `getSavingsBalance(String userId, String currency)` → llama a la función SQL
  - `getAccountBalanceCalculated(String accountId)` → llama a `get_account_balance()`
  - `createTransfer(from, to, amount)` → crea 2 transacciones (transferOut + transferIn)

### 3.2 Actualizar `home_screen.dart`

Cambiar el cálculo de "Disponible":
```dart
// ANTES:
final totalAvailable = accounts.fold(0.0, (sum, acc) => sum + acc.currentBalance);

// DESPUÉS:
final totalAvailable = await dbService.getAvailableBalance(currentUser.id, _activeCurrency);
```

### 3.3 Actualizar `add_transaction_screen.dart`

Cambiar para usar `transactionTypeId` en lugar de `type`:
```dart
// ANTES:
type: TransactionType.income,

// DESPUÉS:
transactionTypeId: 1, // 1 = income
type: TransactionType.income, // Para backward compatibility
```

---

## PASO 4: Testing

### 4.1 Prueba Manual

1. **Crear una cuenta nueva** (tipo: available)
2. **Agregar un ingreso** de $100,000
3. **Verificar** que el disponible muestra $100,000
4. **Agregar un gasto** de $20,000
5. **Verificar** que el disponible muestra $80,000
6. **Crear cuenta de ahorro**
7. **Hacer transferencia** de available → savings
8. **Verificar** que:
   - Cuenta available disminuye
   - Cuenta savings aumenta
   - Disponible (total) solo cuenta "available"

### 4.2 Verificar en Supabase

Ir a **Table Editor** → **transactions** y verificar:
- `transaction_type_id` tiene valores correctos (1, 2, 11, 12)
- `amount` siempre es positivo
- `destination_account_id` está lleno para transferencias

---

## PASO 5: Limpieza (DESPUÉS de confirmar que todo funciona)

Una vez que confirmes que el nuevo sistema funciona:

```sql
-- Eliminar columna vieja transaction_type (string)
ALTER TABLE transactions DROP COLUMN IF EXISTS transaction_type;

-- Eliminar columna current_balance de accounts (ya no se usa, se calcula)
-- OPCIONAL: Puedes mantenerla como cache si quieres
-- ALTER TABLE accounts DROP COLUMN current_balance;
```

---

## Troubleshooting

### Error: "column transaction_type_id does not exist"
→ No ejecutaste el script SQL. Ve al PASO 1.

### Error: "function get_account_balance does not exist"
→ No ejecutaste el script SQL completo. Ve al PASO 1.

### Los balances están mal
→ Ejecuta esta query para recalcular:
```sql
SELECT
  a.id,
  a.name,
  get_account_balance(a.id) as calculated_balance
FROM accounts a
WHERE user_id = 'TU_USER_ID';
```

### No veo cambios en la app
→ Haz hot restart (no hot reload). O cierra y abre la app.

---

## Resumen de Cambios

| Antes | Después |
|-------|---------|
| `transaction_type: 'income'` | `transaction_type_id: 1` |
| `transaction_type: 'expense'` | `transaction_type_id: 2` |
| Balance guardado en `current_balance` | Balance calculado con query |
| Todas las cuentas cuentan para "Disponible" | Solo `account_purpose='available'` |
| No hay transferencias | Transferencias con `transaction_type_id` 11/12 |

---

## Siguiente Paso

**¿Quieres que continue con el código de `SupabaseDatabaseService` ahora?**

O prefieres primero ejecutar el script SQL en Supabase para confirmar que funciona?
