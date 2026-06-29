'use client';
import { useCallback, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { getSupabase } from '@/lib/supabase';
import { useSession } from '@/lib/useSession';
import { Button } from '@/lib/ui';

type Row = Record<string, any>;

// Staff "what's next" — minimal chrome, one tap (docs/03-WIREFRAMES.md S1).
export default function StaffPage() {
  const router = useRouter();
  const { loading, userId, organizationId } = useSession();
  const [me, setMe] = useState<Row | null>(null);
  const [branchId, setBranchId] = useState<string | null>(null);
  const [queue, setQueue] = useState<Row[]>([]);

  useEffect(() => {
    if (!userId) return;
    const sb = getSupabase();
    sb.from('staff').select('*').eq('user_id', userId).maybeSingle().then(({ data }) => setMe(data));
    sb.from('branches').select('id').order('created_at').limit(1).maybeSingle().then(({ data }) => setBranchId(data?.id ?? null));
  }, [userId]);

  const loadQueue = useCallback(async () => {
    if (!me?.department_id) return;
    const { data } = await getSupabase().from('reception_queue').select('*')
      .eq('department_id', me.department_id)
      .order('acuity', { ascending: false }).order('position', { ascending: true });
    setQueue(data ?? []);
  }, [me?.department_id]);

  useEffect(() => {
    loadQueue();
    const sb = getSupabase();
    const ch = sb.channel('staff-queue')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'visit_stages' }, () => loadQueue())
      .subscribe();
    const poll = setInterval(loadQueue, 8000);
    return () => { clearInterval(poll); sb.removeChannel(ch); };
  }, [loadQueue]);

  if (loading) return <main className="p-10 text-sm text-muted">Loading…</main>;
  if (!userId) { router.push('/login'); return null; }
  if (!organizationId) { router.push('/onboarding'); return null; }

  const sb = getSupabase();
  const rpc = async (fn: string, args: Row) => { await sb.rpc(fn, args); await loadQueue(); };
  const setStatus = async (status: string) => {
    if (me) { await sb.from('staff').update({ status }).eq('id', me.id); setMe({ ...me, status }); }
  };

  const serving = queue.find((r) => r.state === 'serving');
  const called = queue.find((r) => r.state === 'called');
  const current = serving ?? called;
  const waitingCount = queue.filter((r) => r.state === 'active').length;

  return (
    <div className="min-h-screen">
      <header className="flex items-center justify-between border-b border-line bg-surface px-6 py-3">
        <span className="text-sm font-semibold text-accent">Queue.ai · {me?.display_name ?? 'Staff'}</span>
        <div className="flex items-center gap-2">
          <span className={`text-xs ${me?.status === 'online' ? 'text-status-calm' : 'text-faint'}`}>● {me?.status ?? '—'}</span>
          <button className="text-xs text-muted underline" onClick={async () => { await sb.auth.signOut(); router.push('/login'); }}>Sign out</button>
        </div>
      </header>

      <main className="mx-auto max-w-md px-6 py-8">
        {!me?.department_id ? (
          <p className="text-sm text-muted">Your account isn't linked to a department yet. Ask an admin to assign you in Structure.</p>
        ) : (
          <>
            <div className="rounded-card border border-line bg-surface p-6">
              <p className="text-xs font-semibold uppercase tracking-wide text-faint">Now</p>
              {current ? (
                <>
                  <p className="tnum mt-1 text-3xl font-semibold">{current.ticket_no}</p>
                  <p className="text-muted">{current.patient_name ?? '—'} · {current.state}</p>
                  <div className="mt-4 flex gap-2">
                    {current.state === 'called' && <Button onClick={() => rpc('serve_stage', { p_stage_id: current.stage_id })}>Start</Button>}
                    <Button onClick={() => rpc('complete_stage', { p_stage_id: current.stage_id })}>✔ Complete → next</Button>
                  </div>
                </>
              ) : (
                <>
                  <p className="mt-1 text-muted">No one in service.</p>
                  <div className="mt-4">
                    <Button onClick={() => branchId && rpc('call_next', { p_branch_id: branchId, p_department_id: me.department_id })}
                      disabled={waitingCount === 0}>▶ Call next</Button>
                  </div>
                </>
              )}
            </div>

            <p className="mt-4 text-sm text-muted">Up next: {waitingCount} waiting</p>

            <div className="mt-6 flex gap-2">
              {me?.status === 'online'
                ? <button className="text-sm text-muted underline" onClick={() => setStatus('break')}>Take a break</button>
                : <button className="text-sm text-status-calm underline" onClick={() => setStatus('online')}>Return online</button>}
            </div>
          </>
        )}
      </main>
    </div>
  );
}
