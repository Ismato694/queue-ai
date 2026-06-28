'use client';
import { useCallback, useEffect, useState } from 'react';
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

  const load = useCallback(async () => {
    const sb = getSupabase();
    const [b, d, s, st] = await Promise.all([
      sb.from('branches').select('*').order('created_at'),
      sb.from('departments').select('*').order('created_at'),
      sb.from('services').select('*').order('created_at'),
      sb.from('staff').select('*').order('created_at'),
    ]);
    setBranches(b.data ?? []); setDepartments(d.data ?? []);
    setServices(s.data ?? []); setStaff(st.data ?? []);
  }, []);
  useEffect(() => { load(); }, [load]);

  const insert = async (table: string, values: Row) => {
    await getSupabase().from(table).insert({ organization_id: organizationId, ...values });
    await load();
  };

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-semibold">Structure</h1>

      <Card title="Branches">
        <List rows={branches} render={(r) => r.name} />
        <AddOne placeholder="Branch name" onAdd={(name) => insert('branches', { name })} />
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

const branchName = (bs: Row[], id: string) => bs.find((b) => b.id === id)?.name ?? '—';
const deptName = (ds: Row[], id: string) => ds.find((d) => d.id === id)?.name ?? '—';

function List({ rows, render }: { rows: Row[]; render: (r: Row) => string }) {
  if (!rows.length) return <p className="text-sm text-neutral-400">None yet.</p>;
  return <ul className="mb-3 space-y-1 text-sm">{rows.map((r) => <li key={r.id} className="text-neutral-700">• {render(r)}</li>)}</ul>;
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
      className="rounded-control border border-neutral-300 px-2 py-2 text-sm">
      <option value="">{placeholder}</option>
      {options.map((o) => <option key={o.v} value={o.v}>{o.l}</option>)}
    </select>
  );
}
