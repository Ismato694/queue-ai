'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { getSupabase, supabaseConfigured } from '@/lib/supabase';
import { Button, Card, Field } from '@/lib/ui';

// each staff role has a home screen (org_admin → admin console)
function routeForRole(role?: string | null): string {
  switch (role) {
    case 'manager': return '/manager';
    case 'receptionist': return '/reception';
    case 'staff': return '/staff';
    default: return '/admin'; // org_admin / unknown
  }
}

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [mode, setMode] = useState<'login' | 'signup'>('login');
  const [msg, setMsg] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit() {
    setBusy(true); setMsg(null);
    try {
      const sb = getSupabase();
      const { data, error } = mode === 'login'
        ? await sb.auth.signInWithPassword({ email, password })
        : await sb.auth.signUp({ email, password });
      if (error) { setMsg(error.message); return; }

      // signup may require email confirmation → no session yet
      const uid = data.session?.user?.id;
      if (!uid) { setMsg('Account created — check your email to confirm, then sign in.'); setMode('login'); return; }

      // link any pending staff invite for this email (0031), then route by role
      await sb.rpc('claim_staff_membership');
      const { data: me } = await sb.from('staff')
        .select('role, organization_id').eq('user_id', uid).maybeSingle();
      if (!me?.organization_id) { router.push('/onboarding'); return; }
      router.push(routeForRole(me.role));
    } finally { setBusy(false); }
  }

  return (
    <main className="mx-auto max-w-md px-6 py-20">
      <p className="text-sm font-medium text-accent">Queue.ai</p>
      <h1 className="mt-1 mb-6 text-2xl font-semibold">{mode === 'login' ? 'Sign in' : 'Create account'}</h1>
      <Card>
        {!supabaseConfigured && (
          <p className="mb-3 text-sm text-status-busy">Set NEXT_PUBLIC_SUPABASE_* in .env.local to enable auth.</p>
        )}
        <div className="space-y-3">
          <Field label="Email" type="email" value={email} onChange={(e) => setEmail(e.target.value)} />
          <Field label="Password" type="password" value={password} onChange={(e) => setPassword(e.target.value)} />
          {msg && <p className="text-sm text-status-delayed">{msg}</p>}
          <Button type="button" onClick={submit} disabled={busy || !supabaseConfigured}>
            {busy ? '…' : mode === 'login' ? 'Sign in' : 'Sign up'}
          </Button>
        </div>
        <button
          className="mt-4 text-xs text-muted underline"
          onClick={() => setMode(mode === 'login' ? 'signup' : 'login')}
        >
          {mode === 'login' ? 'Need an account? Sign up' : 'Have an account? Sign in'}
        </button>
      </Card>
    </main>
  );
}
