-- Supabase Schema for Posicion App
-- Este script es IDEMPOTENTE - puede ejecutarse múltiples veces sin errores
-- ⚠️ ADVERTENCIA: DROP TABLE elimina TODOS los datos. Solo usar en desarrollo.

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ========================================
-- DROP EXISTING OBJECTS (orden inverso para respetar FKs)
-- ========================================

-- Drop tables in reverse dependency order
DROP TABLE IF EXISTS public.transactions CASCADE;
DROP TABLE IF EXISTS public.fixed_expense_change_history CASCADE;
DROP TABLE IF EXISTS public.fixed_expense_instances CASCADE;
DROP TABLE IF EXISTS public.credit_cards CASCADE;
DROP TABLE IF EXISTS public.fixed_expenses CASCADE;
DROP TABLE IF EXISTS public.categories CASCADE;
DROP TABLE IF EXISTS public.accounts CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;

-- ========================================
-- CREATE TABLES
-- ========================================

-- Users table (extends Supabase auth.users)
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  alias TEXT,
  display_name TEXT,
  profile_image_url TEXT,
  birth_date DATE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Accounts table
CREATE TABLE public.accounts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  alias TEXT,
  type TEXT NOT NULL CHECK (type IN ('cash', 'debit', 'digital')),
  currency TEXT DEFAULT 'ARS' NOT NULL,
  initial_balance NUMERIC(15,2) DEFAULT 0,
  current_balance NUMERIC(15,2) DEFAULT 0,
  is_default BOOLEAN DEFAULT false,
  is_deletable BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Categories table
CREATE TABLE public.categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
  color_hex TEXT DEFAULT '#6B73FF',
  icon TEXT DEFAULT 'category',
  description TEXT,
  parent_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Fixed Expenses table
CREATE TABLE public.fixed_expenses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  account_id UUID REFERENCES public.accounts(id) ON DELETE SET NULL,
  category_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  description TEXT,
  amount NUMERIC(15,2) NOT NULL,
  frequency TEXT NOT NULL CHECK (frequency IN ('MENSUAL', 'SEMANAL')),
  day_of_month INTEGER CHECK (day_of_month BETWEEN 1 AND 31),
  day_of_week INTEGER CHECK (day_of_week BETWEEN 1 AND 7),
  is_active BOOLEAN DEFAULT true,
  start_date DATE NOT NULL DEFAULT CURRENT_DATE,
  end_date DATE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Fixed Expense Instances table
-- Representa instancias individuales de gastos fijos (ejemplo: "Fútbol del domingo 08/12")
CREATE TABLE public.fixed_expense_instances (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  fixed_expense_id UUID NOT NULL REFERENCES public.fixed_expenses(id) ON DELETE CASCADE,
  due_date DATE NOT NULL,
  amount NUMERIC(15,2) NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'skipped', 'cancelled')),
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(fixed_expense_id, due_date) -- No permitir duplicados para la misma fecha
);

-- Transactions table
-- Ingresos y egresos reales. Las transferencias se modelan como 2 transacciones vinculadas.
CREATE TABLE public.transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  account_id UUID NOT NULL REFERENCES public.accounts(id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES public.categories(id) ON DELETE CASCADE,
  fixed_expense_instance_id UUID REFERENCES public.fixed_expense_instances(id) ON DELETE SET NULL,
  
  -- Tipo de movimiento: solo ingreso o egreso (no 'transfer')
  movement_type TEXT NOT NULL CHECK (movement_type IN ('income', 'expense')),
  
  -- Para transferencias: vincula con la transacción relacionada
  -- Ejemplo: Transferencia de Efectivo→Banco genera 2 transacciones que se referencian mutuamente
  related_transaction_id UUID REFERENCES public.transactions(id) ON DELETE SET NULL,
  
  amount NUMERIC(15,2) NOT NULL,
  currency TEXT DEFAULT 'ARS' NOT NULL,
  description TEXT,
  date TIMESTAMP WITH TIME ZONE NOT NULL,
  location TEXT,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Fixed Expense Change History table
-- Rastrea todos los cambios realizados a los gastos fijos para auditoría y reportes
CREATE TABLE public.fixed_expense_change_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  fixed_expense_id UUID NOT NULL REFERENCES public.fixed_expenses(id) ON DELETE CASCADE,
  change_type TEXT NOT NULL CHECK (change_type IN ('amount_change', 'frequency_change', 'deactivated', 'reactivated', 'created')),
  old_value TEXT,
  new_value TEXT,
  effective_date DATE NOT NULL,
  reason TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Credit Cards table
CREATE TABLE public.credit_cards (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  alias TEXT,
  credit_limit NUMERIC(15,2) NOT NULL,
  closing_day INTEGER CHECK (closing_day BETWEEN 1 AND 31),
  current_balance NUMERIC(15,2) DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);


-- ========================================
-- ROW LEVEL SECURITY (RLS)
-- ========================================

-- Enable Row Level Security
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fixed_expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fixed_expense_instances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fixed_expense_change_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.credit_cards ENABLE ROW LEVEL SECURITY;

-- Users policies
DROP POLICY IF EXISTS "Users can view own data" ON public.users;
CREATE POLICY "Users can view own data" ON public.users
  FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own data" ON public.users;
CREATE POLICY "Users can update own data" ON public.users
  FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own data" ON public.users;
CREATE POLICY "Users can insert own data" ON public.users
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Accounts policies
DROP POLICY IF EXISTS "Users can view own accounts" ON public.accounts;
CREATE POLICY "Users can view own accounts" ON public.accounts
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own accounts" ON public.accounts;
CREATE POLICY "Users can insert own accounts" ON public.accounts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own accounts" ON public.accounts;
CREATE POLICY "Users can update own accounts" ON public.accounts
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own accounts" ON public.accounts;
CREATE POLICY "Users can delete own accounts" ON public.accounts
  FOR DELETE USING (auth.uid() = user_id);

-- Categories policies
DROP POLICY IF EXISTS "Users can view own categories" ON public.categories;
CREATE POLICY "Users can view own categories" ON public.categories
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own categories" ON public.categories;
CREATE POLICY "Users can insert own categories" ON public.categories
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own categories" ON public.categories;
CREATE POLICY "Users can update own categories" ON public.categories
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own categories" ON public.categories;
CREATE POLICY "Users can delete own categories" ON public.categories
  FOR DELETE USING (auth.uid() = user_id);

-- Fixed expenses policies
DROP POLICY IF EXISTS "Users can view own fixed expenses" ON public.fixed_expenses;
CREATE POLICY "Users can view own fixed expenses" ON public.fixed_expenses
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own fixed expenses" ON public.fixed_expenses;
CREATE POLICY "Users can insert own fixed expenses" ON public.fixed_expenses
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own fixed expenses" ON public.fixed_expenses;
CREATE POLICY "Users can update own fixed expenses" ON public.fixed_expenses
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own fixed expenses" ON public.fixed_expenses;
CREATE POLICY "Users can delete own fixed expenses" ON public.fixed_expenses
  FOR DELETE USING (auth.uid() = user_id);

-- Fixed expense instances policies
DROP POLICY IF EXISTS "Users can view own fixed expense instances" ON public.fixed_expense_instances;
CREATE POLICY "Users can view own fixed expense instances" ON public.fixed_expense_instances
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own fixed expense instances" ON public.fixed_expense_instances;
CREATE POLICY "Users can insert own fixed expense instances" ON public.fixed_expense_instances
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own fixed expense instances" ON public.fixed_expense_instances;
CREATE POLICY "Users can update own fixed expense instances" ON public.fixed_expense_instances
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own fixed expense instances" ON public.fixed_expense_instances;
CREATE POLICY "Users can delete own fixed expense instances" ON public.fixed_expense_instances
  FOR DELETE USING (auth.uid() = user_id);

-- Fixed expense change history policies
DROP POLICY IF EXISTS "Users can view own change history" ON public.fixed_expense_change_history;
CREATE POLICY "Users can view own change history" ON public.fixed_expense_change_history
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own change history" ON public.fixed_expense_change_history;
CREATE POLICY "Users can insert own change history" ON public.fixed_expense_change_history
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Transactions policies
DROP POLICY IF EXISTS "Users can view own transactions" ON public.transactions;
CREATE POLICY "Users can view own transactions" ON public.transactions
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own transactions" ON public.transactions;
CREATE POLICY "Users can insert own transactions" ON public.transactions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own transactions" ON public.transactions;
CREATE POLICY "Users can update own transactions" ON public.transactions
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own transactions" ON public.transactions;
CREATE POLICY "Users can delete own transactions" ON public.transactions
  FOR DELETE USING (auth.uid() = user_id);

-- Credit cards policies
DROP POLICY IF EXISTS "Users can view own credit cards" ON public.credit_cards;
CREATE POLICY "Users can view own credit cards" ON public.credit_cards
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own credit cards" ON public.credit_cards;
CREATE POLICY "Users can insert own credit cards" ON public.credit_cards
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own credit cards" ON public.credit_cards;
CREATE POLICY "Users can update own credit cards" ON public.credit_cards
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own credit cards" ON public.credit_cards;
CREATE POLICY "Users can delete own credit cards" ON public.credit_cards
  FOR DELETE USING (auth.uid() = user_id);


-- ========================================
-- PERFORMANCE INDEXES
-- ========================================

-- Create indexes for better performance
-- Create indexes for better performance
DROP INDEX IF EXISTS idx_accounts_user_id;
CREATE INDEX idx_accounts_user_id ON public.accounts(user_id);

DROP INDEX IF EXISTS idx_categories_user_id;
CREATE INDEX idx_categories_user_id ON public.categories(user_id);

DROP INDEX IF EXISTS idx_fixed_expenses_user_id;
CREATE INDEX idx_fixed_expenses_user_id ON public.fixed_expenses(user_id);

DROP INDEX IF EXISTS idx_fixed_expense_instances_user_id;
CREATE INDEX idx_fixed_expense_instances_user_id ON public.fixed_expense_instances(user_id);

DROP INDEX IF EXISTS idx_fixed_expense_instances_fixed_expense_id;
CREATE INDEX idx_fixed_expense_instances_fixed_expense_id ON public.fixed_expense_instances(fixed_expense_id);

DROP INDEX IF EXISTS idx_fixed_expense_instances_due_date;
CREATE INDEX idx_fixed_expense_instances_due_date ON public.fixed_expense_instances(due_date);

DROP INDEX IF EXISTS idx_fixed_expense_instances_status;
CREATE INDEX idx_fixed_expense_instances_status ON public.fixed_expense_instances(status);

DROP INDEX IF EXISTS idx_fixed_expense_change_history_user_id;
CREATE INDEX idx_fixed_expense_change_history_user_id ON public.fixed_expense_change_history(user_id);

DROP INDEX IF EXISTS idx_fixed_expense_change_history_fixed_expense_id;
CREATE INDEX idx_fixed_expense_change_history_fixed_expense_id ON public.fixed_expense_change_history(fixed_expense_id);

DROP INDEX IF EXISTS idx_fixed_expense_change_history_effective_date;
CREATE INDEX idx_fixed_expense_change_history_effective_date ON public.fixed_expense_change_history(effective_date);

DROP INDEX IF EXISTS idx_transactions_user_id;
CREATE INDEX idx_transactions_user_id ON public.transactions(user_id);

DROP INDEX IF EXISTS idx_transactions_date;
CREATE INDEX idx_transactions_date ON public.transactions(date);

DROP INDEX IF EXISTS idx_transactions_fixed_expense_instance_id;
CREATE INDEX idx_transactions_fixed_expense_instance_id ON public.transactions(fixed_expense_instance_id);

DROP INDEX IF EXISTS idx_transactions_related_transaction_id;
CREATE INDEX idx_transactions_related_transaction_id ON public.transactions(related_transaction_id);

DROP INDEX IF EXISTS idx_transactions_movement_type;
CREATE INDEX idx_transactions_movement_type ON public.transactions(movement_type);

DROP INDEX IF EXISTS idx_credit_cards_user_id;
CREATE INDEX idx_credit_cards_user_id ON public.credit_cards(user_id);


-- ========================================
-- FUNCTIONS AND TRIGGERS
-- ========================================

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
DROP TRIGGER IF EXISTS update_users_updated_at ON public.users;
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_accounts_updated_at ON public.accounts;
CREATE TRIGGER update_accounts_updated_at BEFORE UPDATE ON public.accounts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_fixed_expenses_updated_at ON public.fixed_expenses;
CREATE TRIGGER update_fixed_expenses_updated_at BEFORE UPDATE ON public.fixed_expenses
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_fixed_expense_instances_updated_at ON public.fixed_expense_instances;
CREATE TRIGGER update_fixed_expense_instances_updated_at BEFORE UPDATE ON public.fixed_expense_instances
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_credit_cards_updated_at ON public.credit_cards;
CREATE TRIGGER update_credit_cards_updated_at BEFORE UPDATE ON public.credit_cards
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
