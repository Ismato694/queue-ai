'use client';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useSession } from '@/lib/useSession';
import { getSupabase } from '@/lib/supabase';

const nav = [
  { href: '/admin', label: 'Overview' },
  { href: '/admin/structure', label: 'Structure' },
  { href: '/admin/flows', label: 'Flow Builder' },
];

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const { loading, userId, organizationId } = useSession();

  if (loading) return <main className="p-10 text-sm text-muted">Loading…</main>;
  if (!userId) { router.push('/login'); return null; }
  if (!organizationId) { router.push('/onboarding'); return null; }

  return (
    <div className="min-h-screen">
      <header className="flex items-center justify-between border-b border-line bg-surface px-6 py-3">
        <div className="flex items-center gap-6">
          <span className="text-sm font-semibold text-accent">Queue.ai</span>
          <nav className="flex gap-4 text-sm">
            {nav.map((n) => <Link key={n.href} href={n.href} className="text-muted hover:text-ink">{n.label}</Link>)}
          </nav>
        </div>
        <button
          className="text-xs text-muted underline"
          onClick={async () => { await getSupabase().auth.signOut(); router.push('/login'); }}
        >Sign out</button>
      </header>
      <main className="mx-auto max-w-5xl px-6 py-8">{children}</main>
    </div>
  );
}
