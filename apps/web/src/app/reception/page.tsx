'use client';
import { useCallback, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { getSupabase } from '@/lib/supabase';
import { useSession } from '@/lib/useSession';
import { Button, Card, Field } from '@/lib/ui';

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
    const { data } = await getSupabase()
      .from('reception_queue').select('*')
      .eq('branch_id', branchId).eq('department_id', deptId)
      .order('acuity', { ascending: false })
      .order('position', { ascending: true });
    setQueue(data ?? []);
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

  if (loading) return <main className="p-10 text-sm text-neutral-500">Loading…</main>;
  if (!userId) { router.push('/login'); return null; }
  if (!organizationId) { router.push('/onboarding'); return null; }

  const sb = getSupabase();
  const rpc = async (fn: string, args: Row) => { await sb.rpc(fn, args); await loadQueue(); };

  const addWalkin = async () => {
    if (!phone) return;
    await sb.rpc('create_walkin_visit', {
      p_branch_id: branchId, p_flow_id: null, p_name: name || 'Walk-in', p_phone: phone, p_acuity: acuity,
    });
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
      <header className="flex items-center justify-between border-b border-neutral-200 bg-white px-6 py-3">
        <span className="text-sm font-semibold text-accent">Queue.ai · Reception</span>
        <button className="text-xs text-neutral-500 underline"
          onClick={async () => { await sb.auth.signOut(); router.push('/login'); }}>Sign out</button>
      </header>

      <main className="mx-auto max-w-4xl space-y-5 px-6 py-6">
        <div className="flex flex-wrap items-end gap-3">
          <Picker label="Branch" value={branchId} onChange={setBranchId} options={branches} />
          <Picker label="Department" value={deptId} onChange={setDeptId} options={departments} />
          <Button onClick={() => rpc('call_next', { p_branch_id: branchId, p_department_id: deptId })}
            disabled={!next}>▶ Call next</Button>
          {next && (
            <span className="text-sm text-neutral-600">
              Next: <strong>{next.ticket_no}</strong> {acuityDot(next.acuity)} {next.patient_name}
            </span>
          )}
        </div>

        <Card title="Add walk-in (under 15 seconds)">
          <div className="flex flex-wrap items-end gap-2">
            <div className="w-44"><Field label="Name" value={name} onChange={(e) => setName(e.target.value)} /></div>
            <div className="w-40"><Field label="Phone" value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="+234…" /></div>
            <label className="text-sm">
              <span className="mb-1 block text-neutral-600">Acuity</span>
              <select value={acuity} onChange={(e) => setAcuity(e.target.value as any)}
                className="rounded-control border border-neutral-300 px-2 py-2">
                <option value="routine">Routine</option><option value="priority">Priority</option><option value="emergency">Emergency</option>
              </select>
            </label>
            <Button onClick={addWalkin} disabled={!phone}>Add to queue</Button>
          </div>
        </Card>

        <Card title={`Queue — ${departments.find((d) => d.id === deptId)?.name ?? ''}`}>
          {queue.length === 0 && <p className="text-sm text-neutral-400">No one waiting.</p>}
          <ul className="divide-y divide-neutral-100">
            {queue.map((r) => (
              <li key={r.stage_id} className="flex items-center gap-3 py-2 text-sm">
                <span className="tnum w-16 font-medium">{r.ticket_no}</span>
                <span className="w-6">{acuityDot(r.acuity)}</span>
                <span className="flex-1">{r.patient_name ?? '—'}</span>
                <StateBadge state={r.state} />
                <span className="tnum w-12 text-right text-neutral-500">{waited(r.entered_state_at)}</span>
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
        <p className="text-xs text-neutral-400">Acuity-first ordering · every priority change is audited (R2). Live updates arrive in S3.</p>
      </main>
    </div>
  );
}

function Picker({ label, value, onChange, options }:
  { label: string; value: string; onChange: (v: string) => void; options: Row[] }) {
  return (
    <label className="text-sm">
      <span className="mb-1 block text-neutral-600">{label}</span>
      <select value={value} onChange={(e) => onChange(e.target.value)}
        className="rounded-control border border-neutral-300 px-2 py-2">
        {options.map((o) => <option key={o.id} value={o.id}>{o.name}</option>)}
      </select>
    </label>
  );
}

function StateBadge({ state }: { state: string }) {
  const map: Record<string, string> = {
    active: 'text-neutral-500', called: 'text-status-info', serving: 'text-status-busy',
  };
  return <span className={`w-16 text-xs ${map[state] ?? ''}`}>{state}</span>;
}

function Mini({ children, onClick, danger }: { children: React.ReactNode; onClick: () => void; danger?: boolean }) {
  return (
    <button onClick={onClick}
      className={`rounded-control border px-2 py-1 text-xs ${danger ? 'border-red-200 text-status-delayed' : 'border-neutral-300 text-neutral-700'} hover:bg-neutral-100`}>
      {children}
    </button>
  );
}
