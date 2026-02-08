-- ============================================
-- CHUNK 2: Fix RLS Policies
-- ============================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all SELECT" ON users;
DROP POLICY IF EXISTS "Allow all INSERT" ON users;
DROP POLICY IF EXISTS "Allow all UPDATE" ON users;
DROP POLICY IF EXISTS "Allow all DELETE" ON users;

CREATE POLICY "Allow all SELECT" ON users FOR SELECT USING (true);
CREATE POLICY "Allow all INSERT" ON users FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow all UPDATE" ON users FOR UPDATE USING (true);
CREATE POLICY "Allow all DELETE" ON users FOR DELETE USING (true);

