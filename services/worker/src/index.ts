// Queue.ai worker — domain async jobs (docs/06-ARCHITECTURE.md §3,5).
// S0: health. S3: notification dispatcher (cost-aware, R6). Connects with the Supabase
// service-role key (bypasses RLS by design). Real ETA/no-show jobs land in S4.
import { createServer } from 'node:http';
import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { messageFor } from './messages.ts';

const PORT = Number(process.env.WORKER_PORT ?? 4000);
const SB_URL = process.env.NEXT_PUBLIC_SUPABASE_URL ?? process.env.SUPABASE_URL;
const SB_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

const admin: SupabaseClient | null =
  SB_URL && SB_KEY ? createClient(SB_URL, SB_KEY, { auth: { persistSession: false } }) : null;

// ── Notification dispatcher (R6 cost-aware) ──────────────────────────────────
// Picks queued notifications and sends them. Push is free; SMS via Termii/Africa's
// Talking only for high-value events. Without provider keys it marks them sent
// (simulated) so the pipeline is observable in dev.
async function dispatchNotifications() {
  if (!admin) return;
  const { data } = await admin
    .from('notifications').select('*').eq('status', 'queued').limit(20);
  for (const n of data ?? []) {
    const r = await send(n);
    await admin.from('notifications')
      .update({ status: r.ok ? 'sent' : 'failed', sent_at: new Date().toISOString(),
                provider: r.provider, provider_ref: r.ref ?? null })
      .eq('id', n.id);
  }
}

type SendResult = { ok: boolean; provider: string; ref?: string };

async function send(n: Record<string, any>): Promise<SendResult> {
  const text = messageFor(n.event_type);

  // WhatsApp channel (Meta Cloud API) — needs the recipient's number (decrypt via RPC)
  if (n.channel === 'whatsapp' && process.env.WHATSAPP_TOKEN && process.env.WHATSAPP_PHONE_NUMBER_ID && admin) {
    const { data } = await admin.rpc('get_sms_target', { p_notification_id: n.id });
    const phone = (data as { phone?: string } | null)?.phone?.replace(/^\+/, '');
    if (!phone) { console.warn(`[notify] no phone for ${n.id}`); return { ok: false, provider: 'whatsapp_cloud' }; }
    try {
      const res = await fetch(`https://graph.facebook.com/v21.0/${process.env.WHATSAPP_PHONE_NUMBER_ID}/messages`, {
        method: 'POST',
        headers: { authorization: `Bearer ${process.env.WHATSAPP_TOKEN}`, 'content-type': 'application/json' },
        body: JSON.stringify({ messaging_product: 'whatsapp', to: phone, type: 'text', text: { body: text } }),
      });
      if (!res.ok) { console.error(`[notify] WhatsApp ${res.status}`); return { ok: false, provider: 'whatsapp_cloud' }; }
      const body = await res.json().catch(() => ({}));
      return { ok: true, provider: 'whatsapp_cloud', ref: body?.messages?.[0]?.id };
    } catch (e) { console.error('[notify] whatsapp error', e); return { ok: false, provider: 'whatsapp_cloud' }; }
  }

  const termiiKey = process.env.TERMII_API_KEY;
  if (termiiKey && admin) {
    // resolve the (encrypted) recipient via the service-role-only RPC, then send
    const { data } = await admin.rpc('get_sms_target', { p_notification_id: n.id });
    const phone = (data as { phone?: string } | null)?.phone;
    if (!phone) { console.warn(`[notify] no phone for ${n.id}`); return { ok: false, provider: 'termii' }; }
    try {
      const res = await fetch('https://api.ng.termii.com/api/sms/send', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          to: phone, from: process.env.TERMII_SENDER_ID ?? 'Queue.ai',
          sms: text, type: 'plain', channel: 'generic', api_key: termiiKey,
        }),
      });
      const body = await res.json().catch(() => ({}));
      // Termii returns 200 with a code; surface failures (insufficient balance, bad sender, etc.)
      if (!res.ok || (body?.code && body.code !== 'ok')) {
        console.error(`[notify] Termii ${res.status}`, body?.message ?? '');
        return { ok: false, provider: 'termii', ref: body?.message };
      }
      return { ok: true, provider: 'termii', ref: body?.message_id };
    } catch (e) { console.error('[notify] send error', e); return { ok: false, provider: 'termii' }; }
  }
  console.log(`[notify] (simulated) ${n.channel}:${n.event_type} -> "${text}" (${n.id})`);
  return { ok: true, provider: 'simulated' }; // dev: no provider key
}

// ── No-show grace sweep (R4): called stages past their grace_deadline → no_show ──
async function sweepNoShows() {
  if (!admin) return;
  const { data } = await admin
    .from('visit_stages').select('id, organization_id, visit_id')
    .eq('state', 'called').lt('grace_deadline', new Date().toISOString()).limit(50);
  for (const s of data ?? []) {
    await admin.from('visit_stages').update({ state: 'no_show', entered_state_at: new Date().toISOString() }).eq('id', s.id);
    await admin.from('activity_events').insert({
      organization_id: s.organization_id, entity_type: 'visit_stage', entity_id: s.id,
      event_type: 'state_change', from_state: 'called', to_state: 'no_show', actor_type: 'system',
    });
  }
}

const server = createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ ok: true, service: 'queue-ai-worker', supabase: Boolean(admin), ts: new Date().toISOString() }));
    return;
  }
  res.writeHead(404); res.end();
});

// ── Intelligence rollups (audit H1): populate staff_throughput + daily_metrics ──
async function rollups() {
  if (!admin) return;
  await admin.rpc('rollup_throughput', { p_window_min: 60 });
  await admin.rpc('rollup_daily_metrics');
}

// ── Trust-Engine accuracy loop (0026): snapshot ETAs, then score them vs actuals ──
async function predictions() {
  if (!admin) return;
  await admin.rpc('snapshot_active_predictions');
  await admin.rpc('score_pending_predictions');
}

// ── "Leave now" alert (0030): pull parked patients into the queue at the right moment ──
async function leaveNow() {
  if (!admin) return;
  await admin.rpc('process_leave_now');
}

server.listen(PORT, () => {
  console.log(`[worker] listening on :${PORT}${admin ? '' : ' (no Supabase creds — jobs idle)'}`);
  if (admin) {
    setInterval(() => { dispatchNotifications().catch((e) => console.error('[notify]', e)); }, 5000);
    setInterval(() => { sweepNoShows().catch((e) => console.error('[sweep]', e)); }, 15000);
    setInterval(() => { rollups().catch((e) => console.error('[rollup]', e)); }, 15 * 60 * 1000);
    setInterval(() => { predictions().catch((e) => console.error('[predict]', e)); }, 30 * 1000);
    setInterval(() => { leaveNow().catch((e) => console.error('[leave]', e)); }, 30 * 1000);
    rollups().catch((e) => console.error('[rollup]', e)); // once on boot
  }
});
