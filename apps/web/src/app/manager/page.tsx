'use client';
import { useCallback, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { getSupabase } from '@/lib/supabase';
import { useSession } from '@/lib/useSession';
import { Card, Button } from '@/lib/ui';
import { askAssistant, dailySummary, type Overview, type AssistantResult } from '@/lib/assistant';

type Row = Record<string, any>;
const mins = (s: number) => Math.round(s / 60);
const statusColor: Record<string, string> = {
  calm: 'text-status-calm', busy: 'text-status-busy', delayed: 'text-status-delayed',
};
const dot: Record<string, string> = { calm: '🟢', busy: '🟡', delayed: '🔴' };

export default function ManagerPage() {
  const router = useRouter();
  const { loading, userId, organizationId } = useSession();
  const [branches, setBranches] = useState<Row[]>([]);
  const [branchId, setBranchId] = useState('');
  const [o, setO] = useState<Overview | null>(null);
  const [hr, setHr] = useState<{ today_seconds: number; month_seconds: number; lifetime_seconds: number } | null>(null);
  const [q, setQ] = useState('');
  const [a, setA] = useState<AssistantResult | null>(null);
  const [ops, setOps] = useState<Row[]>([]);
  const [sim, setSim] = useState<Row | null>(null);

  useEffect(() => {
    if (!organizationId) return;
    getSupabase().from('branches').select('*').order('created_at').then(({ data }) => {
      setBranches(data ?? []); if (data?.[0]) setBranchId((b) => b || data[0].id);
    });
  }, [organizationId]);

  const load = useCallback(async () => {
    if (!branchId) return;
    const sb = getSupabase();
    const [ov, hours, pops] = await Promise.all([
      sb.rpc('get_flow_overview', { p_branch_id: branchId }),
      sb.rpc('get_hours_returned', { p_branch_id: branchId }),
      sb.rpc('get_predictive_ops', { p_branch_id: branchId }),
    ]);
    if (ov.data) setO(ov.data as Overview);
    if (hours.data) setHr(hours.data as typeof hr);
    setOps((pops.data as Row[]) ?? []);
  }, [branchId]);

  const runSim = async (add: number, remove: number) => {
    const { data } = await getSupabase().rpc('simulate_branch',
      { p_branch_id: branchId, p_add_staff: add, p_remove_staff: remove });
    setSim(data as Row);
  };

  useEffect(() => {
    load();
    const sb = getSupabase();
    const ch = sb.channel('mgr').on('postgres_changes', { event: '*', schema: 'public', table: 'visit_stages' }, () => load()).subscribe();
    const poll = setInterval(load, 8000);
    return () => { clearInterval(poll); sb.removeChannel(ch); };
  }, [load]);

  if (loading) return <main className="p-10 text-sm text-muted">Loading…</main>;
  if (!userId) { router.push('/login'); return null; }
  if (!organizationId) { router.push('/onboarding'); return null; }

  const ask = async () => { if (o && q) setA(await askAssistant(q, o)); };

  return (
    <div className="min-h-screen">
      <header className="flex items-center justify-between border-b border-line bg-surface px-6 py-3">
        <span className="text-sm font-semibold text-accent">Queue.ai · Manager</span>
        <select value={branchId} onChange={(e) => setBranchId(e.target.value)}
          className="rounded-control border border-line px-2 py-1 text-sm">
          {branches.map((b) => <option key={b.id} value={b.id}>{b.name}</option>)}
        </select>
      </header>

      <main className="mx-auto max-w-5xl space-y-6 px-6 py-8">
        {!o ? <p className="text-sm text-muted">Loading overview…</p> : (
          <>
            {/* Hours Returned — the mission KPI, everywhere (Law #0) */}
            {hr && (
              <div className="rounded-card bg-neutral-900 p-5 text-white">
                <p className="text-xs uppercase tracking-widest text-faint">Hours Returned</p>
                <div className="mt-2 flex flex-wrap gap-10">
                  <HR label="Today" seconds={hr.today_seconds} big />
                  <HR label="This month" seconds={hr.month_seconds} />
                  <HR label="Since joining" seconds={hr.lifetime_seconds} />
                </div>
              </div>
            )}

            {/* Flow Score hero + quiet metrics */}
            <div className="flex flex-wrap items-center gap-8">
              <div>
                <p className="text-xs uppercase tracking-wide text-faint">Flow Score</p>
                <p className="tnum text-5xl font-semibold">{o.flow_score}<span className="text-2xl text-faint">/100</span></p>
              </div>
              <Metric label="Waiting" value={`${o.waiting_total}`} />
              <Metric label="Avg wait" value={`${mins(o.avg_wait_seconds)}m`} />
              <Metric label="No-show" value={`${Math.round(o.no_show_rate * 100)}%`} />
              <Metric label="Served today" value={`${o.served_today}`} />
              <Metric label="⏱ Time saved today" value={`${Math.round(o.time_saved_seconds / 3600)}h`} highlight />
            </div>

            {/* Digital Twin board (F3-lite) */}
            <Card title="Digital Twin — live">
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4">
                {o.departments.map((d) => (
                  <div key={d.name} className="rounded-control border border-line p-3">
                    <p className="text-sm font-medium">{d.name}</p>
                    <p className={`mt-1 text-sm ${statusColor[d.status]}`}>{dot[d.status]} {d.waiting} waiting</p>
                    <p className="text-xs text-faint">longest ~{mins(d.longest_wait_s)}m</p>
                  </div>
                ))}
              </div>
            </Card>

            {/* Predictive Operations (F13) + Capacity recommendation */}
            <Card title="⚠ Predictive Operations">
              {ops.length === 0 ? (
                <p className="text-sm text-status-calm">No bottlenecks predicted — all departments within target.</p>
              ) : (
                <ul className="space-y-2">
                  {ops.map((w, i) => (
                    <li key={i} className="rounded-control border border-status-busy/30 bg-status-busy/5 p-3 text-sm">
                      <p className="font-medium text-ink">
                        {w.department} will stay overloaded ~{w.clear_min} min ({w.waiting} waiting · {w.servers} staff)
                      </p>
                      <p className="text-muted">→ {w.recommend} (projected clear ~{w.projected_clear_min} min)</p>
                    </li>
                  ))}
                </ul>
              )}
              <p className="mt-2 text-xs text-faint">Heuristic forecast — sharpens as the pilot accumulates data (v2).</p>
            </Card>

            {/* Simulation (F5) — what-if staffing */}
            <Card title="🔮 Simulation — what if?">
              <div className="flex flex-wrap items-center gap-2">
                <Button variant="ghost" onClick={() => runSim(1, 0)}>+1 staff</Button>
                <Button variant="ghost" onClick={() => runSim(2, 0)}>+2 staff</Button>
                <Button variant="ghost" onClick={() => runSim(0, 1)}>−1 staff (close a counter)</Button>
              </div>
              {sim && (
                <p className="mt-3 text-sm">
                  Avg wait {sim.current_avg_wait_min}m → <strong>{sim.projected_avg_wait_min}m</strong>{' '}
                  <span className={Number(sim.delta_pct) <= 0 ? 'text-status-calm' : 'text-status-delayed'}>
                    ({Number(sim.delta_pct) > 0 ? '+' : ''}{sim.delta_pct}%)
                  </span>{' '}
                  <span className="text-faint">· {sim.servers}→{sim.new_servers} staff, {sim.waiting} waiting</span>
                </p>
              )}
            </Card>

            {/* Grounded Flow Intelligence (mock generation, real numbers) */}
            <Card title="🧠 Flow Intelligence">
              <p className="text-sm text-ink">{dailySummary(o)}</p>
              <div className="mt-4 flex gap-2">
                <input value={q} onChange={(e) => setQ(e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && ask()}
                  placeholder="Ask: why is today slower?"
                  className="flex-1 rounded-control border border-line px-3 py-2 text-sm" />
                <Button onClick={ask}>Ask</Button>
              </div>
              {a && (
                <div className="mt-3 rounded-control bg-canvas p-3 text-sm">
                  <p className="text-ink">{a.answer}</p>
                  <p className="mt-2 text-xs text-faint">grounded in: {a.citations.join(' · ')}</p>
                </div>
              )}
              <p className="mt-2 text-xs text-faint">Answers use live metrics only (mock generation — Claude swap-in ready).</p>
            </Card>
          </>
        )}
      </main>
    </div>
  );
}

function HR({ label, seconds, big }: { label: string; seconds: number; big?: boolean }) {
  const hours = (seconds / 3600);
  const txt = hours >= 100 ? Math.round(hours).toLocaleString() : hours.toFixed(1);
  return (
    <div>
      <p className="text-xs text-faint">{label}</p>
      <p className={`tnum font-semibold ${big ? 'text-4xl text-status-calm' : 'text-2xl'}`}>{txt}<span className="ml-1 text-base text-faint">h</span></p>
    </div>
  );
}

function Metric({ label, value, highlight }: { label: string; value: string; highlight?: boolean }) {
  return (
    <div>
      <p className="text-xs uppercase tracking-wide text-faint">{label}</p>
      <p className={`tnum text-2xl font-semibold ${highlight ? 'text-status-calm' : ''}`}>{value}</p>
    </div>
  );
}
