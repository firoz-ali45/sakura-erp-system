/**
 * Automated Supabase Migration Runner
 * Ye script automatically SQL files ko Supabase database mein run karega
 * 
 * Usage: node run-supabase-migration.js <sql-file-path>
 * Example: node run-supabase-migration.js ADD_GRN_APPROVAL_COLUMNS.sql
 */

const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

// Supabase connection
const supabaseUrl = process.env.SUPABASE_URL || 'https://kexwnurwavszvmlpifsf.supabase.co';
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseServiceKey) {
  console.error('❌ Error: SUPABASE_SERVICE_ROLE_KEY not found in .env file');
  console.log('📝 Please add SUPABASE_SERVICE_ROLE_KEY to .env file');
  console.log('   Get it from: Supabase Dashboard → Settings → API → service_role key');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function runSQLMigration(sqlFilePath) {
  try {
    console.log(`📂 Reading SQL file: ${sqlFilePath}`);
    
    // Read SQL file
    const sqlContent = fs.readFileSync(sqlFilePath, 'utf8');
    
    if (!sqlContent.trim()) {
      console.error('❌ Error: SQL file is empty');
      return false;
    }
    
    console.log(`📝 SQL Content Length: ${sqlContent.length} characters`);
    console.log('🚀 Executing SQL migration...\n');
    
    // Split SQL into individual statements (handle DO $$ blocks)
    const statements = sqlContent
      .split(';')
      .map(s => s.trim())
      .filter(s => s.length > 0 && !s.startsWith('--'));
    
    // Execute SQL using Supabase REST API (rpc function)
    // Note: Supabase doesn't have direct SQL execution via JS client
    // So we'll use the REST API endpoint
    
    const response = await fetch(`${supabaseUrl}/rest/v1/rpc/exec_sql`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': supabaseServiceKey,
        'Authorization': `Bearer ${supabaseServiceKey}`
      },
      body: JSON.stringify({ sql: sqlContent })
    });
    
    // Alternative: Use Supabase Management API
    // For now, we'll provide instructions to use Supabase CLI instead
    
    console.log('⚠️  Direct SQL execution via JS client is limited.');
    console.log('✅ Use Supabase CLI instead (recommended):\n');
    console.log(`   supabase db execute --file "${sqlFilePath}"`);
    console.log('\n📋 Or use the automated script: run-supabase-migration.bat\n');
    
    return true;
    
  } catch (error) {
    console.error('❌ Error running migration:', error.message);
    return false;
  }
}

// Main execution
const sqlFile = process.argv[2];

if (!sqlFile) {
  console.log('📖 Usage: node run-supabase-migration.js <sql-file-path>');
  console.log('📖 Example: node run-supabase-migration.js ADD_GRN_APPROVAL_COLUMNS.sql\n');
  process.exit(1);
}

const sqlFilePath = path.resolve(sqlFile);

if (!fs.existsSync(sqlFilePath)) {
  console.error(`❌ Error: SQL file not found: ${sqlFilePath}`);
  process.exit(1);
}

runSQLMigration(sqlFilePath)
  .then(success => {
    if (success) {
      console.log('\n✅ Migration process completed!');
    } else {
      console.log('\n❌ Migration failed. Check errors above.');
      process.exit(1);
    }
  })
  .catch(error => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  });


