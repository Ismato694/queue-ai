'use client';
import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { getSupabase, supabaseConfigured } from '@/lib/supabase';
import { Button, Card, Field } from '@/lib/ui';

type Flow = { id: string; name: string };

export default function JoinPage() {
  const router = useRouter();
  const token = String(useParams().token);
  const [branch, setBranch] = useState<{ branch_name: string; flows: Flow[] } | null>(null);
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [flowId, setFlowId] = useState('');
  const [here, setHere] = useState(true);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);

  useEffect(() => {
    if (!supabaseConfigured) return;
    getSupabase().rpc('get_branch_by_token', { p_token: token }).then(({ data }) => {
      if (data) { setBranch(data); if (data.flows?.[0]) setFlowId(data.flows[0].id); }
    });
  }, [token]);

  async function join() {
    if (!phone) return;
    setBusy(true); setMsg(null);
    try {
      const { data, error } = await getSupabase().rpc('join_queue', {
        p_branch_token: token, p_flow_id: flowId || null,
        p_name: name || 'Guest', p_phone: phone,
        p_channel: here ? 'qr' : 'web', p_immediate: here,
      });
      if (error) { setMsg(error.message); return; }
      router.push(`/visit/${data}`);
    } finally { setBusy(false); }
  }

  if (!supabaseConfigured) return <Shell><p className="text-sm text-status-busy">Not configured yet.</p></Shell>;
  if (!branch) return <Shell><p className="text-sm text-muted">Loading…</p></Shell>;

  return (
    <Shell>
      <p className="text-sm font-medium text-accent">{branch.branch_name}</p>
      <h1 className="mt-1 mb-6 text-2xl font-semibold tracking-tight">Get seen faster. Skip the line.</h1>
      <Card>
        <div className="space-y-3">
          {branch.flows.length > 1 && (
            <label className="block text-sm">
              <span className="mb-1 block text-muted">Service</span>
              <select value={flowId} onChange={(e) => setFlowId(e.target.value)}
                className="w-full rounded-control border border-line px-3 py-2">
                {branch.flows.map((f) => <option key={f.id} value={f.id}>{f.name}</option>)}
              </select>
            </label>
          )}
          <Field label="Name" value={name} onChange={(e) => setName(e.target.value)} />
          <Field label="Phone" value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="+234…" />
          <div className="flex gap-2 text-sm">
            <Toggle on={here} onClick={() => setHere(true)}>I'm here now</Toggle>
            <Toggle on={!here} onClick={() => setHere(false)}>I'll arrive later</Toggle>
          </div>
          {msg && <p className="text-sm text-status-delayed">{msg}</p>}
          <Button onClick={join} disabled={busy || !phone}>{busy ? '…' : 'Get my ticket'}</Button>
          <p className="text-xs text-faint">You'll get a live tracker and updates.</p>
        </div>
      </Card>

      {waNumber && (
        <a href={`https://wa.me/${waNumber}?text=${encodeURIComponent(`JOIN ${token}`)}`}
          target="_blank" rel="noreferrer"
          className="mt-3 flex items-center justify-center gap-2 rounded-control border border-line px-4 py-3 text-sm font-medium text-muted">
          💬 Join on WhatsApp instead
        </a>
      )}
      <div className="mt-4 text-center">
        <a href={`/q/${token}`} className="text-xs text-muted underline">See live wait times first</a>
      </div>
    </Shell>
  );
}

const waNumber = process.env.NEXT_PUBLIC_WHATSAPP_NUMBER;

function Shell({ children }: { children: React.ReactNode }) {
  return <main className="mx-auto max-w-md px-6 py-16">{children}</main>;
}
function Toggle({ on, onClick, children }: { on: boolean; onClick: () => void; children: React.ReactNode }) {
  return (
    <button onClick={onClick}
      className={`flex-1 rounded-control border px-3 py-2 ${on ? 'border-accent bg-accent/5 text-accent' : 'border-line text-muted'}`}>
      {children}
    </button>
  );
}
