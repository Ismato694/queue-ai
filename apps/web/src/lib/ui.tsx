'use client';
import { type ReactNode } from 'react';

// Tiny shared UI primitives carrying the 03a tokens (calm, restrained).
export function Button(
  { children, onClick, type = 'button', disabled, variant = 'primary' }:
  { children: ReactNode; onClick?: () => void; type?: 'button' | 'submit'; disabled?: boolean; variant?: 'primary' | 'ghost' },
) {
  const base = 'rounded-control px-4 py-2 text-sm font-medium transition-all duration-150 ease-calm disabled:opacity-50';
  const styles = variant === 'primary'
    ? 'bg-accent text-white hover:opacity-90'
    : 'border border-neutral-300 text-neutral-700 hover:bg-neutral-100';
  return <button type={type} onClick={onClick} disabled={disabled} className={`${base} ${styles}`}>{children}</button>;
}

export function Card({ title, children }: { title?: string; children: ReactNode }) {
  return (
    <div className="rounded-card border border-neutral-200 bg-white p-5">
      {title && <h2 className="mb-3 text-sm font-semibold text-neutral-500">{title}</h2>}
      {children}
    </div>
  );
}

export function Field({ label, ...props }: { label: string } & React.InputHTMLAttributes<HTMLInputElement>) {
  return (
    <label className="block text-sm">
      <span className="mb-1 block text-neutral-600">{label}</span>
      <input {...props} className="w-full rounded-control border border-neutral-300 px-3 py-2 outline-none focus:border-accent" />
    </label>
  );
}
