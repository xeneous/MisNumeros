/// Database service that now uses Supabase instead of SQLite
/// This file re-exports SupabaseDatabaseService as DatabaseService to maintain
/// compatibility with existing code

import 'supabase_database_service.dart';

// Type alias for backward compatibility
typedef DatabaseService = SupabaseDatabaseService;
