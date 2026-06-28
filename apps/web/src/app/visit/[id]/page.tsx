'use client';
import { useCallback, useEffect, useState } from 'react';
import { useParams } from 'next/navigation';
import { getSupabase, supabaseConfigured } from '@/lib/supabase';

type Stage = { name: string; state: string; is_current: boolean };
type Status = { branch_name: string; status: string; eta_seconds: number | null; stages: Stage[] };

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
            {s.eta_seconds == null ? 'calculating…' : `~${Math.max(1, Math.round(s.eta_seconds / 60))} min`}
          </p>
          <p className="mt-1 text-xs text-neutral-400">Estimate — confidence &amp; reasons arrive in the next build (Trust Engine).</p>
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
