import Link from 'next/link';
import { supabaseConfigured } from '@/lib/supabase';

// S0 status page — renders before Supabase credentials exist, and confirms wiring once they do.
// Real auth + org/branch CRUD land in S0/S1 once a Supabase project is connected.
export default function Home() {
  return (
    <main className="mx-auto max-w-2xl px-6 py-16">
      <p className="text-sm font-medium text-accent">Queue.ai · Customer Flow OS</p>
      <h1 className="mt-2 text-3xl font-semibold tracking-tight">
        Removing decisions. Giving people their time back.
      </h1>
      <p className="mt-4 text-neutral-600">
        Foundation scaffold (Sprint&nbsp;S0). Database schema, RLS, tenant model, and the
        hospital care-pathway seed are in place. Next: connect a Supabase project and wire auth.
      </p>

      <div className="mt-8 rounded-card border border-neutral-200 bg-white p-5">
        <h2 className="text-sm font-semibold text-neutral-500">Environment check</h2>
        <ul className="mt-3 space-y-1 text-sm">
          <li>
            Supabase configured:{' '}
            <span className={supabaseConfigured ? 'text-status-calm' : 'text-status-busy'}>
              {supabaseConfigured ? '✓ connected' : '• not yet (set NEXT_PUBLIC_SUPABASE_* )'}
            </span>
          </li>
        </ul>
      </div>

      <div className="mt-6">
        <Link href="/admin" className="rounded-control bg-accent px-4 py-2 text-sm font-medium text-white">
          Open admin →
        </Link>
        <Link href="/login" className="ml-3 text-sm text-accent underline">Sign in</Link>
        <Link href="/roi" className="ml-3 text-sm text-accent underline">ROI calculator</Link>
      </div>

      <p className="mt-8 text-xs text-neutral-400">
        Law&nbsp;#0 — Time is the Product. See <code>/docs</code> for the full spec.
      </p>
    </main>
  );
}
