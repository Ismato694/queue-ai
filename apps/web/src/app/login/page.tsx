'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { getSupabase, supabaseConfigured } from '@/lib/supabase';
import { Button, Card, Field } from '@/lib/ui';

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
      const fn = mode === 'login'
        ? sb.auth.signInWithPassword({ email, password })
        : sb.auth.signUp({ email, password });
      const { error } = await fn;
      if (error) { setMsg(error.message); return; }
      router.push('/admin');
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
          className="mt-4 text-xs text-neutral-500 underline"
          onClick={() => setMode(mode === 'login' ? 'signup' : 'login')}
        >
          {mode === 'login' ? 'Need an account? Sign up' : 'Have an account? Sign in'}
        </button>
      </Card>
    </main>
  );
}
