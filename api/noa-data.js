// Read-only data feed for NOA Oficina IA's agents — same pattern as
// HK Interno's and HK Control's own api/noa-data.js.
//
// Token-gated (NOA_ACCESS_TOKEN, set in Vercel env vars) so only NOA's
// backend can call this — never called from a browser, and never
// touches anything the public site (index.html) already does.
//
// Uses the Supabase SERVICE ROLE key (server-side only, never the anon
// key the public site uses) because `inscripciones` has RLS enabled
// with no anonymous-read policy — the anon key can only INSERT new
// registrations, never read them back. This is a brand-new, separate
// read path; it doesn't change any existing RLS policy or any behavior
// of the public site.
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://dqxmcqenqedehlorvwms.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

async function fetchTable(table) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?select=*&order=created_at.desc`, {
    headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` },
  });
  if (!res.ok) return [];
  return res.json();
}

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, x-noa-token');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'GET') return res.status(405).json({ error: 'method not allowed' });

  const token = (req.headers['authorization'] || '').replace(/^Bearer\s+/i, '') || req.headers['x-noa-token'];
  if (!token || token !== process.env.NOA_ACCESS_TOKEN) {
    return res.status(401).json({ error: 'No autorizado' });
  }
  if (!SUPABASE_SERVICE_ROLE_KEY) {
    return res.status(500).json({ error: 'falta SUPABASE_SERVICE_ROLE_KEY en Vercel' });
  }

  try {
    const inscripciones = await fetchTable('inscripciones');
    return res.status(200).json({ inscripciones });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
};
