'use client';
import { useCallback, useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { getSupabase } from '@/lib/supabase';
import { Button, Card, Field } from '@/lib/ui';

type Row = Record<string, any>;
interface Stage {
  name: string;
  department_id: string;
  service_id: string;
  est_duration_seconds: number;
  requires_triage: boolean;
  is_optional: boolean;
}

const blank = (): Stage => ({ name: '', department_id: '', service_id: '', est_duration_seconds: 600, requires_triage: false, is_optional: false });

export default function FlowBuilder() {
  const router = useRouter();
  const id = String(useParams().id);
  const [flow, setFlow] = useState<Row | null>(null);
  const [departments, setDepartments] = useState<Row[]>([]);
  const [services, setServices] = useState<Row[]>([]);
  const [stages, setStages] = useState<Stage[]>([]);
  const [msg, setMsg] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    const sb = getSupabase();
    const { data: f } = await sb.from('flows').select('*').eq('id', id).maybeSingle();
    setFlow(f ?? null);
    const [d, s] = await Promise.all([
      sb.from('departments').select('*').order('created_at'),
      sb.from('services').select('*').order('created_at'),
    ]);
    setDepartments(d.data ?? []); setServices(s.data ?? []);

    if (f?.current_version_id) {
      const { data: st } = await sb.from('flow_stages').select('*')
        .eq('flow_version_id', f.current_version_id).order('position');
      if (st?.length) {
        setStages(st.map((r) => ({
          name: r.name, department_id: r.department_id ?? '', service_id: r.service_id ?? '',
          est_duration_seconds: r.est_duration_seconds ?? 600,
          requires_triage: r.requires_triage, is_optional: r.is_optional,
        })));
      }
    }
  }, [id]);
  useEffect(() => { load(); }, [load]);

  const update = (i: number, patch: Partial<Stage>) =>
    setStages((s) => s.map((st, idx) => (idx === i ? { ...st, ...patch } : st)));
  const remove = (i: number) => setStages((s) => s.filter((_, idx) => idx !== i));
  const move = (i: number, dir: -1 | 1) => setStages((s) => {
    const j = i + dir; if (j < 0 || j >= s.length) return s;
    const c = [...s]; [c[i], c[j]] = [c[j], c[i]]; return c;
  });

  async function publish() {
    setBusy(true); setMsg(null);
    try {
      const clean = stages.filter((s) => s.name && s.department_id);
      const { error } = await getSupabase().rpc('publish_flow', { p_flow_id: id, p_stages: clean });
      if (error) { setMsg(error.message); return; }
      setMsg('Published ✓'); await load();
    } finally { setBusy(false); }
  }

  if (!flow) return <p className="text-sm text-neutral-500">Loading…</p>;

  return (
    <div className="space-y-6">
      <button className="text-xs text-neutral-500 underline" onClick={() => router.push('/admin/flows')}>← Flows</button>
      <h1 className="text-2xl font-semibold">{flow.name}</h1>

      <Card title="Stages (the patient journey)">
        {stages.length === 0 && <p className="mb-3 text-sm text-neutral-400">No stages yet. Add the first.</p>}
        <ol className="space-y-3">
          {stages.map((s, i) => (
            <li key={i} className="rounded-control border border-neutral-200 p-3">
              <div className="mb-2 flex items-center gap-2">
                <span className="text-xs text-neutral-400">#{i + 1}</span>
                <input className="flex-1 rounded-control border border-neutral-300 px-2 py-1 text-sm"
                  placeholder="Stage name (e.g. Consultation)" value={s.name}
                  onChange={(e) => update(i, { name: e.target.value })} />
                <button className="text-xs text-neutral-400" onClick={() => move(i, -1)}>↑</button>
                <button className="text-xs text-neutral-400" onClick={() => move(i, 1)}>↓</button>
                <button className="text-xs text-status-delayed" onClick={() => remove(i)}>✕</button>
              </div>
              <div className="flex flex-wrap items-center gap-2 text-sm">
                <Pick value={s.department_id} onChange={(v) => update(i, { department_id: v })}
                  options={departments} placeholder="Department" />
                <Pick value={s.service_id} onChange={(v) => update(i, { service_id: v })}
                  options={services} placeholder="Service (optional)" />
                <label className="flex items-center gap-1">
                  <span className="text-neutral-500">min</span>
                  <input type="number" className="w-16 rounded-control border border-neutral-300 px-2 py-1"
                    value={Math.round(s.est_duration_seconds / 60)}
                    onChange={(e) => update(i, { est_duration_seconds: (Number(e.target.value) || 1) * 60 })} />
                </label>
                <label className="flex items-center gap-1"><input type="checkbox" checked={s.requires_triage}
                  onChange={(e) => update(i, { requires_triage: e.target.checked })} /> triage</label>
                <label className="flex items-center gap-1"><input type="checkbox" checked={s.is_optional}
                  onChange={(e) => update(i, { is_optional: e.target.checked })} /> optional</label>
              </div>
            </li>
          ))}
        </ol>
        <div className="mt-3 flex items-center gap-2">
          <Button variant="ghost" onClick={() => setStages((s) => [...s, blank()])}>+ Add stage</Button>
          <Button onClick={publish} disabled={busy || stages.length === 0}>{busy ? '…' : 'Save & publish'}</Button>
          {msg && <span className="text-sm text-status-calm">{msg}</span>}
        </div>
      </Card>

      <Card title="Preview">
        <p className="text-sm text-neutral-600">
          {stages.filter((s) => s.name).map((s) => s.name).join('  →  ') || '—'}
        </p>
      </Card>
    </div>
  );
}

function Pick({ value, onChange, options, placeholder }:
  { value: string; onChange: (v: string) => void; options: Row[]; placeholder: string }) {
  return (
    <select value={value} onChange={(e) => onChange(e.target.value)}
      className="rounded-control border border-neutral-300 px-2 py-1">
      <option value="">{placeholder}</option>
      {options.map((o) => <option key={o.id} value={o.id}>{o.name}</option>)}
    </select>
  );
}
