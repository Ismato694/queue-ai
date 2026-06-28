// Queue.ai worker — domain async jobs (docs/06-ARCHITECTURE.md §3,5).
// S0: health endpoint + job stubs. Real logic (ETA recompute, no-show sweep, notifications, AI)
// lands in S2–S5. Connects with the Supabase service-role key (bypasses RLS by design).
import { createServer } from 'node:http';

const PORT = Number(process.env.WORKER_PORT ?? 4000);

// ── Job stubs (wired to BullMQ / pg_cron in later sprints) ──
async function recomputeETA(_branchId: string, _departmentId: string) {
  // S4: heuristic ETA + confidence + reasons (Trust Engine F11) → predictions table.
}
async function sweepNoShows() {
  // S4: stages past grace_deadline in 'called' → no_show or requeue (R4).
}
async function rollupDailyMetrics() {
  // S5: Flow Score + Time-Saved (Law #0) → daily_metrics.
}

const server = createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ ok: true, service: 'queue-ai-worker', ts: new Date().toISOString() }));
    return;
  }
  res.writeHead(404);
  res.end();
});

server.listen(PORT, () => {
  console.log(`[worker] listening on :${PORT} (job handlers stubbed for S0)`);
  // Prevent unused-symbol lint in S0; these are invoked by the queue/cron in later sprints.
  void recomputeETA; void sweepNoShows; void rollupDailyMetrics;
});
