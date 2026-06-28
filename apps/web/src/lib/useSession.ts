'use client';
import { useEffect, useState } from 'react';
import { getSupabase, supabaseConfigured } from './supabase';

export interface SessionState {
  loading: boolean;
  userId: string | null;
  email: string | null;
  organizationId: string | null; // null = signed in but not yet onboarded
}

/** Tracks auth session + whether the user has an org (staff row). */
export function useSession(): SessionState {
  const [state, setState] = useState<SessionState>({
    loading: true, userId: null, email: null, organizationId: null,
  });

  useEffect(() => {
    if (!supabaseConfigured) { setState((s) => ({ ...s, loading: false })); return; }
    const sb = getSupabase();
    let active = true;

    async function load(userId: string | null, email: string | null) {
      if (!userId) { if (active) setState({ loading: false, userId: null, email: null, organizationId: null }); return; }
      const { data } = await sb.from('staff').select('organization_id').eq('user_id', userId).limit(1).maybeSingle();
      if (active) setState({ loading: false, userId, email, organizationId: data?.organization_id ?? null });
    }

    sb.auth.getSession().then(({ data }) => {
      const u = data.session?.user;
      load(u?.id ?? null, u?.email ?? null);
    });
    const { data: sub } = sb.auth.onAuthStateChange((_e, session) => {
      const u = session?.user;
      load(u?.id ?? null, u?.email ?? null);
    });
    return () => { active = false; sub.subscription.unsubscribe(); };
  }, []);

  return state;
}
