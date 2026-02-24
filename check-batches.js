const fs = require('fs');
const path = require('path');
const envPath = path.join(__dirname, 'ERP_Final - - Without_React2', 'ERP_Final - - Without_React', 'sakura-erp-migration', 'backend', '.env');
if (fs.existsSync(envPath)) {
  fs.readFileSync(envPath, 'utf8').split('\n').forEach(line => {
    const idx = line.indexOf('=');
    if (idx > 0 && !line.startsWith('#')) {
      process.env[line.slice(0, idx).trim()] = line.slice(idx + 1).trim().replace(/^["']|["']$/g, '');
    }
  });
}
async function run() {
  const postgres = (await import('postgres')).default;
  const sql = postgres(process.env.DATABASE_URL, { max: 1 });
  const r = await sql.unsafe(`SELECT column_name, is_nullable, column_default FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'batches' ORDER BY ordinal_position`);
  console.log('batches columns:', r);
  const r2 = await sql.unsafe(`SELECT pg_get_viewdef('public.grn_batches'::regclass, true)`);
  console.log('grn_batches view:', r2[0]?.pg_get_viewdef);
  await sql.end();
}
run().catch(e => console.error(e));
