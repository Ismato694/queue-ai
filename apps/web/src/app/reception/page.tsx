'use client';
import { useCallback, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { getSupabase } from '@/lib/supabase';
import { useSession } from '@/lib/useSession';
import { Button, Card, Field } from '@/lib/ui';
import { cacheGet, cacheSet } from '@/lib/cache';

type Row = Record<string, any>;
const ACUITY_NEXT: Record<string, 'routine' | 'priority' | 'emergency'> = {
  routine: 'priority', priority: 'emergency', emergency: 'routine',
};
const acuityDot = (a: string) => (a === 'emergency' ? '🔴' : a === 'priority' ? '🟠' : '⚪');

export default function Reception() {
  const router = useRouter();
  const { loading, userId, organizationId } = useSession();
  const [branches, setBranches] = useState<Row[]>([]);
  const [departments, setDepartments] = useState<Row[]>([]);
  const [branchId, setBranchId] = useState('');
  const [deptId, setDeptId] = useState('');
  const [queue, setQueue] = useState<Row[]>([]);
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [acuity, setAcuity] = useState<'routine' | 'priority' | 'emergency'>('routine');
  const [now, setNow] = useState(Date.now());
  const [offline, setOffline] = useState(false);

  // config: branches + departments
  useEffect(() => {
    if (!organizationId) return;
    const sb = getSupabase();
    Promise.all([
      sb.from('branches').select('*').order('created_at'),
      sb.from('departments').select('*').order('created_at'),
    ]).then(([b, d]) => {
      setBranches(b.data ?? []); setDepartments(d.data ?? []);
      if (!branchId && b.data?.[0]) setBranchId(b.data[0].id);
      if (!deptId && d.data?.[0]) setDeptId(d.data[0].id);
    });
  }, [organizationId]); // eslint-disable-line react-hooks/exhaustive-deps

  const loadQueue = useCallback(async () => {
    if (!branchId || !deptId) return;
    const cacheKey = `queue:${branchId}:${deptId}`;
    try {
      const { data, error } = await getSupabase()
        .from('reception_queue').select('*')
        .eq('branch_id', branchId).eq('department_id', deptId)
        .order('acuity', { ascending: false })
        .order('position', { ascending: true });
      if (error) throw error;
      setQueue(data ?? []);
      cacheSet(cacheKey, data ?? []);
      setOffline(false);
    } catch {
      // network blip — fall back to last-good cache so the desk keeps working (R5)
      const cached = cacheGet<Row[]>(cacheKey);
      if (cached) setQueue(cached);
      setOffline(true);
    }
  }, [branchId, deptId]);

  // Supabase Realtime (live) + a slow poll fallback + a clock for "waited" times
  useEffect(() => {
    loadQueue();
    const c = setInterval(() => setNow(Date.now()), 1000);
    const poll = setInterval(loadQueue, 8000); // fallback for poor networks
    const sb = getSupabase();
    const ch = sb
      .channel('reception-queue')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'visit_stages' }, () => loadQueue())
      .subscribe();
    return () => { clearInterval(c); clearInterval(poll); sb.removeChannel(ch); };
  }, [loadQueue]);

  if (loading) return <main className="p-10 text-sm text-muted">Loading…</main>;
  if (!userId) { router.push('/login'); return null; }
  if (!organizationId) { router.push('/onboarding'); return null; }

  const sb = getSupabase();
  const rpc = async (fn: string, args: Row) => {
    const { error } = await sb.rpc(fn, args);
    if (error) { alert(`${fn} failed: ${error.message}`); return; }
    await loadQueue();
  };

  const addWalkin = async () => {
    if (!phone) return;
    const { error } = await sb.rpc('create_walkin_visit', {
      p_branch_id: branchId, p_flow_id: null, p_name: name || 'Walk-in', p_phone: phone, p_acuity: acuity,
    });
    if (error) { alert(`Add failed: ${error.message}`); return; }
    setName(''); setPhone(''); setAcuity('routine'); await loadQueue();
  };

  const waited = (iso: string) => {
    const s = Math.max(0, Math.floor((now - new Date(iso).getTime()) / 1000));
    const m = Math.floor(s / 60);
    return m > 0 ? `${m}m` : `${s}s`;
  };

  const next = queue.find((r) => r.state === 'active');

  return (
    <div className="min-h-screen">
      <header className="flex items-center justify-between border-b border-line bg-surface px-6 py-3">
        <span className="text-sm font-semibold text-accent">Queue.ai · Reception</span>
        {offline && (
          <span className="rounded-control bg-status-busy/10 px-2 py-1 text-xs text-status-busy">
            ⚠ Offline — showing last-known queue
          </span>
        )}
        <button className="text-xs text-muted underline"
          onClick={async () => { await sb.auth.signOut(); router.push('/login'); }}>Sign out</button>
      </header>

      <main className="mx-auto max-w-4xl space-y-5 px-6 py-6">
        <div className="flex flex-wrap items-end gap-3">
          <Picker label="Branch" value={branchId} onChange={setBranchId} options={branches} />
          <Picker label="Department" value={deptId} onChange={setDeptId} options={departments} />
          <Button onClick={() => rpc('call_next', { p_branch_id: branchId, p_department_id: deptId })}
            disabled={!next}>▶ Call next</Button>
          {next && (
            <span className="text-sm text-muted">
              Next: <strong>{next.ticket_no}</strong> {acuityDot(next.acuity)} {next.patient_name}
            </span>
          )}
        </div>

        <Card title="Add walk-in (under 15 seconds)">
          <div className="flex flex-wrap items-end gap-2">
            <div className="w-44"><Field label="Name" value={name} onChange={(e) => setName(e.target.value)} /></div>
            <div className="w-40"><Field label="Phone" value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="+234…" /></div>
            <label className="text-sm">
              <span className="mb-1 block text-muted">Acuity</span>
              <select value={acuity} onChange={(e) => setAcuity(e.target.value as any)}
                className="rounded-control border border-line px-2 py-2">
                <option value="routine">Routine</option><option value="priority">Priority</option><option value="emergency">Emergency</option>
              </select>
            </label>
            <Button onClick={addWalkin} disabled={!phone}>Add to queue</Button>
          </div>
        </Card>

        <Card title={`Queue — ${departments.find((d) => d.id === deptId)?.name ?? ''}`}>
          {queue.length === 0 && <p className="text-sm text-faint">No one waiting.</p>}
          <ul className="divide-y divide-line">
            {queue.map((r) => (
              <li key={r.stage_id} className="flex items-center gap-3 py-2 text-sm">
                <span className="tnum w-16 font-medium">{r.ticket_no}</span>
                <span className="w-6">{acuityDot(r.acuity)}</span>
                <span className="flex-1">{r.patient_name ?? '—'}</span>
                <StateBadge state={r.state} />
                <span className="tnum w-12 text-right text-muted">{waited(r.entered_state_at)}</span>
                <div className="flex gap-1">
                  {r.state === 'called' && <Mini onClick={() => rpc('serve_stage', { p_stage_id: r.stage_id })}>Serve</Mini>}
                  {(r.state === 'serving' || r.state === 'called') &&
                    <Mini onClick={() => rpc('complete_stage', { p_stage_id: r.stage_id })}>Done →</Mini>}
                  <Mini onClick={() => rpc('set_stage_priority', { p_stage_id: r.stage_id, p_acuity: ACUITY_NEXT[r.acuity] })}>⇧</Mini>
                  <Mini danger onClick={() => rpc('cancel_visit', { p_visit_id: r.visit_id })}>✕</Mini>
                </div>
              </li>
            ))}
          </ul>
        </Card>
        <p className="text-xs text-faint">Acuity-first ordering · every priority change is audited (R2). Live updates arrive in S3.</p>
      </main>
    </div>
  );
}

function Picker({ label, value, onChange, options }:
  { label: string; value: string; onChange: (v: string) => void; options: Row[] }) {
  return (
    <label className="text-sm">
      <span className="mb-1 block text-muted">{label}</span>
      <select value={value} onChange={(e) => onChange(e.target.value)}
        className="rounded-control border border-line px-2 py-2">
        {options.map((o) => <option key={o.id} value={o.id}>{o.name}</option>)}
      </select>
    </label>
  );
}

function StateBadge({ state }: { state: string }) {
  const map: Record<string, string> = {
    active: 'text-muted', called: 'text-status-info', serving: 'text-status-busy',
  };
  return <span className={`w-16 text-xs ${map[state] ?? ''}`}>{state}</span>;
}

function Mini({ children, onClick, danger }: { children: React.ReactNode; onClick: () => void; danger?: boolean }) {
  return (
    <button onClick={onClick}
      className={`rounded-control border px-2 py-1 text-xs ${danger ? 'border-status-delayed/30 text-status-delayed' : 'border-line text-ink'} hover:bg-surface2`}>
      {children}
    </button>
  );
}
