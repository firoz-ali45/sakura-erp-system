-- ============================================
-- VERIFY ADMIN EMAIL (Set email_verified = false for OTP verification)
-- Run this in Supabase SQL Editor
-- ============================================

-- Set admin user's email_verified to false so they need OTP verification
UPDATE users 
SET email_verified = false
WHERE email = 'sakurapersonal071@gmail.com' 
  AND role = 'admin';

-- Verify the update
SELECT 
    email,
    name,
    role,
    status,
    email_verified,
    CASE 
        WHEN email_verified = false THEN '❌ Needs OTP Verification'
        WHEN email_verified = true THEN '✅ Email Verified'
        ELSE '❓ Unknown'
    END as verification_status
FROM users
WHERE email = 'sakurapersonal071@gmail.com';

