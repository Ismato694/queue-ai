'use client';
import { useCallback, useEffect, useState } from 'react';
import { useParams } from 'next/navigation';
import { getSupabase, supabaseConfigured } from '@/lib/supabase';

type Disp = {
  branch_name: string;
  now_serving: { ticket: string; dept: string; counter: string | null }[];
  coming_up: { ticket: string; dept: string }[];
};

// Public waiting-room display (R3) — ticket numbers only, never names. Airport-board style.
export default function DisplayPage() {
  const token = String(useParams().token);
  const [d, setD] = useState<Disp | null>(null);

  const load = useCallback(async () => {
    if (!supabaseConfigured) return;
    const { data } = await getSupabase().rpc('get_public_display', { p_branch_token: token });
    if (data) setD(data as Disp);
  }, [token]);
  useEffect(() => { load(); const t = setInterval(load, 4000); return () => clearInterval(t); }, [load]);

  if (!d) return <main className="grid min-h-screen place-items-center bg-neutral-900 text-neutral-300">Loading…</main>;

  return (
    <main className="min-h-screen bg-neutral-900 px-10 py-8 text-white">
      <div className="flex items-baseline justify-between">
        <h1 className="text-2xl font-semibold">{d.branch_name}</h1>
        <span className="tnum text-xl text-neutral-400">{new Date().toLocaleTimeString('en-NG', { hour: '2-digit', minute: '2-digit' })}</span>
      </div>

      <div className="mt-10 grid grid-cols-2 gap-12">
        <section>
          <h2 className="mb-4 text-sm uppercase tracking-widest text-neutral-400">Now serving</h2>
          <ul className="space-y-3">
            {d.now_serving.length === 0 && <li className="text-neutral-500">—</li>}
            {d.now_serving.map((r, i) => (
              <li key={i} className="flex items-center gap-4">
                <span className="tnum text-4xl font-bold text-status-calm">{r.ticket}</span>
                <span className="text-xl text-neutral-300">→ {r.counter ?? r.dept}</span>
              </li>
            ))}
          </ul>
        </section>
        <section>
          <h2 className="mb-4 text-sm uppercase tracking-widest text-neutral-400">Coming up</h2>
          <ul className="space-y-2">
            {d.coming_up.length === 0 && <li className="text-neutral-500">—</li>}
            {d.coming_up.map((r, i) => (
              <li key={i} className="tnum text-2xl text-neutral-200">{r.ticket} <span className="text-base text-neutral-500">· {r.dept}</span></li>
            ))}
          </ul>
        </section>
      </div>
    </main>
  );
}
