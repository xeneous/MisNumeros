# Modelo de Datos UML - Posición App

## Diagrama de Clases

```mermaid
classDiagram
    class User {
        +String id
        +String email
        +String displayName
        +String alias
        +DateTime birthDate
        +String nationality
        +String profileImageUrl
        +UserPlan userPlan
        +DateTime createdAt
        +DateTime updatedAt
        +int localId
        +toMap()
        +fromMap()
        +fromFirebaseUser()
    }

    class Account {
        +String id
        +String userId
        +String name
        +String alias
        +AccountType type
        +String moneda
        +double initialBalance
        +double currentBalance
        +bool isDefault
        +bool isDeletable
        +DateTime createdAt
        +DateTime updatedAt
        +toMap()
        +fromMap()
        +copyWith()
    }

    class Transaction {
        +String id
        +String userId
        +TransactionType type
        +double amount
        +String description
        +String category
        +DateTime date
        +TransactionStatus status
        +String accountId
        +String creditCardId
        +int installments
        +double totalAmount
        +double interestAmount
        +int currentInstallment
        +bool isSharedExpense
        +List~String~ participants
        +Map~String,double~ participantAmounts
        +String currency
        +String location
        +DateTime createdAt
        +DateTime updatedAt
        +getInstallmentAmount()
        +getPersonalShare()
        +toMap()
        +fromMap()
    }

    class Categoria {
        +int idCategoria
        +String userId
        +String nombre
        +TipoCategoria tipo
        +String colorHex
        +String icono
        +String descripcion
        +int padreId
        +DateTime fechaCreacion
        +bool activa
        +toMap()
        +fromMap()
        +copyWith()
    }

    class Contacto {
        +int idContacto
        +String userId
        +String nombre
        +String email
        +String telefono
        +String banco
        +String cuentaDestino
        +String notas
        +bool favorito
        +toMap()
        +fromMap()
        +copyWith()
    }

    class GastoFijo {
        +int idGasto
        +String userId
        +int idCuenta
        +int idCategoria
        +String nombre
        +String descripcion
        +double montoTotal
        +int cuotas
        +double montoCuotas
        +String frecuencia
        +int diaSemana
        +int diaMes
        +DateTime fechaInicio
        +DateTime fechaFin
        +bool activo
        +int recordatorioDias
        +toMap()
        +fromMap()
        +copyWith()
    }

    class ProximoGasto {
        +int idObligacion
        +int idGasto
        +double montoEstimado
        +double montoReal
        +DateTime fechaVencimiento
        +DateTime fechaPago
        +EstadoProximoGasto estado
        +PrioridadProximoGasto prioridad
        +bool recordatorio
        +int idTransaccion
        +toMap()
        +fromMap()
        +copyWith()
    }

    class CreditCard {
        +String id
        +String userId
        +String name
        +String bank
        +String last4Digits
        +String currency
        +double creditLimit
        +double availableCredit
        +int closingDay
        +int dueDay
        +bool isActive
        +DateTime createdAt
        +DateTime updatedAt
        +toMap()
        +fromMap()
    }

    class AccountType {
        <<enumeration>>
        cash
        debit
        digital
        credit
    }

    class TransactionType {
        <<enumeration>>
        income
        expense
    }

    class TransactionStatus {
        <<enumeration>>
        pending
        completed
        cancelled
    }

    class TipoCategoria {
        <<enumeration>>
        ingreso
        gasto
    }

    class EstadoProximoGasto {
        <<enumeration>>
        pendiente
        pagado
        cancelado
    }

    class PrioridadProximoGasto {
        <<enumeration>>
        baja
        media
        alta
    }

    class UserPlan {
        <<enumeration>>
        free
        premium
    }

    %% Relaciones
    User "1" --> "0..*" Account : posee
    User "1" --> "0..*" Transaction : realiza
    User "1" --> "0..*" Categoria : define
    User "1" --> "0..*" Contacto : tiene
    User "1" --> "0..*" GastoFijo : configura
    User "1" --> "0..*" CreditCard : posee

    Account "1" --> "0..*" Transaction : origen
    Account "1" --> "0..*" GastoFijo : débito

    CreditCard "1" --> "0..*" Transaction : pago

    Categoria "0..1" --> "0..*" Categoria : subcategoría
    Categoria "1" --> "0..*" GastoFijo : clasifica

    GastoFijo "1" --> "0..*" ProximoGasto : genera

    Transaction --> TransactionType
    Transaction --> TransactionStatus
    Account --> AccountType
    Categoria --> TipoCategoria
    ProximoGasto --> EstadoProximoGasto
    ProximoGasto --> PrioridadProximoGasto
    User --> UserPlan
```

## Diagrama Entidad-Relación Simplificado

```mermaid
erDiagram
    USER ||--o{ ACCOUNT : posee
    USER ||--o{ TRANSACTION : realiza
    USER ||--o{ CATEGORIA : define
    USER ||--o{ CONTACTO : tiene
    USER ||--o{ GASTO-FIJO : configura
    USER ||--o{ CREDIT-CARD : posee

    ACCOUNT ||--o{ TRANSACTION : "origen de"
    CREDIT-CARD ||--o{ TRANSACTION : "pago con"

    CATEGORIA ||--o{ CATEGORIA : "subcategoría de"
    CATEGORIA ||--o{ GASTO-FIJO : clasifica

    ACCOUNT ||--o{ GASTO-FIJO : "débito desde"
    GASTO-FIJO ||--o{ PROXIMO-GASTO : genera

    USER {
        string id PK
        string email
        string displayName
        string alias
        date birthDate
        string nationality
        string profileImageUrl
        enum userPlan
    }

    ACCOUNT {
        string id PK
        string userId FK
        string name
        enum type
        string moneda
        double initialBalance
        double currentBalance
        boolean isDefault
    }

    TRANSACTION {
        string id PK
        string userId FK
        string accountId FK
        string creditCardId FK
        enum type
        double amount
        string description
        string category
        date date
        enum status
        int installments
        boolean isSharedExpense
        string currency
        string location
    }

    CATEGORIA {
        int idCategoria PK
        string userId FK
        int padreId FK
        string nombre
        enum tipo
        string colorHex
        string icono
        boolean activa
    }

    CONTACTO {
        int idContacto PK
        string userId FK
        string nombre
        string email
        string telefono
        string banco
        string cuentaDestino
        boolean favorito
    }

    GASTO-FIJO {
        int idGasto PK
        string userId FK
        int idCuenta FK
        int idCategoria FK
        string nombre
        double montoTotal
        int cuotas
        double montoCuotas
        string frecuencia
        date fechaInicio
        date fechaFin
        boolean activo
    }

    PROXIMO-GASTO {
        int idObligacion PK
        int idGasto FK
        double montoEstimado
        double montoReal
        date fechaVencimiento
        date fechaPago
        enum estado
        enum prioridad
    }

    CREDIT-CARD {
        string id PK
        string userId FK
        string name
        string bank
        string currency
        double creditLimit
        int closingDay
        int dueDay
        boolean isActive
    }
```

## Notas sobre el Modelo

### Claves Principales
- **User.id**: Firebase UID (String)
- **Account.id**: UUID generado
- **Transaction.id**: UUID generado
- **Categoria.idCategoria**: Autoincremental (int)
- **GastoFijo.idGasto**: Autoincremental (int)

### Relaciones Importantes

1. **User → Account (1:N)**
   - Un usuario puede tener múltiples cuentas
   - Una cuenta pertenece a un solo usuario
   - Relación identificada por `Account.userId`

2. **Account → Transaction (1:N)**
   - Una cuenta puede tener múltiples transacciones
   - Una transacción puede asociarse a una cuenta O a una tarjeta de crédito
   - Relación identificada por `Transaction.accountId` o `Transaction.creditCardId`

3. **GastoFijo → ProximoGasto (1:N)**
   - Un gasto fijo genera múltiples próximos gastos
   - Relación identificada por `ProximoGasto.idGasto`

4. **Categoria → Categoria (Recursiva)**
   - Una categoría puede tener subcategorías
   - Relación identificada por `Categoria.padreId`

5. **Transaction → Participants (N:M)**
   - Una transacción puede tener múltiples participantes
   - Implementado con `isSharedExpense`, `participants` y `participantAmounts`

### Características Especiales

- **Multi-moneda**: Account y Transaction soportan múltiples monedas (ARS, USD, EUR)
- **Cuotas**: Transaction soporta pagos en cuotas con intereses
- **Geolocalización**: Transaction puede guardar ubicación GPS
- **Gastos compartidos**: Transaction soporta división de gastos entre usuarios
- **Recordatorios**: GastoFijo y ProximoGasto incluyen sistema de recordatorios
- **Soft Delete**: Muchas entidades usan campos `activa` en lugar de borrado físico

### Enumeraciones

- **AccountType**: cash, debit, digital, credit
- **TransactionType**: income, expense
- **TransactionStatus**: pending, completed, cancelled
- **TipoCategoria**: ingreso, gasto
- **EstadoProximoGasto**: pendiente, pagado, cancelado
- **PrioridadProximoGasto**: baja, media, alta
- **UserPlan**: free, premium
