-- ============================================
-- UPDATE ADMIN PASSWORD
-- Run this in Supabase SQL Editor
-- ============================================

-- Update admin user password
UPDATE users 
SET password_hash = 'Firoz112233@@'
WHERE email = 'sakurapersonal071@gmail.com';

-- Verify update
SELECT email, name, role, status, 
       CASE 
           WHEN password_hash IS NOT NULL THEN 'Password set'
           ELSE 'No password'
       END AS password_status
FROM users 
WHERE email = 'sakurapersonal071@gmail.com';

