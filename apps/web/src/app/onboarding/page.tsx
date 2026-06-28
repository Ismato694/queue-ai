'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { getSupabase } from '@/lib/supabase';
import { useSession } from '@/lib/useSession';
import { Button, Card, Field } from '@/lib/ui';

// The S0/S1 demo: a signed-in user with no org creates org + first branch (1 RPC).
export default function OnboardingPage() {
  const router = useRouter();
  const { loading, userId, organizationId } = useSession();
  const [org, setOrg] = useState('');
  const [branch, setBranch] = useState('');
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);

  if (!loading && !userId) { router.push('/login'); return null; }
  if (!loading && organizationId) { router.push('/admin'); return null; }

  async function create() {
    setBusy(true); setMsg(null);
    try {
      const sb = getSupabase();
      const { error } = await sb.rpc('bootstrap_organization', { p_org_name: org, p_branch_name: branch });
      if (error) { setMsg(error.message); return; }
      router.push('/admin');
    } finally { setBusy(false); }
  }

  return (
    <main className="mx-auto max-w-md px-6 py-20">
      <h1 className="mb-1 text-2xl font-semibold">Set up your hospital</h1>
      <p className="mb-6 text-sm text-neutral-600">One step: create your organization and first branch.</p>
      <Card>
        <div className="space-y-3">
          <Field label="Organization name" value={org} onChange={(e) => setOrg(e.target.value)} placeholder="Lagoon Hospital" />
          <Field label="First branch" value={branch} onChange={(e) => setBranch(e.target.value)} placeholder="Ikeja" />
          {msg && <p className="text-sm text-status-delayed">{msg}</p>}
          <Button onClick={create} disabled={busy || !org || !branch}>{busy ? '…' : 'Create'}</Button>
        </div>
      </Card>
    </main>
  );
}
