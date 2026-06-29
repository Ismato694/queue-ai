'use client';
import Link from 'next/link';
import { Card } from '@/lib/ui';

export default function AdminHome() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Admin</h1>
        <p className="text-sm text-muted">Configure your hospital, then build its flow.</p>
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        <Link href="/admin/structure"><Card title="Structure">Branches · departments · services · staff →</Card></Link>
        <Link href="/admin/flows"><Card title="Flow Builder (F1)">Define the patient journey →</Card></Link>
        <Link href="/reception"><Card title="Reception board">Run the live queue →</Card></Link>
        <Link href="/staff"><Card title="Staff view">Call next · complete →</Card></Link>
        <Link href="/manager"><Card title="Manager dashboard">Flow Score · Digital Twin · Flow Intelligence →</Card></Link>
      </div>
      <p className="text-xs text-muted">
        QR code & shareable links (customer join, waiting-room display, public board) are in{' '}
        <Link href="/admin/structure" className="text-accent underline">Structure → Branch access</Link>.
      </p>
      <p className="text-xs text-faint">Law #0 — Time is the Product. Every screen removes a decision.</p>
    </div>
  );
}
