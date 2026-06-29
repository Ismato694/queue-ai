'use client';
import { useCallback, useEffect, useState } from 'react';
import { QRCodeSVG } from 'qrcode.react';
import { getSupabase } from '@/lib/supabase';
import { useSession } from '@/lib/useSession';
import { Button, Card, Field } from '@/lib/ui';

type Row = Record<string, any>;

export default function StructurePage() {
  const { organizationId } = useSession();
  const [branches, setBranches] = useState<Row[]>([]);
  const [departments, setDepartments] = useState<Row[]>([]);
  const [services, setServices] = useState<Row[]>([]);
  const [staff, setStaff] = useState<Row[]>([]);
  const [origin, setOrigin] = useState('');
  useEffect(() => { setOrigin(window.location.origin); }, []);

  const load = useCallback(async () => {
    const sb = getSupabase();
    const [b, d, s, st] = await Promise.all([
      sb.from('branches').select('*').order('created_at').limit(500),
      sb.from('departments').select('*').order('created_at').limit(500),
      sb.from('services').select('*').order('created_at').limit(500),
      sb.from('staff').select('*').order('created_at').limit(500),
    ]);
    setBranches(b.data ?? []); setDepartments(d.data ?? []);
    setServices(s.data ?? []); setStaff(st.data ?? []);
  }, []);
  useEffect(() => { load(); }, [load]);

  const insert = async (table: string, values: Row) => {
    await getSupabase().from(table).insert({ organization_id: organizationId, ...values });
    await load();
  };

  const updateBranch = async (id: string, patch: Row) => {
    await getSupabase().from('branches').update(patch).eq('id', id);
    await load();
  };

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-semibold">Structure</h1>

      <Card title="Branches">
        {!branches.length ? <p className="text-sm text-faint">None yet.</p> : (
          <ul className="mb-3 space-y-2 text-sm">
            {branches.map((r) => (
              <li key={r.id} className="flex flex-wrap items-center gap-x-3 gap-y-1">
                <span className="text-ink">• {r.name}</span>
                <label className="flex items-center gap-1 text-xs text-muted">
                  <input type="checkbox" checked={!!r.publish_public_wait}
                    onChange={(e) => updateBranch(r.id, { publish_public_wait: e.target.checked })} />
                  Public wait board
                </label>
                {r.publish_public_wait && r.qr_token && (
                  <a href={`/q/${r.qr_token}`} target="_blank" rel="noreferrer" className="text-xs text-accent underline">
                    /q/{String(r.qr_token).slice(0, 6)}…
                  </a>
                )}
              </li>
            ))}
          </ul>
        )}
        <AddOne placeholder="Branch name" onAdd={(name) => insert('branches', { name })} />
      </Card>

      <Card title="Branch access — QR & links">
        {!branches.length ? <p className="text-sm text-faint">Add a branch first.</p> : (
          <div className="space-y-6">
            {branches.filter((b) => b.qr_token).map((b) => (
              <BranchAccess key={b.id} branch={b} origin={origin} />
            ))}
          </div>
        )}
      </Card>

      <Card title="Departments">
        <List rows={departments} render={(r) => `${r.name} · ${branchName(branches, r.branch_id)}`} />
        <AddDept branches={branches} onAdd={(name, branch_id) => insert('departments', { name, branch_id })} />
      </Card>

      <Card title="Services">
        <List rows={services} render={(r) => `${r.name} · ${Math.round((r.avg_duration_seconds ?? 0) / 60)}m · ${deptName(departments, r.department_id)}`} />
        <AddService departments={departments} onAdd={(name, department_id, mins) =>
          insert('services', { name, department_id, avg_duration_seconds: mins * 60 })} />
      </Card>

      <Card title="Staff">
        <List rows={staff} render={(r) => `${r.display_name} · ${r.role} · ${deptName(departments, r.department_id)}`} />
        <AddStaff departments={departments} onAdd={(display_name, role, department_id) =>
          insert('staff', { display_name, role, department_id })} />
      </Card>
    </div>
  );
}

// Per-branch access: the customer join QR + the three shareable links.
function BranchAccess({ branch, origin }: { branch: Row; origin: string }) {
  const joinUrl = `${origin}/join/${branch.qr_token}`;
  const displayUrl = `${origin}/display/${branch.qr_token}`;
  const publicUrl = `${origin}/q/${branch.qr_token}`;
  return (
    <div className="flex flex-col gap-4 sm:flex-row sm:items-start">
      <div className="shrink-0 rounded-card border border-line bg-white p-3">
        {origin && <QRCodeSVG value={joinUrl} size={128} />}
      </div>
      <div className="min-w-0 flex-1">
        <p className="font-medium">{branch.name}</p>
        <p className="text-xs text-muted">Patients scan this QR to join the queue. Print it for the entrance/reception.</p>
        <div className="mt-3 space-y-2">
          <LinkRow label="Customer join" url={joinUrl} />
          <LinkRow label="Waiting-room display" url={displayUrl} />
          <LinkRow label={`Public wait board${branch.publish_public_wait ? '' : ' (off)'}`} url={publicUrl} />
        </div>
      </div>
    </div>
  );
}

function LinkRow({ label, url }: { label: string; url: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <div className="flex items-center gap-2 text-xs">
      <span className="w-40 shrink-0 text-muted">{label}</span>
      <a href={url} target="_blank" rel="noreferrer" className="truncate text-accent underline">{url}</a>
      <button
        onClick={() => { navigator.clipboard?.writeText(url); setCopied(true); setTimeout(() => setCopied(false), 1200); }}
        className="shrink-0 rounded border border-line px-2 py-0.5 text-muted">
        {copied ? 'Copied' : 'Copy'}
      </button>
    </div>
  );
}

const branchName = (bs: Row[], id: string) => bs.find((b) => b.id === id)?.name ?? '—';
const deptName = (ds: Row[], id: string) => ds.find((d) => d.id === id)?.name ?? '—';

function List({ rows, render }: { rows: Row[]; render: (r: Row) => string }) {
  if (!rows.length) return <p className="text-sm text-faint">None yet.</p>;
  return <ul className="mb-3 space-y-1 text-sm">{rows.map((r) => <li key={r.id} className="text-ink">• {render(r)}</li>)}</ul>;
}

function AddOne({ placeholder, onAdd }: { placeholder: string; onAdd: (name: string) => void }) {
  const [v, setV] = useState('');
  return (
    <div className="flex items-end gap-2">
      <div className="flex-1"><Field label="" placeholder={placeholder} value={v} onChange={(e) => setV(e.target.value)} /></div>
      <Button variant="ghost" onClick={() => { if (v) { onAdd(v); setV(''); } }}>Add</Button>
    </div>
  );
}

function AddDept({ branches, onAdd }: { branches: Row[]; onAdd: (name: string, branchId: string) => void }) {
  const [name, setName] = useState(''); const [branchId, setBranchId] = useState('');
  return (
    <div className="flex items-end gap-2">
      <div className="flex-1"><Field label="" placeholder="Department name" value={name} onChange={(e) => setName(e.target.value)} /></div>
      <Select value={branchId} onChange={setBranchId} options={branches.map((b) => ({ v: b.id, l: b.name }))} placeholder="Branch" />
      <Button variant="ghost" onClick={() => { if (name && branchId) { onAdd(name, branchId); setName(''); } }}>Add</Button>
    </div>
  );
}

function AddService({ departments, onAdd }: { departments: Row[]; onAdd: (name: string, deptId: string, mins: number) => void }) {
  const [name, setName] = useState(''); const [deptId, setDeptId] = useState(''); const [mins, setMins] = useState('10');
  return (
    <div className="flex items-end gap-2">
      <div className="flex-1"><Field label="" placeholder="Service name" value={name} onChange={(e) => setName(e.target.value)} /></div>
      <div className="w-20"><Field label="" type="number" value={mins} onChange={(e) => setMins(e.target.value)} /></div>
      <Select value={deptId} onChange={setDeptId} options={departments.map((d) => ({ v: d.id, l: d.name }))} placeholder="Dept" />
      <Button variant="ghost" onClick={() => { if (name && deptId) { onAdd(name, deptId, Number(mins) || 10); setName(''); } }}>Add</Button>
    </div>
  );
}

function AddStaff({ departments, onAdd }: { departments: Row[]; onAdd: (name: string, role: string, deptId: string | null) => void }) {
  const [name, setName] = useState(''); const [role, setRole] = useState('staff'); const [deptId, setDeptId] = useState('');
  return (
    <div className="flex items-end gap-2">
      <div className="flex-1"><Field label="" placeholder="Staff name" value={name} onChange={(e) => setName(e.target.value)} /></div>
      <Select value={role} onChange={setRole} options={['receptionist', 'staff', 'manager', 'org_admin'].map((r) => ({ v: r, l: r }))} placeholder="Role" />
      <Select value={deptId} onChange={setDeptId} options={departments.map((d) => ({ v: d.id, l: d.name }))} placeholder="Dept" />
      <Button variant="ghost" onClick={() => { if (name) { onAdd(name, role, deptId || null); setName(''); } }}>Add</Button>
    </div>
  );
}

function Select({ value, onChange, options, placeholder }:
  { value: string; onChange: (v: string) => void; options: { v: string; l: string }[]; placeholder: string }) {
  return (
    <select value={value} onChange={(e) => onChange(e.target.value)}
      className="rounded-control border border-line px-2 py-2 text-sm">
      <option value="">{placeholder}</option>
      {options.map((o) => <option key={o.v} value={o.v}>{o.l}</option>)}
    </select>
  );
}
