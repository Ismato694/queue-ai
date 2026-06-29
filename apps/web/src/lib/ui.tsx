'use client';
import { type ReactNode, useEffect, useState } from 'react';
import { Moon, Sun, Loader2, type LucideIcon } from 'lucide-react';

// Design-system primitives (docs/03a-DESIGN-PHILOSOPHY.md) — calm, restrained, theme-aware.

type Variant = 'primary' | 'secondary' | 'ghost' | 'danger';
type Size = 'sm' | 'md';

export function Button({
  children, onClick, type = 'button', disabled, busy, variant = 'primary', size = 'md', icon: Icon, full,
}: {
  children?: ReactNode; onClick?: () => void; type?: 'button' | 'submit';
  disabled?: boolean; busy?: boolean; variant?: Variant; size?: Size; icon?: LucideIcon; full?: boolean;
}) {
  const base = 'inline-flex items-center justify-center gap-2 font-medium rounded-control transition-all duration-150 ease-calm active:scale-[0.98] focus-visible:shadow-focus disabled:opacity-50 disabled:pointer-events-none select-none';
  const sizes: Record<Size, string> = { sm: 'h-8 px-3 text-xs', md: 'h-10 px-4 text-sm' };
  const variants: Record<Variant, string> = {
    primary: 'bg-accent text-accent-ink shadow-xs hover:brightness-110',
    secondary: 'bg-surface text-ink border border-line shadow-xs hover:bg-surface2',
    ghost: 'text-muted hover:bg-surface2 hover:text-ink',
    danger: 'bg-status-delayed text-white shadow-xs hover:brightness-110',
  };
  return (
    <button type={type} onClick={onClick} disabled={disabled || busy}
      className={`${base} ${sizes[size]} ${variants[variant]} ${full ? 'w-full' : ''}`}>
      {busy ? <Loader2 size={16} className="animate-spin" /> : Icon ? <Icon size={16} /> : null}
      {children}
    </button>
  );
}

export function IconButton({ icon: Icon, onClick, label }: { icon: LucideIcon; onClick?: () => void; label: string }) {
  return (
    <button onClick={onClick} aria-label={label}
      className="grid h-9 w-9 place-items-center rounded-control text-muted transition-colors hover:bg-surface2 hover:text-ink focus-visible:shadow-focus">
      <Icon size={18} />
    </button>
  );
}

export function Card({ title, icon: Icon, children, hover, className = '' }:
  { title?: string; icon?: LucideIcon; children: ReactNode; hover?: boolean; className?: string }) {
  return (
    <div className={`rounded-card border border-line bg-surface p-5 shadow-card transition-all duration-200 ease-calm ${hover ? 'hover:-translate-y-0.5 hover:shadow-lift' : ''} ${className}`}>
      {title && (
        <h2 className="mb-3 flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-muted">
          {Icon && <Icon size={14} />}{title}
        </h2>
      )}
      {children}
    </div>
  );
}

export function Field({ label, ...props }: { label?: string } & React.InputHTMLAttributes<HTMLInputElement>) {
  return (
    <label className="block text-sm">
      {label && <span className="mb-1.5 block font-medium text-muted">{label}</span>}
      <input {...props}
        className="w-full rounded-control border border-line bg-surface px-3 py-2 text-ink placeholder:text-faint outline-none transition-all focus:border-accent focus-visible:shadow-focus" />
    </label>
  );
}

export function Select({ value, onChange, children, ...rest }:
  { value: string; onChange: (v: string) => void; children: ReactNode } & Omit<React.SelectHTMLAttributes<HTMLSelectElement>, 'onChange' | 'value'>) {
  return (
    <select value={value} onChange={(e) => onChange(e.target.value)} {...rest}
      className="rounded-control border border-line bg-surface px-3 py-2 text-sm text-ink outline-none transition-all focus:border-accent focus-visible:shadow-focus">
      {children}
    </select>
  );
}

export function Badge({ children, tone = 'neutral' }:
  { children: ReactNode; tone?: 'neutral' | 'calm' | 'busy' | 'delayed' | 'info' | 'accent' }) {
  const tones: Record<string, string> = {
    neutral: 'bg-surface2 text-muted',
    calm: 'bg-status-calm/10 text-status-calm',
    busy: 'bg-status-busy/10 text-status-busy',
    delayed: 'bg-status-delayed/10 text-status-delayed',
    info: 'bg-status-info/10 text-status-info',
    accent: 'bg-accent/10 text-accent',
  };
  return <span className={`inline-flex items-center gap-1 rounded-pill px-2 py-0.5 text-xs font-medium ${tones[tone]}`}>{children}</span>;
}

export function StatusDot({ status }: { status: 'calm' | 'busy' | 'delayed' | string }) {
  const c = status === 'delayed' ? 'bg-status-delayed' : status === 'busy' ? 'bg-status-busy' : 'bg-status-calm';
  return <span className={`inline-block h-2 w-2 rounded-full ${c}`} />;
}

export function Spinner() { return <Loader2 size={16} className="animate-spin text-muted" />; }

export function ThemeToggle() {
  const [dark, setDark] = useState(false);
  useEffect(() => { setDark(document.documentElement.classList.contains('dark')); }, []);
  const toggle = () => {
    const next = !dark; setDark(next);
    document.documentElement.classList.toggle('dark', next);
    try { localStorage.setItem('qai-theme', next ? 'dark' : 'light'); } catch { /* ignore */ }
  };
  return <IconButton icon={dark ? Sun : Moon} onClick={toggle} label="Toggle theme" />;
}
