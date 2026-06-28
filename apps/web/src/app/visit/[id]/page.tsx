'use client';
import { useCallback, useEffect, useState } from 'react';
import { useParams } from 'next/navigation';
import { getSupabase, supabaseConfigured } from '@/lib/supabase';

type Stage = { name: string; state: string; is_current: boolean };
type Status = {
  branch_name: string; status: string;
  eta_low_s: number | null; eta_high_s: number | null;
  confidence: number | null; reasons: string[]; stages: Stage[];
};
const mins = (s: number) => Math.max(1, Math.round(s / 60));

export default function VisitPage() {
  const id = String(useParams().id);
  const [s, setS] = useState<Status | null>(null);
  const [acting, setActing] = useState(false);

  const load = useCallback(async () => {
    if (!supabaseConfigured) return;
    const { data } = await getSupabase().rpc('get_visit_status', { p_visit_id: id });
    if (data) setS(data as Status);
  }, [id]);

  useEffect(() => { load(); const t = setInterval(load, 4000); return () => clearInterval(t); }, [load]);

  if (!s) return <main className="mx-auto max-w-md px-6 py-16 text-sm text-neutral-500">Loading your visit…</main>;

  const current = s.stages.find((x) => x.is_current);
  const isPreQueue = current?.state === 'pre_queue';
  const isCalled = current?.state === 'called';
  const done = s.status === 'completed';

  async function activate() {
    setActing(true);
    try { await getSupabase().rpc('activate_visit', { p_visit_id: id, p_trigger: 'on_my_way' }); await load(); }
    finally { setActing(false); }
  }

  return (
    <main className="mx-auto max-w-md px-6 py-10">
      <p className="text-sm font-medium text-accent">{s.branch_name}</p>

      {done ? (
        <h1 className="mt-2 text-2xl font-semibold">✔ Visit complete</h1>
      ) : isCalled ? (
        <div className="mt-4 rounded-card border border-status-info/30 bg-status-info/5 p-5">
          <p className="text-sm text-status-info">● It's your turn</p>
          <p className="mt-1 text-2xl font-semibold">Please proceed to {current?.name}</p>
        </div>
      ) : (
        <div className="mt-4">
          <p className="text-sm text-neutral-500">You'll be seen in</p>
          <p className="tnum text-4xl font-semibold">
            {s.eta_low_s == null || s.eta_high_s == null
              ? 'calculating…'
              : mins(s.eta_low_s) === mins(s.eta_high_s)
                ? `~${mins(s.eta_high_s)} min`
                : `${mins(s.eta_low_s)}–${mins(s.eta_high_s)} min`}
          </p>
          {s.confidence != null && (
            <div className="mt-2">
              <p className="text-sm text-neutral-600">{Math.round(s.confidence * 100)}% confidence</p>
              <div className="mt-1 h-1.5 w-40 overflow-hidden rounded-full bg-neutral-200">
                <div className="h-full bg-status-calm" style={{ width: `${Math.round(s.confidence * 100)}%` }} />
              </div>
              {s.reasons?.length > 0 && (
                <ul className="mt-2 text-xs text-neutral-500">
                  {s.reasons.map((r, i) => <li key={i}>• {r}</li>)}
                </ul>
              )}
            </div>
          )}
        </div>
      )}

      {isPreQueue && !done && (
        <button onClick={activate} disabled={acting}
          className="mt-5 w-full rounded-control bg-accent px-4 py-3 font-medium text-white">
          {acting ? '…' : "I'm on my way"}
        </button>
      )}

      <div className="mt-8">
        <h2 className="mb-3 text-sm font-semibold text-neutral-500">Your journey</h2>
        <ol className="space-y-2">
          {s.stages.map((st, i) => (
            <li key={i} className="flex items-center gap-3 text-sm">
              <span className="w-5">{icon(st)}</span>
              <span className={st.is_current ? 'font-medium text-neutral-900' : 'text-neutral-500'}>
                {st.name}{st.is_current ? '  ← you are here' : ''}
              </span>
            </li>
          ))}
        </ol>
      </div>

      <p className="mt-10 text-xs text-neutral-400">Law #0 — we're saving you time. Keep this page; it updates live.</p>
    </main>
  );
}

function icon(st: Stage) {
  if (['completed', 'transferred'].includes(st.state)) return '✔';
  if (st.is_current) return st.state === 'called' ? '●' : '⏳';
  if (st.state === 'cancelled' || st.state === 'no_show') return '✕';
  return '○';
}
