'use client';
import { useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import { getSupabase } from '@/lib/supabase';
import { useSession } from '@/lib/useSession';
import { Button, Card, Field } from '@/lib/ui';

type Row = Record<string, any>;

export default function FlowsPage() {
  const { organizationId } = useSession();
  const [flows, setFlows] = useState<Row[]>([]);
  const [name, setName] = useState('');

  const load = useCallback(async () => {
    const { data } = await getSupabase().from('flows').select('*').order('created_at');
    setFlows(data ?? []);
  }, []);
  useEffect(() => { load(); }, [load]);

  async function create() {
    if (!name) return;
    await getSupabase().from('flows').insert({ organization_id: organizationId, name, industry_template: 'hospital' });
    setName(''); await load();
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Flow Builder</h1>
        <p className="text-sm text-muted">Define the patient journey — the same engine works for any industry (F1).</p>
      </div>

      <Card title="Your flows">
        {flows.length === 0 && <p className="mb-3 text-sm text-faint">No flows yet. Create one below.</p>}
        <ul className="mb-3 space-y-2">
          {flows.map((f) => (
            <li key={f.id} className="flex items-center justify-between text-sm">
              <span>{f.name} {f.is_published ? <span className="text-status-calm">· published</span> : <span className="text-faint">· draft</span>}</span>
              <Link className="text-accent underline" href={`/admin/flows/${f.id}`}>Edit →</Link>
            </li>
          ))}
        </ul>
        <div className="flex items-end gap-2">
          <div className="flex-1"><Field label="" placeholder="e.g. Outpatient Visit" value={name} onChange={(e) => setName(e.target.value)} /></div>
          <Button variant="ghost" onClick={create}>Create flow</Button>
        </div>
      </Card>
    </div>
  );
}
