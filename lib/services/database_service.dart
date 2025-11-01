import 'package:sqflite/sqflite.dart' as sql;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:path/path.dart';
import 'dart:io';

import '../models/usuario.dart';
import '../models/account.dart';
import '../models/transaccion.dart'; // Import the new Transaccion model
import '../models/cuenta.dart';
import '../models/categoria.dart';
import '../models/gasto_fijo.dart';
import '../models/proximo_gasto.dart';
import '../models/transaction.dart' as new_tx;
import '../models/contacto.dart';
import '../models/contactos_transacciones.dart';

import '../models/user.dart' as app_user;
import '../models/credit_card.dart';

class DatabaseService {
  static sql.Database? _database;
  static const String _dbName = 'expense_manager.db';
  static const int _dbVersion = 8; // Incremented for Firebase UID migration

  // Cache for table schema information to avoid repeated PRAGMA queries
  static final Map<String, bool> _tableHasOldUserIdColumn = {};

  // Table names
  static const String usuariosTable = 'usuarios';
  static const String cuentasTable = 'cuentas';
  static const String categoriasTable = 'categorias';
  static const String transaccionesTable = 'transacciones';
  static const String gastosFijosTable = 'gastos_fijos';
  static const String proximosGastosTable = 'proximos_gastos';
  static const String contactosTable = 'contactos';
  static const String contactosTransaccionesTable = 'contactos_transacciones';
  static const String accountsTable = 'accounts';
  static const String creditCardsTable = 'credit_cards';

  final firestore.FirebaseFirestore _firestore =
      firestore.FirebaseFirestore.instance;
  Future<sql.Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<sql.Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _dbName);

    return await sql.openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(sql.Database db, int version) async {
    // Usuarios table
    await db.execute('''
      CREATE TABLE $usuariosTable (
        id_usuario INTEGER PRIMARY KEY AUTOINCREMENT,
        email VARCHAR(100) NOT NULL UNIQUE,
        password_hash VARCHAR(255) NOT NULL,
        alias VARCHAR(30) NOT NULL,
        nombre VARCHAR(50),
        fecha_nacimiento DATE,
        telefono VARCHAR(20),
        foto_url TEXT,
        fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        activo BOOLEAN NOT NULL DEFAULT 1,
        moneda_preferencia VARCHAR(3) NOT NULL DEFAULT 'ARS'
      )
    ''');

    // Cuentas table
    await db.execute('''
      CREATE TABLE $cuentasTable (
        id_cuenta INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        nombre VARCHAR(50) NOT NULL,
        tipo VARCHAR(20) NOT NULL,
        numero_cuenta VARCHAR(50),
        banco_entidad VARCHAR(50),
        moneda VARCHAR(3) NOT NULL DEFAULT 'ARS',
        color_hex VARCHAR(7) NOT NULL DEFAULT '#2196F3',
        icono VARCHAR(30) NOT NULL DEFAULT 'credit_card',
        fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        activa BOOLEAN NOT NULL DEFAULT 1,
        es_principal BOOLEAN NOT NULL DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES $usuariosTable (id_usuario)
      )
    ''');

    // Categorias table
    await db.execute('''
      CREATE TABLE $categoriasTable (
        id_categoria INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        nombre VARCHAR(50) NOT NULL,
        tipo VARCHAR(10) NOT NULL,
        color_hex VARCHAR(7) NOT NULL DEFAULT '#6B73FF',
        icono VARCHAR(30) NOT NULL DEFAULT 'category',
        descripcion TEXT,
        padre_id INTEGER,
        fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        activa BOOLEAN NOT NULL DEFAULT 1,
        FOREIGN KEY (user_id) REFERENCES $usuariosTable (id_usuario),
        FOREIGN KEY (padre_id) REFERENCES $categoriasTable (id_categoria)
      )
    ''');

    // Transacciones table
    await db.execute('''
      CREATE TABLE $transaccionesTable (
        id_transaccion TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        id_cuenta INTEGER NOT NULL,
        id_categoria INTEGER NOT NULL,
        tipo_movimiento INTEGER NOT NULL DEFAULT 2,
        signo INTEGER NOT NULL DEFAULT -1,
        moneda VARCHAR(3) NOT NULL DEFAULT 'ARS',
        tipo VARCHAR(10) NOT NULL,
        monto DECIMAL(15,2) NOT NULL,
        descripcion TEXT,
        fecha_transaccion DATETIME NOT NULL,
        fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        metodo_pago VARCHAR(20),
        referencia VARCHAR(100),
        ubicacion TEXT,
        imagen_url TEXT,
        notas TEXT,
        FOREIGN KEY (user_id) REFERENCES $usuariosTable (id_usuario),
        FOREIGN KEY (id_cuenta) REFERENCES $cuentasTable (id_cuenta),
        FOREIGN KEY (id_categoria) REFERENCES $categoriasTable (id_categoria)
      )
    ''');

    // Gastos fijos table
    await db.execute('''
      CREATE TABLE $gastosFijosTable (
        id_gasto INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        id_cuenta INTEGER NOT NULL,
        id_categoria INTEGER NOT NULL,
        nombre VARCHAR(100) NOT NULL,
        descripcion TEXT,
        monto_total DECIMAL(15,2) NOT NULL,
        cuotas INTEGER,
        monto_cuotas DECIMAL(15,2) NOT NULL,
        frecuencia VARCHAR(10) NOT NULL,
        dia_semana INTEGER,
        dia_mes INTEGER,
        fecha_inicio DATE NOT NULL,
        fecha_fin DATE,
        activo BOOLEAN NOT NULL DEFAULT 1,
        recordatorio_dias INTEGER DEFAULT 3,
        FOREIGN KEY (user_id) REFERENCES $usuariosTable (id_usuario),
        FOREIGN KEY (id_cuenta) REFERENCES $cuentasTable (id_cuenta),
        FOREIGN KEY (id_categoria) REFERENCES $categoriasTable (id_categoria)
      )
    ''');

    // Proximos gastos table
    await db.execute('''
      CREATE TABLE $proximosGastosTable (
        id_obligacion INTEGER PRIMARY KEY AUTOINCREMENT,
        id_gasto INTEGER NOT NULL,
        monto_estimado DECIMAL(15,2) NOT NULL,
        monto_real DECIMAL(15,2),
        fecha_vencimiento DATE NOT NULL,
        fecha_pago DATE,
        estado VARCHAR(15) NOT NULL DEFAULT 'pendiente',
        prioridad VARCHAR(10) NOT NULL DEFAULT 'media',
        recordatorio BOOLEAN NOT NULL DEFAULT 1,
        id_transaccion INTEGER,
        FOREIGN KEY (id_gasto) REFERENCES $gastosFijosTable (id_gasto),
        FOREIGN KEY (id_transaccion) REFERENCES $transaccionesTable (id_transaccion)
      )
    ''');

    // Contactos table
    await db.execute('''
      CREATE TABLE $contactosTable (
        id_contacto INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        nombre VARCHAR(50) NOT NULL,
        email VARCHAR(100),
        telefono VARCHAR(20),
        banco VARCHAR(50),
        cuenta_destino VARCHAR(50),
        notas TEXT,
        favorito BOOLEAN NOT NULL DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES $usuariosTable (id_usuario)
      )
    ''');

    // Contactos transacciones junction table
    await db.execute('''
      CREATE TABLE $contactosTransaccionesTable (
        id_transaccion INTEGER NOT NULL,
        id_contacto INTEGER NOT NULL,
        PRIMARY KEY (id_transaccion, id_contacto),
        FOREIGN KEY (id_transaccion) REFERENCES $transaccionesTable (id_transaccion),
        FOREIGN KEY (id_contacto) REFERENCES $contactosTable (id_contacto)
      )
    ''');

    // New tables for version 3 onwards
    await db.execute('''
      CREATE TABLE $accountsTable (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        name TEXT NOT NULL,
        alias TEXT,
        type TEXT NOT NULL,
        moneda TEXT NOT NULL DEFAULT 'ARS',
        initialBalance REAL NOT NULL,
        currentBalance REAL NOT NULL,
        isDefault INTEGER NOT NULL DEFAULT 0,
        isDeletable INTEGER NOT NULL DEFAULT 1,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $creditCardsTable (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        name TEXT NOT NULL,
        alias TEXT,
        creditLimit REAL NOT NULL,
        closingDay INTEGER NOT NULL,
        currentBalance REAL NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(
    sql.Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 8) {
      // Migration to Firebase UID - Add user_id columns and migrate data
      // First check if columns exist before adding them
      try {
        await db.execute('ALTER TABLE $cuentasTable ADD COLUMN user_id TEXT');
      } catch (e) {
        print('user_id column already exists in $cuentasTable or error: $e');
      }

      try {
        await db.execute(
          'ALTER TABLE $categoriasTable ADD COLUMN user_id TEXT',
        );
      } catch (e) {
        print('user_id column already exists in $categoriasTable or error: $e');
      }

      try {
        await db.execute(
          'ALTER TABLE $transaccionesTable ADD COLUMN user_id TEXT',
        );
      } catch (e) {
        print(
          'user_id column already exists in $transaccionesTable or error: $e',
        );
      }

      try {
        await db.execute(
          'ALTER TABLE $gastosFijosTable ADD COLUMN user_id TEXT',
        );
      } catch (e) {
        print(
          'user_id column already exists in $gastosFijosTable or error: $e',
        );
      }

      try {
        await db.execute('ALTER TABLE $contactosTable ADD COLUMN user_id TEXT');
      } catch (e) {
        print('user_id column already exists in $contactosTable or error: $e');
      }

      // Note: Data migration will be handled at runtime when users log in
      // The old id_usuario columns will be kept for backward compatibility during transition
    }
    if (oldVersion < 7) {
      // Add moneda column to accounts table
      await db.execute(
        'ALTER TABLE $accountsTable ADD COLUMN moneda TEXT NOT NULL DEFAULT \'ARS\'',
      );
    }
    if (oldVersion < 6) {
      // Add moneda column to transacciones
      await db.execute(
        'ALTER TABLE $transaccionesTable ADD COLUMN moneda VARCHAR(3) NOT NULL DEFAULT \'ARS\'',
      );
    }
    if (oldVersion < 5) {
      // Add tipo_movimiento and signo columns to transacciones
      await db.execute(
        'ALTER TABLE $transaccionesTable ADD COLUMN tipo_movimiento INTEGER NOT NULL DEFAULT 2',
      );
      await db.execute(
        'ALTER TABLE $transaccionesTable ADD COLUMN signo INTEGER NOT NULL DEFAULT -1',
      );
    }
    if (oldVersion < 4) {
      // Recreate the transactions table with a TEXT primary key
      await db.execute('DROP TABLE IF EXISTS $transaccionesTable');
      await db.execute('''
        CREATE TABLE $transaccionesTable (
          id_transaccion TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          id_cuenta INTEGER NOT NULL,
          id_categoria INTEGER NOT NULL,
          tipo_movimiento INTEGER NOT NULL DEFAULT 2,
          signo INTEGER NOT NULL DEFAULT -1,
          moneda VARCHAR(3) NOT NULL DEFAULT 'ARS',
          tipo VARCHAR(10) NOT NULL,
          monto DECIMAL(15,2) NOT NULL,
          descripcion TEXT,
          fecha_transaccion DATETIME NOT NULL,
          fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
          metodo_pago VARCHAR(20),
          referencia VARCHAR(100),
          ubicacion TEXT,
          imagen_url TEXT,
          notas TEXT,
          FOREIGN KEY (user_id) REFERENCES $usuariosTable (id_usuario),
          FOREIGN KEY (id_cuenta) REFERENCES $cuentasTable (id_cuenta),
          FOREIGN KEY (id_categoria) REFERENCES $categoriasTable (id_categoria)
        )
      ''');
    }
    if (oldVersion < 2) {
      // Migration from version 1 to 2 - recreate all tables with new schema
      await db.execute('DROP TABLE IF EXISTS operaciones');
      await db.execute('DROP TABLE IF EXISTS periodicidades');
      await db.execute('DROP TABLE IF EXISTS tiposMovimiento');
      await db.execute('DROP TABLE IF EXISTS contactos');
      await db.execute('DROP TABLE IF EXISTS conceptos');
      await db.execute('DROP TABLE IF EXISTS gastos');
      await db.execute('DROP TABLE IF EXISTS movimientos');
      await db.execute('DROP TABLE IF EXISTS fixed_expenses');
      await db.execute('DROP TABLE IF EXISTS loans');
      await db.execute('DROP TABLE IF EXISTS transactions');
      await db.execute('DROP TABLE IF EXISTS credit_cards');
      await db.execute('DROP TABLE IF EXISTS accounts');
      await db.execute('DROP TABLE IF EXISTS users');
    }
    if (oldVersion < 3) {
      // In version 3, we just need to ensure all tables are created.
      // The _onCreate method now contains all table creation logic.
      await _onCreate(db, newVersion);
    }
  }

  // Usuario operations
  Future<int> insertUsuario(Usuario usuario) async {
    final db = await database;
    return await db.insert(usuariosTable, usuario.toMap());
  }

  Future<Usuario?> getUsuario(int idUsuario) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      usuariosTable,
      where: 'id_usuario = ?',
      whereArgs: [idUsuario],
    );

    if (maps.isNotEmpty) {
      return Usuario.fromMap(maps.first);
    }
    return null;
  }

  Future<Usuario?> getUsuarioByEmail(String email) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      usuariosTable,
      where: 'email = ?',
      whereArgs: [email],
    );

    if (maps.isNotEmpty) {
      return Usuario.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Usuario>> getAllUsuarios() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      usuariosTable,
      orderBy: 'id_usuario ASC',
    );

    if (maps.isNotEmpty) {
      return maps.map((map) => Usuario.fromMap(map)).toList();
    }
    return [];
  }

  Future<int> updateUsuario(Usuario usuario) async {
    final db = await database;
    return await db.update(
      usuariosTable,
      usuario.toMap(),
      where: 'id_usuario = ?',
      whereArgs: [usuario.idUsuario],
    );
  }

  // Create an initial user record in the local DB upon registration
  Future<int> createInitialUser(String email, String alias) async {
    final db = await database;
    final newUser = Usuario(
      idUsuario: 0, // autoincrement
      email: email,
      passwordHash: 'firebase_auth', // Placeholder, auth is handled by Firebase
      alias: alias,
      fechaCreacion: DateTime.now(),
      fechaActualizacion: DateTime.now(),
    );
    return await db.insert(
      usuariosTable,
      newUser.toMap(),
      conflictAlgorithm:
          sql.ConflictAlgorithm.ignore, // Don't fail if user already exists
    );
  }

  Future<app_user.User?> getUserFromFirestore(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        // Ensure the user object's 'id' is populated from the document's UID.
        return app_user.User.fromMap(data..['id'] = uid);
      }
    } catch (e) {
      print('Error getting user from Firestore: $e');
    }
    return null;
  }

  Future<void> createOrUpdateUserInFirestore(app_user.User user) async {
    await _firestore
        .collection('users')
        .doc(user.id)
        .set(user.toMap(), firestore.SetOptions(merge: true));
  }

  Future<void> createOrUpdateUserFromAppUser(app_user.User user) async {
    final db = await database;
    final existingUser = await getUsuarioByEmail(user.email);
    if (existingUser != null) {
      final updatedUser = existingUser.copyWith(
        alias: user.alias,
        fechaActualizacion: DateTime.now(),
      );
      await updateUsuario(updatedUser);
    } else {
      await createInitialUser(user.email, user.alias ?? user.displayName ?? '');
    }
  }

  Future<void> insertUsuarioFromUser(app_user.User user) async {
    final db = await database;
    final newUser = Usuario(
      idUsuario: 0, // autoincrement
      email: user.email,
      passwordHash: 'firebase_auth', // Placeholder
      alias: user.alias ?? user.displayName ?? user.email.split('@')[0],
      fechaCreacion: user.createdAt,
      fechaActualizacion: user.updatedAt,
      nombre: user.displayName,
      fechaNacimiento: user.birthDate,
      fotoUrl: user.profileImageUrl,
    );
    await db.insert(
      usuariosTable,
      newUser.toMap(),
      conflictAlgorithm: sql.ConflictAlgorithm.ignore,
    );
  }

  /// Ensures a user exists in the old 'usuarios' table and returns their integer ID.
  /// If the user doesn't exist, it creates them first.
  Future<int> getOrCreateOldUserId(app_user.User user) async {
    Usuario? localUser = await getUsuarioByEmail(user.email);
    if (localUser == null) {
      // User does not exist in the old table, so we create it.
      await insertUsuarioFromUser(user);
      // Fetch the newly created user to get their auto-incremented ID.
      localUser = await getUsuarioByEmail(user.email);
    } else {
      // If user exists, check if alias needs an update for consistency.
      if (localUser.alias != user.alias) {
        await updateUsuario(localUser.copyWith(alias: user.alias));
      }
    }
    if (localUser == null) {
      throw Exception(
        'Failed to create or find user in the old database schema.',
      );
    }
    return localUser.idUsuario;
  }

  /// Migrates existing data from integer user IDs to Firebase UIDs
  /// This method should be called when a user logs in to ensure their data is properly migrated
  Future<void> migrateUserDataToFirebaseUID(
    String firebaseUID,
    int oldUserId,
  ) async {
    final db = await database;

    try {
      // Only migrate if oldUserId is valid (> 0)
      if (oldUserId <= 0) {
        print(
          'Skipping migration - no valid old user ID (oldUserId: $oldUserId)',
        );
        return;
      }

      // Check if each table has the old id_usuario column before trying to migrate
      final tables = [
        cuentasTable,
        categoriasTable,
        transaccionesTable,
        gastosFijosTable,
        contactosTable,
      ];

      for (final tableName in tables) {
        try {
          final hasOldColumn = await _hasOldUserIdColumn(db, tableName);
          if (hasOldColumn) {
            await db.update(
              tableName,
              {'user_id': firebaseUID},
              where: 'id_usuario = ? AND (user_id IS NULL OR user_id = "")',
              whereArgs: [oldUserId],
            );
            print(
              'Migrated $tableName from user ID $oldUserId to Firebase UID $firebaseUID',
            );
          } else {
            print(
              'Skipping $tableName - no id_usuario column (new installation)',
            );
          }
        } catch (e) {
          print('Error migrating table $tableName: $e');
        }
      }

      print('Migration completed for Firebase UID $firebaseUID');
    } catch (e) {
      print('Error in migration process: $e');
    }
  }

  // Nueva Cuenta operations (new schema)
  Future<int> insertCuenta(Cuenta cuenta) async {
    final db = await database;
    return await db.insert(cuentasTable, cuenta.toMap());
  }

  Future<List<Cuenta>> getCuentas(String userId) async {
    final db = await database;

    // Use cached schema info to avoid repeated PRAGMA queries
    final hasOldColumn = await _hasOldUserIdColumn(db, cuentasTable);

    String whereClause = 'user_id = ?';
    List<dynamic> whereArgs = [userId];

    if (hasOldColumn) {
      whereClause = 'user_id = ? OR id_usuario = ?';
      whereArgs = [userId, userId];
    }

    final List<Map<String, dynamic>> maps = await db.query(
      cuentasTable,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'fecha_creacion DESC',
    );

    return maps.map((map) => Cuenta.fromMap(map)).toList();
  }

  Future<Cuenta?> getCuenta(int idCuenta) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      cuentasTable,
      where: 'id_cuenta = ?',
      whereArgs: [idCuenta],
    );

    if (maps.isNotEmpty) {
      return Cuenta.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateCuenta(Cuenta cuenta) async {
    final db = await database;
    return await db.update(
      cuentasTable,
      cuenta.toMap(),
      where: 'id_cuenta = ?',
      whereArgs: [cuenta.idCuenta],
    );
  }

  Future<int> deleteCuenta(int idCuenta) async {
    final db = await database;
    return await db.delete(
      cuentasTable,
      where: 'id_cuenta = ?',
      whereArgs: [idCuenta],
    );
  }

  // Helper to find an old account by name for the bridge
  Future<List<Cuenta>> findOldAccountByName(String name, String userId) async {
    final db = await database;

    // Use cached schema info to avoid repeated PRAGMA queries
    final hasOldColumn = await _hasOldUserIdColumn(db, cuentasTable);

    String whereClause = 'nombre = ? AND user_id = ?';
    List<dynamic> whereArgs = [name, userId];

    if (hasOldColumn) {
      whereClause = 'nombre = ? AND (user_id = ? OR id_usuario = ?)';
      whereArgs = [name, userId, userId];
    }

    final List<Map<String, dynamic>> maps = await db.query(
      cuentasTable,
      where: whereClause,
      whereArgs: whereArgs,
    );

    return maps.map((map) => Cuenta.fromMap(map)).toList();
  }

  // Cuenta operations
  Future<int> insertAccount(Account account) async {
    final db = await database;

    // Save to both SQLite local and Firestore for persistence
    try {
      await _firestore
          .collection('accounts')
          .doc(account.id)
          .set(account.toMap());
      print('DatabaseService: Account saved to Firestore: ${account.name}');
    } catch (e) {
      print('DatabaseService: Error saving account to Firestore: $e');
    }

    // Use REPLACE to avoid primary key constraint errors
    return await db.insert(
      accountsTable,
      account.toMap(),
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
  }

  Future<List<Account>> getAccounts(String userId) async {
    try {
      // First try to get accounts from Firestore (persistent)
      final snapshot = await _firestore
          .collection('accounts')
          .where('userId', isEqualTo: userId)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final firestoreAccounts = snapshot.docs
            .map((doc) => Account.fromMap(doc.data()))
            .toList();

        print(
          'DatabaseService: Found ${firestoreAccounts.length} accounts in Firestore',
        );

        // Sync Firestore accounts to local SQLite
        await _syncAccountsToLocal(firestoreAccounts);

        return firestoreAccounts;
      }
    } catch (e) {
      print('DatabaseService: Error fetching accounts from Firestore: $e');
    }

    // Fallback to local SQLite if Firestore fails
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      accountsTable,
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'createdAt DESC',
    );

    final localAccounts = maps.map((map) => Account.fromMap(map)).toList();
    print(
      'DatabaseService: Found ${localAccounts.length} accounts in local SQLite',
    );

    return localAccounts;
  }

  Future<Account?> getAccount(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      accountsTable,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Account.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateAccount(Account account) async {
    final db = await database;

    // Update in both Firestore and local SQLite
    try {
      await _firestore
          .collection('accounts')
          .doc(account.id)
          .set(account.toMap(), firestore.SetOptions(merge: true));
      print('DatabaseService: Account updated in Firestore: ${account.name}');
    } catch (e) {
      print('DatabaseService: Error updating account in Firestore: $e');
    }

    return await db.update(
      accountsTable,
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<int> deleteAccount(String id) async {
    final db = await database;

    // --- TEMPORARY BRIDGE ---
    // First, find the account to get its details for deleting the old counterpart.
    final accountToDelete = await getAccount(id);
    if (accountToDelete != null) {
      // Find and delete the corresponding "old" Cuenta.
      final oldAccounts = await findOldAccountByName(
        accountToDelete.name,
        accountToDelete.userId,
      );
      for (final oldAccount in oldAccounts) {
        await deleteCuenta(oldAccount.idCuenta);
      }
    }
    // --- END OF BRIDGE ---

    // Finally, delete the new Account.
    return await db.delete(accountsTable, where: 'id = ?', whereArgs: [id]);
  }

  // Categoria operations
  Future<int> insertCategoria(Categoria categoria) async {
    final db = await database;
    return await db.insert(
      categoriasTable,
      categoria.toMap(),
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
  }

  Future<List<Categoria>> getCategorias(String userId) async {
    final db = await database;

    // Use cached schema info to avoid repeated PRAGMA queries
    final hasOldColumn = await _hasOldUserIdColumn(db, categoriasTable);

    String whereClause = 'user_id = ?';
    List<dynamic> whereArgs = [userId];

    if (hasOldColumn) {
      whereClause = 'user_id = ? OR id_usuario = ?';
      whereArgs = [userId, userId];
    }

    final List<Map<String, dynamic>> maps = await db.query(
      categoriasTable,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'nombre ASC',
    );

    return maps.map((map) => Categoria.fromMap(map)).toList();
  }

  Future<Categoria?> getCategoria(int idCategoria) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      categoriasTable,
      where: 'id_categoria = ?',
      whereArgs: [idCategoria],
    );

    if (maps.isNotEmpty) {
      return Categoria.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateCategoria(Categoria categoria) async {
    final db = await database;
    return await db.update(
      categoriasTable,
      categoria.toMap(),
      where: 'id_categoria = ?',
      whereArgs: [categoria.idCategoria],
    );
  }

  Future<int> deleteCategoria(int idCategoria) async {
    final db = await database;
    return await db.delete(
      categoriasTable,
      where: 'id_categoria = ?',
      whereArgs: [idCategoria],
    );
  }

  // Transaccion operations
  Future<int> insertTransaccion(Transaccion transaccion) async {
    final db = await database;
    return await db.insert(transaccionesTable, transaccion.toMap());
  }

  Future<List<Transaccion>> getTransacciones(
    String userId, {
    DateTime? fromDate,
    DateTime? toDate,
    int? accountId,
  }) async {
    final db = await database;

    // Use cached schema info to avoid repeated PRAGMA queries
    final hasOldColumn = await _hasOldUserIdColumn(db, transaccionesTable);

    String whereClause = 'user_id = ?';
    List<dynamic> whereArgs = [userId];

    if (hasOldColumn) {
      whereClause = 'user_id = ? OR id_usuario = ?';
      whereArgs = [userId, userId];
    }

    if (accountId != null) {
      whereClause += ' AND id_cuenta = ?';
      whereArgs.add(accountId);
    }

    if (fromDate != null && toDate != null) {
      whereClause += ' AND fecha_transaccion BETWEEN ? AND ?';
      whereArgs.addAll([fromDate.toIso8601String(), toDate.toIso8601String()]);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      transaccionesTable,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'fecha_transaccion DESC, fecha_registro DESC',
    );

    return maps.map((map) => Transaccion.fromMap(map)).toList();
  }

  Future<Transaccion?> getTransaccion(String idTransaccion) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      transaccionesTable,
      where: 'id_transaccion = ?',
      whereArgs: [idTransaccion],
    );

    if (maps.isNotEmpty) {
      return Transaccion.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateTransaccion(Transaccion transaccion) async {
    final db = await database;
    return await db.update(
      transaccionesTable,
      transaccion.toMap(),
      where: 'id_transaccion = ?',
      whereArgs: [transaccion.idTransaccion],
    );
  }

  Future<int> deleteTransaccion(String idTransaccion) async {
    final db = await database;
    return await db.delete(
      transaccionesTable,
      where: 'id_transaccion = ?',
      whereArgs: [idTransaccion],
    );
  }

  Future<List<String>> getTopTransactionDescriptions(
    String userId,
    TipoTransaccion tipo, {
    int limit = 5,
  }) async {
    final db = await database;

    // Use cached schema info to avoid repeated PRAGMA queries
    final hasOldColumn = await _hasOldUserIdColumn(db, transaccionesTable);

    String whereClause = 'user_id = ?';
    List<dynamic> queryArgs = [userId, tipo.name, limit];

    if (hasOldColumn) {
      whereClause = '(user_id = ? OR id_usuario = ?)';
      queryArgs = [userId, userId, tipo.name, limit];
    }

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT descripcion, COUNT(descripcion) as freq
      FROM $transaccionesTable
      WHERE $whereClause AND tipo = ? AND descripcion IS NOT NULL AND descripcion != ''
      GROUP BY descripcion
      ORDER BY freq DESC
      LIMIT ?
    ''', queryArgs);

    if (maps.isNotEmpty) {
      return maps.map((map) => map['descripcion'] as String).toList();
    }
    return [];
  }

  // New transaction operations (using new_tx.Transaction model)
  Future<void> insertNewTransaction(new_tx.Transaction transaction) async {
    print(
      'DatabaseService: Saving transaction to Firestore - ID: ${transaction.id}, Amount: ${transaction.amount}, Account: ${transaction.accountId}',
    );

    // --- NEW: Save directly to Firestore ---
    await _firestore
        .collection('transactions')
        .doc(transaction.id)
        .set(transaction.toMap());

    print('DatabaseService: Transaction saved to Firestore successfully');

    // After inserting, update the balance of the corresponding new Account
    // This logic remains crucial.
    if (transaction.accountId != null && transaction.accountId!.isNotEmpty) {
      print(
        'DatabaseService: Updating account balance for account ${transaction.accountId}',
      );
      await updateAccountBalance(
        transaction.accountId!,
        transaction.amount,
        _mapNewToOldTransactionType(transaction.type),
      );
      print('DatabaseService: Account balance updated successfully');
    }
  }

  Future<void> updateAccountBalance(
    String accountId,
    double amount,
    TipoTransaccion type,
  ) async {
    print(
      'DatabaseService: updateAccountBalance called - AccountID: $accountId, Amount: $amount, Type: ${type.name}',
    );

    final account = await getAccount(accountId);
    if (account != null) {
      print('DatabaseService: Current balance: ${account.currentBalance}');

      final newBalance = type == TipoTransaccion.ingreso
          ? (account.currentBalance + amount)
          : (account.currentBalance - amount);

      print('DatabaseService: New balance will be: $newBalance');

      final updatedAccount = account.copyWith(
        currentBalance: newBalance,
        updatedAt: DateTime.now(), // Update timestamp
      );

      await updateAccount(updatedAccount);
      print('DatabaseService: Account balance updated in database');
    } else {
      print('DatabaseService: ERROR - Account not found with ID: $accountId');
    }
  }

  Future<List<new_tx.Transaction>> getTransactions({
    required String userId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      // Simplified query without complex indexes - just get all user transactions
      firestore.Query query = _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId);

      final snapshot = await query.get();
      List<new_tx.Transaction> transactions = snapshot.docs
          .map(
            (doc) =>
                new_tx.Transaction.fromMap(doc.data() as Map<String, dynamic>),
          )
          .toList();

      // Get current valid account IDs to filter orphaned transactions
      final validAccounts = await getAccounts(userId);
      final validAccountIds = validAccounts.map((a) => a.id).toSet();

      print(
        'DatabaseService: Found ${transactions.length} total transactions, ${validAccountIds.length} valid accounts',
      );

      // Filter out transactions for accounts that no longer exist
      transactions = transactions.where((tx) {
        final isValidAccount =
            tx.accountId != null && validAccountIds.contains(tx.accountId);
        if (!isValidAccount) {
          print(
            'DatabaseService: Filtering out transaction for non-existent account: ${tx.accountId}',
          );
        }
        return isValidAccount;
      }).toList();

      // Filter by date in memory if needed (avoids complex Firestore indexes)
      if (fromDate != null || toDate != null) {
        transactions = transactions.where((tx) {
          if (fromDate != null && tx.date.isBefore(fromDate)) return false;
          if (toDate != null && tx.date.isAfter(toDate)) return false;
          return true;
        }).toList();
      }

      // Sort by date in memory
      transactions.sort((a, b) => b.date.compareTo(a.date));

      print(
        'DatabaseService: Returning ${transactions.length} valid transactions',
      );
      return transactions;
    } catch (e) {
      print('Error fetching transactions from Firestore: $e');
      return [];
    }
  }

  Future<List<new_tx.Transaction>> getTransactionsForAccount({
    required String userId,
    required String accountId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      // Simplified query - just get all user transactions and filter in memory
      firestore.Query query = _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId);

      final snapshot = await query.get();
      List<new_tx.Transaction> transactions = snapshot.docs
          .map(
            (doc) =>
                new_tx.Transaction.fromMap(doc.data() as Map<String, dynamic>),
          )
          .toList();

      // Verify the account still exists before returning transactions
      final account = await getAccount(accountId);
      if (account == null) {
        print(
          'DatabaseService: Account $accountId no longer exists, returning empty list',
        );
        return [];
      }

      // Filter by account and date in memory (avoids complex Firestore indexes)
      transactions = transactions.where((tx) {
        if (tx.accountId != accountId) return false;
        if (fromDate != null && tx.date.isBefore(fromDate)) return false;
        if (toDate != null && tx.date.isAfter(toDate)) return false;
        return true;
      }).toList();

      // Sort by date in memory
      transactions.sort((a, b) => b.date.compareTo(a.date));

      print(
        'DatabaseService: Returning ${transactions.length} transactions for account $accountId',
      );
      return transactions;
    } catch (e) {
      print('Error fetching transactions from Firestore: $e');
      return [];
    }
  }

  // Helper to bridge new TransactionType to old TipoTransaccion
  TipoTransaccion _mapNewToOldTransactionType(new_tx.TransactionType type) {
    switch (type) {
      case new_tx.TransactionType.income:
        return TipoTransaccion.ingreso;
      case new_tx.TransactionType.expense:
        return TipoTransaccion.gasto;
    }
  }

  // GastoFijo operations
  Future<int> insertGastoFijo(GastoFijo gastoFijo) async {
    final db = await database;
    return await db.insert(gastosFijosTable, gastoFijo.toMap());
  }

  Future<List<GastoFijo>> getGastosFijos(String userId) async {
    final db = await database;

    // Use cached schema info to avoid repeated PRAGMA queries
    final hasOldColumn = await _hasOldUserIdColumn(db, gastosFijosTable);

    String whereClause = 'user_id = ?';
    List<dynamic> whereArgs = [userId];

    if (hasOldColumn) {
      whereClause = 'user_id = ? OR id_usuario = ?';
      whereArgs = [userId, userId];
    }

    final List<Map<String, dynamic>> maps = await db.query(
      gastosFijosTable,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'fecha_inicio DESC',
    );

    return maps.map((map) => GastoFijo.fromMap(map)).toList();
  }

  Future<GastoFijo?> getGastoFijo(int idGasto) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      gastosFijosTable,
      where: 'id_gasto = ?',
      whereArgs: [idGasto],
    );

    if (maps.isNotEmpty) {
      return GastoFijo.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateGastoFijo(GastoFijo gastoFijo) async {
    final db = await database;
    return await db.update(
      gastosFijosTable,
      gastoFijo.toMap(),
      where: 'id_gasto = ?',
      whereArgs: [gastoFijo.idGasto],
    );
  }

  Future<int> deleteGastoFijo(int idGasto) async {
    final db = await database;
    return await db.delete(
      gastosFijosTable,
      where: 'id_gasto = ?',
      whereArgs: [idGasto],
    );
  }

  // ProximoGasto operations
  Future<int> insertProximoGasto(ProximoGasto proximoGasto) async {
    final db = await database;
    return await db.insert(proximosGastosTable, proximoGasto.toMap());
  }

  Future<List<ProximoGasto>> getProximosGastos(String userId) async {
    final db = await database;

    // Use cached schema info to avoid repeated PRAGMA queries
    final hasOldColumn = await _hasOldUserIdColumn(db, gastosFijosTable);

    String whereClause = 'gf.user_id = ?';
    List<dynamic> queryArgs = [userId];

    if (hasOldColumn) {
      whereClause = 'gf.user_id = ? OR gf.id_usuario = ?';
      queryArgs = [userId, userId];
    }

    // Join with gastos_fijos to get user-specific upcoming expenses
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT pg.* FROM $proximosGastosTable pg
      INNER JOIN $gastosFijosTable gf ON pg.id_gasto = gf.id_gasto
      WHERE $whereClause
      ORDER BY pg.fecha_vencimiento ASC
    ''', queryArgs);

    return maps.map((map) => ProximoGasto.fromMap(map)).toList();
  }

  Future<ProximoGasto?> getProximoGasto(int idObligacion) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      proximosGastosTable,
      where: 'id_obligacion = ?',
      whereArgs: [idObligacion],
    );

    if (maps.isNotEmpty) {
      return ProximoGasto.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateProximoGasto(ProximoGasto proximoGasto) async {
    final db = await database;
    return await db.update(
      proximosGastosTable,
      proximoGasto.toMap(),
      where: 'id_obligacion = ?',
      whereArgs: [proximoGasto.idObligacion],
    );
  }

  Future<int> deleteProximoGasto(int idObligacion) async {
    final db = await database;
    return await db.delete(
      proximosGastosTable,
      where: 'id_obligacion = ?',
      whereArgs: [idObligacion],
    );
  }

  // Contacto operations
  Future<int> insertContacto(Contacto contacto) async {
    final db = await database;
    return await db.insert(contactosTable, contacto.toMap());
  }

  Future<List<Contacto>> getContactos(String userId) async {
    final db = await database;

    // Use cached schema info to avoid repeated PRAGMA queries
    final hasOldColumn = await _hasOldUserIdColumn(db, contactosTable);

    String whereClause = 'user_id = ?';
    List<dynamic> whereArgs = [userId];

    if (hasOldColumn) {
      whereClause = 'user_id = ? OR id_usuario = ?';
      whereArgs = [userId, userId];
    }

    final List<Map<String, dynamic>> maps = await db.query(
      contactosTable,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'nombre ASC',
    );

    return maps.map((map) => Contacto.fromMap(map)).toList();
  }

  Future<Contacto?> getContacto(int idContacto) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      contactosTable,
      where: 'id_contacto = ?',
      whereArgs: [idContacto],
    );

    if (maps.isNotEmpty) {
      return Contacto.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateContacto(Contacto contacto) async {
    final db = await database;
    return await db.update(
      contactosTable,
      contacto.toMap(),
      where: 'id_contacto = ?',
      whereArgs: [contacto.idContacto],
    );
  }

  Future<int> deleteContacto(int idContacto) async {
    final db = await database;
    return await db.delete(
      contactosTable,
      where: 'id_contacto = ?',
      whereArgs: [idContacto],
    );
  }

  // ContactosTransacciones operations
  Future<int> insertContactoTransaccion(
    ContactosTransacciones contactoTransaccion,
  ) async {
    final db = await database;
    return await db.insert(
      contactosTransaccionesTable,
      contactoTransaccion.toMap(),
    );
  }

  Future<List<ContactosTransacciones>> getContactosTransacciones(
    int idTransaccion,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      contactosTransaccionesTable,
      where: 'id_transaccion = ?',
      whereArgs: [idTransaccion],
    );

    return maps.map((map) => ContactosTransacciones.fromMap(map)).toList();
  }

  Future<int> deleteContactoTransaccion(
    int idTransaccion,
    int idContacto,
  ) async {
    final db = await database;
    return await db.delete(
      contactosTransaccionesTable,
      where: 'id_transaccion = ? AND id_contacto = ?',
      whereArgs: [idTransaccion, idContacto],
    );
  }

  // Legacy method aliases for backward compatibility
  // These methods are needed for screens that haven't been updated yet

  Future<int> updateUser(Usuario usuario) async {
    return await updateUsuario(usuario);
  }

  Future<int> insertCreditCard(CreditCard creditCard) async {
    final db = await database;
    return await db.insert(creditCardsTable, creditCard.toMap());
  }

  Future<int> updateCreditCard(CreditCard creditCard) async {
    final db = await database;
    return await db.update(
      creditCardsTable,
      creditCard.toMap(),
      where: 'id = ?',
      whereArgs: [creditCard.id],
    );
  }

  Future<int> deleteCreditCard(String id) async {
    final db = await database;
    return await db.delete(creditCardsTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertFixedExpense(GastoFijo gastoFijo) async {
    return await insertGastoFijo(gastoFijo);
  }

  Future<List<dynamic>> getMovimientos(String userId) async {
    // TODO: Implement when legacy models are updated
    return [];
  }

  Future<List<dynamic>> getGastos(String userId) async {
    // TODO: Implement when legacy models are updated
    return [];
  }

  Future<List<dynamic>> getConceptos() async {
    // TODO: Implement when legacy models are updated
    return [];
  }

  Future<List<dynamic>> getTiposMovimiento() async {
    // TODO: Implement when legacy models are updated
    return [];
  }

  Future<List<dynamic>> getPeriodicidades() async {
    // TODO: Implement when legacy models are updated
    return [];
  }

  Future<List<dynamic>> getOperaciones() async {
    // TODO: Implement when legacy models are updated
    return [];
  }

  Future<List<CreditCard>> getCreditCards(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      creditCardsTable,
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'createdAt DESC',
    );

    return maps.map((map) => CreditCard.fromMap(map)).toList();
  }

  Future<void> clearOtherDefaultAccounts(
    String userId,
    String excludeAccountId,
  ) async {
    final db = await database;
    await db.update(
      accountsTable,
      {'isDefault': 0},
      where: 'userId = ? AND id != ?',
      whereArgs: [userId, excludeAccountId],
    );
  }

  // Utility methods
  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  // --- DEBUG & EXPORT ---

  Future<Map<String, List<int>>> exportAllTablesToCsv() async {
    final db = await database;
    final Map<String, List<int>> csvFiles = {};

    final tables = [
      usuariosTable,
      cuentasTable,
      categoriasTable,
      transaccionesTable,
      gastosFijosTable,
      proximosGastosTable,
      contactosTable,
      accountsTable, // New schema
      creditCardsTable, // New schema
    ];

    for (final table in tables) {
      try {
        final List<Map<String, dynamic>> maps = await db.query(table);
        if (maps.isNotEmpty) {
          final header = maps.first.keys.join(',');
          final rows = maps.map(
            (row) => row.values
                .map((v) => '"${v.toString().replaceAll('"', '""')}"')
                .join(','),
          );
          final csvContent = [header, ...rows].join('\n');
          csvFiles[table] = utf8.encode(csvContent);
        }
      } catch (e) {
        print('Could not export table $table: $e');
      }
    }

    return csvFiles;
  }

  /// Cached method to check if a table has the old id_usuario column
  /// This avoids repeated PRAGMA queries for better performance
  Future<bool> _hasOldUserIdColumn(sql.Database db, String tableName) async {
    if (_tableHasOldUserIdColumn.containsKey(tableName)) {
      return _tableHasOldUserIdColumn[tableName]!;
    }

    try {
      final tableInfo = await db.rawQuery('PRAGMA table_info($tableName)');
      final hasOldColumn = tableInfo.any(
        (column) => column['name'] == 'id_usuario',
      );
      _tableHasOldUserIdColumn[tableName] = hasOldColumn;
      return hasOldColumn;
    } catch (e) {
      // If there's an error, assume no old column exists
      _tableHasOldUserIdColumn[tableName] = false;
      return false;
    }
  }

  /// Syncs accounts from Firestore to local SQLite
  Future<void> _syncAccountsToLocal(List<Account> accounts) async {
    final db = await database;

    try {
      // Clear existing accounts for this user and insert the Firestore ones
      for (final account in accounts) {
        await db.insert(
          accountsTable,
          account.toMap(),
          conflictAlgorithm: sql.ConflictAlgorithm.replace,
        );
      }
      print(
        'DatabaseService: Synced ${accounts.length} accounts to local SQLite',
      );
    } catch (e) {
      print('DatabaseService: Error syncing accounts to local: $e');
    }
  }

  /// Syncs fixed expenses from Firestore to local SQLite
  Future<void> _syncFixedExpensesToLocal(List<GastoFijo> expenses) async {
    final db = await database;

    try {
      for (final expense in expenses) {
        await db.insert(
          gastosFijosTable,
          expense.toMap(),
          conflictAlgorithm: sql.ConflictAlgorithm.replace,
        );
      }
      print(
        'DatabaseService: Synced ${expenses.length} fixed expenses to local SQLite',
      );
    } catch (e) {
      print('DatabaseService: Error syncing fixed expenses to local: $e');
    }
  }
}
