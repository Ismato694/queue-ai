'use client';
import Link from 'next/link';
import { Card } from '@/lib/ui';

export default function AdminHome() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Admin</h1>
        <p className="text-sm text-neutral-600">Configure your hospital, then build its flow.</p>
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        <Link href="/admin/structure"><Card title="Structure">Branches · departments · services · staff →</Card></Link>
        <Link href="/admin/flows"><Card title="Flow Builder (F1)">Define the patient journey →</Card></Link>
        <Link href="/reception"><Card title="Reception board">Run the live queue →</Card></Link>
        <Link href="/staff"><Card title="Staff view">Call next · complete →</Card></Link>
        <Link href="/manager"><Card title="Manager dashboard">Flow Score · Digital Twin · Flow Intelligence →</Card></Link>
      </div>
      <p className="text-xs text-neutral-500">
        Public display: open <code>/display/&lt;branch QR token&gt;</code> on a waiting-room screen (numbers only).
      </p>
      <p className="text-xs text-neutral-400">Law #0 — Time is the Product. Every screen removes a decision.</p>
    </div>
  );
}
