// Queue.ai worker — domain async jobs (docs/06-ARCHITECTURE.md §3,5).
// S0: health. S3: notification dispatcher (cost-aware, R6). Connects with the Supabase
// service-role key (bypasses RLS by design). Real ETA/no-show jobs land in S4.
import { createServer } from 'node:http';
import { createClient, type SupabaseClient } from '@supabase/supabase-js';

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
    const ok = await send(n);
    await admin.from('notifications')
      .update({ status: ok ? 'sent' : 'failed', sent_at: new Date().toISOString() })
      .eq('id', n.id);
  }
}

async function send(n: Record<string, any>): Promise<boolean> {
  const text = messageFor(n.event_type);
  // Provider integration (Termii / Africa's Talking) plugs in here once keys exist.
  if (process.env.TERMII_API_KEY || process.env.AFRICASTALKING_API_KEY) {
    // TODO(S6): real SMS send via provider HTTP API; needs a recipient phone lookup.
    console.log(`[notify] (provider) would send "${text}" for ${n.id}`);
    return true;
  }
  console.log(`[notify] (simulated) ${n.channel}:${n.event_type} -> "${text}" (${n.id})`);
  return true; // simulated success in dev
}

function messageFor(event: string): string {
  switch (event) {
    case 'your_turn': return "It's almost your turn — please proceed to the counter.";
    case 'delayed':   return 'Your wait has increased slightly. Thanks for your patience.';
    default:          return 'Update on your visit.';
  }
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

server.listen(PORT, () => {
  console.log(`[worker] listening on :${PORT}${admin ? '' : ' (no Supabase creds — jobs idle)'}`);
  if (admin) {
    setInterval(() => { dispatchNotifications().catch((e) => console.error('[notify]', e)); }, 5000);
    setInterval(() => { sweepNoShows().catch((e) => console.error('[sweep]', e)); }, 15000);
  }
});
