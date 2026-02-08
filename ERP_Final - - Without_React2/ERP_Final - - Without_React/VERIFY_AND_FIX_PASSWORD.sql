-- ============================================
-- VERIFY AND FIX ADMIN PASSWORD
-- Run this in Supabase SQL Editor
-- ============================================

-- Step 1: Check current password status
SELECT 
    email,
    name,
    role,
    status,
    CASE 
        WHEN password_hash IS NULL THEN 'NULL - No password set'
        WHEN password_hash = '' THEN 'EMPTY - Empty password'
        ELSE 'SET - Password exists (length: ' || LENGTH(password_hash) || ')'
    END AS password_status,
    password_hash
FROM users 
WHERE email = 'sakurapersonal071@gmail.com';

-- Step 2: Update password (uncomment and run if needed)
-- UPDATE users 
-- SET password_hash = 'Firoz112233@@'
-- WHERE email = 'sakurapersonal071@gmail.com';

-- Step 3: Verify update
-- SELECT 
--     email,
--     name,
--     role,
--     status,
--     password_hash,
--     LENGTH(password_hash) AS password_length
-- FROM users 
-- WHERE email = 'sakurapersonal071@gmail.com';

