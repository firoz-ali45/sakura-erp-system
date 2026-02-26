#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

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

const sql = `ALTER TABLE public.batches DROP CONSTRAINT IF EXISTS batches_qc_status_check;
ALTER TABLE public.batches ADD CONSTRAINT batches_qc_status_check
  CHECK (qc_status IN ('pending', 'passed', 'failed', 'on_hold', 'expired', 'approved', 'rejected', 'PASS', 'HOLD', 'FAIL', 'REJECT'));`;

async function run() {
  const postgres = (await import('postgres')).default;
  const url = process.env.DATABASE_URL;
  if (!url) {
    console.error('DATABASE_URL not found in backend .env');
    process.exit(1);
  }
  const db = postgres(url, { max: 1 });
  await db.unsafe(sql);
  await db.end();
  console.log('Done: batches_qc_status_check updated');
}

run().catch(e => { console.error(e.message); process.exit(1); });
