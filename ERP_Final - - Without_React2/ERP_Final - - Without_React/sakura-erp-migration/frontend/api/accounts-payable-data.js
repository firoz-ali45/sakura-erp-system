/**
 * Vercel Serverless API: Accounts Payable data from Google Sheets.
 * Fetches all 3 sheets in parallel and returns JSON. CDN cache makes repeat loads <1s.
 * Set env GOOGLE_SHEETS_API_KEY and optionally AP_SPREADSHEET_ID in Vercel.
 */
const SPREADSHEET_ID = process.env.AP_SPREADSHEET_ID || '1PmGAHvrOM1wnts4Xnp1Wmivrvqk8VnlWqOyp00mCfxw';
const API_KEY = process.env.GOOGLE_SHEETS_API_KEY;
const SHEETS = [
  { key: 'balanceSheet', name: 'Copy of Balance Sheet Database' },
  { key: 'invoices', name: 'Invoices (Data Base)' },
  { key: 'purchases', name: 'Daily Purchases (for Report) Net' }
];

const CACHE_MAX_AGE = 300;       // 5 min
const STALE_WHILE_REVALIDATE = 600;

async function fetchSheet(id, name, key) {
  const url = `https://sheets.googleapis.com/v4/spreadsheets/${id}/values/${encodeURIComponent(name)}?key=${key}`;
  const res = await fetch(url);
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Sheets API ${res.status}: ${text.slice(0, 200)}`);
  }
  const json = await res.json();
  return { key, values: json.values || [] };
}

export default async function handler(req, res) {
  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET');
    return res.status(405).json({ error: 'Method not allowed' });
  }

  if (!API_KEY) {
    res.status(500).json({ error: 'GOOGLE_SHEETS_API_KEY not configured' });
    return;
  }

  try {
    const results = await Promise.all(
      SHEETS.map(({ key, name }) => fetchSheet(SPREADSHEET_ID, name, key))
    );
    const body = {};
    results.forEach(({ key, values }) => { body[key] = { values }; });

    res.setHeader('Cache-Control', `public, s-maxage=${CACHE_MAX_AGE}, stale-while-revalidate=${STALE_WHILE_REVALIDATE}`);
    res.setHeader('Content-Type', 'application/json');
    return res.status(200).json(body);
  } catch (err) {
    console.error('AP data API error:', err.message);
    res.setHeader('Cache-Control', 'no-store');
    return res.status(502).json({ error: err.message || 'Failed to fetch sheets' });
  }
}
