-- ============================================
-- SIMPLE SQL - Run ONE at a time
-- ============================================

-- ==================== CHUNK 1: Create Users Table ====================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    password_hash TEXT,
    phone TEXT,
    role TEXT DEFAULT 'user',
    status TEXT DEFAULT 'inactive',
    permissions JSONB DEFAULT '{}'::jsonb,
    notes TEXT,
    profile_photo_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login TIMESTAMP WITH TIME ZONE,
    last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    approved_by UUID,
    approved_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

INSERT INTO users (email, name, role, status, permissions) VALUES 
('sakurapersonal071@gmail.com', 'Firoz Admin', 'admin', 'active', '{"userManagement": true}'::jsonb)
ON CONFLICT (email) DO NOTHING;

