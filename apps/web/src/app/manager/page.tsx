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
  const [q, setQ] = useState('');
  const [a, setA] = useState<AssistantResult | null>(null);

  useEffect(() => {
    if (!organizationId) return;
    getSupabase().from('branches').select('*').order('created_at').then(({ data }) => {
      setBranches(data ?? []); if (data?.[0]) setBranchId((b) => b || data[0].id);
    });
  }, [organizationId]);

  const load = useCallback(async () => {
    if (!branchId) return;
    const { data } = await getSupabase().rpc('get_flow_overview', { p_branch_id: branchId });
    if (data) setO(data as Overview);
  }, [branchId]);

  useEffect(() => {
    load();
    const sb = getSupabase();
    const ch = sb.channel('mgr').on('postgres_changes', { event: '*', schema: 'public', table: 'visit_stages' }, () => load()).subscribe();
    const poll = setInterval(load, 8000);
    return () => { clearInterval(poll); sb.removeChannel(ch); };
  }, [load]);

  if (loading) return <main className="p-10 text-sm text-neutral-500">Loading…</main>;
  if (!userId) { router.push('/login'); return null; }
  if (!organizationId) { router.push('/onboarding'); return null; }

  const ask = async () => { if (o && q) setA(await askAssistant(q, o)); };

  return (
    <div className="min-h-screen">
      <header className="flex items-center justify-between border-b border-neutral-200 bg-white px-6 py-3">
        <span className="text-sm font-semibold text-accent">Queue.ai · Manager</span>
        <select value={branchId} onChange={(e) => setBranchId(e.target.value)}
          className="rounded-control border border-neutral-300 px-2 py-1 text-sm">
          {branches.map((b) => <option key={b.id} value={b.id}>{b.name}</option>)}
        </select>
      </header>

      <main className="mx-auto max-w-5xl space-y-6 px-6 py-8">
        {!o ? <p className="text-sm text-neutral-500">Loading overview…</p> : (
          <>
            {/* Flow Score hero + quiet metrics */}
            <div className="flex flex-wrap items-center gap-8">
              <div>
                <p className="text-xs uppercase tracking-wide text-neutral-400">Flow Score</p>
                <p className="tnum text-5xl font-semibold">{o.flow_score}<span className="text-2xl text-neutral-400">/100</span></p>
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
                  <div key={d.name} className="rounded-control border border-neutral-200 p-3">
                    <p className="text-sm font-medium">{d.name}</p>
                    <p className={`mt-1 text-sm ${statusColor[d.status]}`}>{dot[d.status]} {d.waiting} waiting</p>
                    <p className="text-xs text-neutral-400">longest ~{mins(d.longest_wait_s)}m</p>
                  </div>
                ))}
              </div>
            </Card>

            {/* Grounded Flow Intelligence (mock generation, real numbers) */}
            <Card title="🧠 Flow Intelligence">
              <p className="text-sm text-neutral-700">{dailySummary(o)}</p>
              <div className="mt-4 flex gap-2">
                <input value={q} onChange={(e) => setQ(e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && ask()}
                  placeholder="Ask: why is today slower?"
                  className="flex-1 rounded-control border border-neutral-300 px-3 py-2 text-sm" />
                <Button onClick={ask}>Ask</Button>
              </div>
              {a && (
                <div className="mt-3 rounded-control bg-neutral-50 p-3 text-sm">
                  <p className="text-neutral-800">{a.answer}</p>
                  <p className="mt-2 text-xs text-neutral-400">grounded in: {a.citations.join(' · ')}</p>
                </div>
              )}
              <p className="mt-2 text-xs text-neutral-400">Answers use live metrics only (mock generation — Claude swap-in ready).</p>
            </Card>
          </>
        )}
      </main>
    </div>
  );
}

function Metric({ label, value, highlight }: { label: string; value: string; highlight?: boolean }) {
  return (
    <div>
      <p className="text-xs uppercase tracking-wide text-neutral-400">{label}</p>
      <p className={`tnum text-2xl font-semibold ${highlight ? 'text-status-calm' : ''}`}>{value}</p>
    </div>
  );
}
