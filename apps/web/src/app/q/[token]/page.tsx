'use client';
import { useCallback, useEffect, useState } from 'react';
import { useParams } from 'next/navigation';
import Link from 'next/link';
import { getSupabase, supabaseConfigured } from '@/lib/supabase';

type Dept = { department_name: string; waiting: number; now_serving: string | null; est_wait_min: number };
type Board = { available: boolean; branch_name: string; departments?: Dept[] };

// Anonymous Public Queue (F10) — a PII-free, opt-in wait board people check before
// coming in. No login, no names. Decide-before-you-leave.
export default function PublicQueuePage() {
  const token = String(useParams().token);
  const [b, setB] = useState<Board | null>(null);

  const load = useCallback(async () => {
    if (!supabaseConfigured) return;
    const { data } = await getSupabase().rpc('get_public_wait', { p_branch_token: token });
    if (data) setB(data as Board);
  }, [token]);

  useEffect(() => { load(); const t = setInterval(load, 10000); return () => clearInterval(t); }, [load]);

  if (!b) return <Shell><p className="text-sm text-muted">Loading live wait times…</p></Shell>;

  if (!b.available) {
    return (
      <Shell>
        <p className="text-sm font-medium text-accent">{b.branch_name}</p>
        <h1 className="mt-1 text-2xl font-semibold">Live wait times aren't public here</h1>
        <p className="mt-2 text-sm text-muted">This location hasn't turned on the public wait board yet.</p>
        <Link href={`/join/${token}`} className="mt-6 inline-block rounded-control bg-accent px-4 py-3 font-medium text-white">
          Join the queue
        </Link>
      </Shell>
    );
  }

  const depts = b.departments ?? [];
  const busiest = depts.reduce((m, d) => Math.max(m, d.est_wait_min), 0);

  return (
    <Shell>
      <p className="text-sm font-medium text-accent">{b.branch_name}</p>
      <h1 className="mt-1 text-2xl font-semibold tracking-tight">Live wait times</h1>
      <p className="mt-1 text-sm text-muted">Updated live · no sign-in needed</p>

      <div className="mt-6 space-y-3">
        {depts.length === 0 && <p className="text-sm text-muted">No active services right now.</p>}
        {depts.map((d) => (
          <div key={d.department_name} className="flex items-center justify-between rounded-card border border-line bg-surface p-4">
            <div>
              <p className="font-medium">{d.department_name}</p>
              <p className="text-xs text-muted">
                {d.waiting} waiting{d.now_serving ? ` · now serving ${d.now_serving}` : ''}
              </p>
            </div>
            <div className="text-right">
              <p className={`tnum text-2xl font-semibold ${d.est_wait_min >= 30 ? 'text-status-busy' : d.est_wait_min >= 15 ? 'text-status-delayed' : 'text-status-calm'}`}>
                ~{d.est_wait_min}<span className="text-sm text-faint"> min</span>
              </p>
            </div>
          </div>
        ))}
      </div>

      <Link href={`/join/${token}`} className="mt-6 block rounded-control bg-accent px-4 py-3 text-center font-medium text-white">
        {busiest >= 20 ? 'Skip the line — join now' : 'Join the queue'}
      </Link>
      <p className="mt-3 text-center text-xs text-faint">Estimates only · we never show patient names.</p>
    </Shell>
  );
}

function Shell({ children }: { children: React.ReactNode }) {
  return <main className="mx-auto max-w-md px-6 py-16">{children}</main>;
}
