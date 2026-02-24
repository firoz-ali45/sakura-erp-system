#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

// Load DATABASE_URL from backend .env
const envPath = path.join(__dirname, 'ERP_Final - - Without_React2', 'ERP_Final - - Without_React', 'sakura-erp-migration', 'backend', '.env');
if (fs.existsSync(envPath)) {
  fs.readFileSync(envPath, 'utf8').split('\n').forEach(line => {
    const idx = line.indexOf('=');
    if (idx > 0 && !line.startsWith('#')) {
      const k = line.slice(0, idx).trim();
      let v = line.slice(idx + 1).trim();
      if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) v = v.slice(1, -1);
      process.env[k] = v;
    }
  });
}

// Use simplified migration for production schema (_deprecated_* tables)
let sql = fs.readFileSync(path.join(__dirname, 'migrations', '20260224000001_unified_batch_id_grn_only.sql'), 'utf8');

async function run() {
  const postgres = (await import('postgres')).default;
  const url = process.env.DATABASE_URL;
  if (!url) {
    console.error('❌ DATABASE_URL not found');
    process.exit(1);
  }
  console.log('🚀 Running Unified Batch ID migration...');
  const sqlClient = postgres(url, { max: 1 });
  await sqlClient.unsafe(sql);
  await sqlClient.end();
  console.log('✅ Migration completed successfully!');
}

run().catch(err => { console.error('❌', err.message); process.exit(1); });
