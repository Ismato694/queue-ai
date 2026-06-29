// WhatsApp join channel (Meta WhatsApp Cloud API webhook).
// GET  → webhook verification handshake (hub.challenge).
// POST → inbound messages. A patient texts "JOIN <code>" (prefilled by the wa.me
//        deep link on the join page); we join_queue(channel='whatsapp') and reply
//        with their live tracker link + ETA. Stateless, no PII stored beyond the
//        normal customer record (phone is encrypted by join_queue).
import { createClient } from '@supabase/supabase-js';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

const SB_URL = process.env.SUPABASE_URL ?? process.env.NEXT_PUBLIC_SUPABASE_URL;
const SB_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ?? process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
const APP_URL = process.env.NEXT_PUBLIC_APP_URL ?? '';
const WA_TOKEN = process.env.WHATSAPP_TOKEN;
const WA_PHONE_ID = process.env.WHATSAPP_PHONE_NUMBER_ID;
const VERIFY_TOKEN = process.env.WHATSAPP_VERIFY_TOKEN ?? 'queue-ai';

const mins = (s: number) => Math.max(1, Math.round(s / 60));

// ── Webhook verification (Meta calls this once when you set the callback URL) ──
export async function GET(req: Request) {
  const u = new URL(req.url);
  if (u.searchParams.get('hub.mode') === 'subscribe'
      && u.searchParams.get('hub.verify_token') === VERIFY_TOKEN) {
    return new Response(u.searchParams.get('hub.challenge') ?? '', { status: 200 });
  }
  return new Response('forbidden', { status: 403 });
}

// ── Inbound messages ──────────────────────────────────────────────────────────
export async function POST(req: Request) {
  let body: any;
  try { body = await req.json(); } catch { return new Response('ok', { status: 200 }); }

  try {
    const value = body?.entry?.[0]?.changes?.[0]?.value;
    const msg = value?.messages?.[0];
    const from: string | undefined = msg?.from; // E.164 without '+'
    const text: string | undefined = msg?.text?.body;
    const profileName: string | undefined = value?.contacts?.[0]?.profile?.name;
    if (from && text) await handle(from, text.trim(), profileName);
  } catch (e) {
    console.error('[whatsapp] handler error', e);
  }
  // Always 200 — Meta retries non-200 aggressively.
  return new Response('ok', { status: 200 });
}

async function handle(from: string, text: string, name?: string) {
  const m = text.match(/^join\s+(\S+)/i) ?? text.match(/^([A-Za-z0-9-]{6,})$/);
  if (!m) {
    await reply(from,
      'To join a queue, tap the "Join on WhatsApp" link at the location, or reply: JOIN <code>.');
    return;
  }
  if (!SB_URL || !SB_KEY) { await reply(from, 'Service is temporarily unavailable. Please try again shortly.'); return; }

  const sb = createClient(SB_URL, SB_KEY, { auth: { persistSession: false } });
  const phone = from.startsWith('+') ? from : `+${from}`;
  const { data: visitId, error } = await sb.rpc('join_queue', {
    p_branch_token: m[1], p_flow_id: null, p_name: name || 'Guest',
    p_phone: phone, p_channel: 'whatsapp', p_immediate: false,
  });
  if (error || !visitId) {
    await reply(from, error?.message?.includes('too many')
      ? "You've joined recently — please wait a moment before trying again."
      : "We couldn't find that queue. Double-check the code and try again.");
    return;
  }

  const { data: status } = await sb.rpc('get_visit_status', { p_visit_id: visitId });
  const eta = status?.eta_high_s != null ? `about ${mins(status.eta_high_s)} min` : 'being calculated';
  const link = APP_URL ? `\nTrack it live: ${APP_URL}/visit/${visitId}` : '';
  await reply(from,
    `You're in the queue at ${status?.branch_name ?? 'the clinic'}. Estimated wait: ${eta}.` +
    `${link}\nWe'll message you when it's almost your turn.`);
}

// ── Outbound reply via Graph API (simulated in dev when no token is set) ────────
async function reply(to: string, text: string) {
  if (!WA_TOKEN || !WA_PHONE_ID) {
    console.log(`[whatsapp] (simulated) -> ${to}: ${text}`);
    return;
  }
  try {
    await fetch(`https://graph.facebook.com/v21.0/${WA_PHONE_ID}/messages`, {
      method: 'POST',
      headers: { authorization: `Bearer ${WA_TOKEN}`, 'content-type': 'application/json' },
      body: JSON.stringify({ messaging_product: 'whatsapp', to, type: 'text', text: { body: text } }),
    });
  } catch (e) { console.error('[whatsapp] send error', e); }
}
