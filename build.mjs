#!/usr/bin/env node
/**
 * Root build script for Vercel when Root Directory is empty.
 * Runs npm ci + npm run build in the frontend subdirectory.
 */
import { spawnSync } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const frontendDir = path.join(
  __dirname,
  'ERP_Final - - Without_React2',
  'ERP_Final - - Without_React',
  'sakura-erp-migration',
  'frontend'
);

console.log('Building frontend from:', frontendDir);

const ci = spawnSync('npm', ['ci'], { cwd: frontendDir, stdio: 'inherit', shell: true });
if (ci.status !== 0) process.exit(ci.status ?? 1);

const build = spawnSync('npm', ['run', 'build'], { cwd: frontendDir, stdio: 'inherit', shell: true });
process.exit(build.status ?? (build.signal ? 1 : 0));
