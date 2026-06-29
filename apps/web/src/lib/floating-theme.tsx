'use client';
import { ThemeToggle } from './ui';

// One global dark/light toggle, fixed bottom-right, available on every screen.
export function FloatingThemeToggle() {
  return (
    <div className="fixed bottom-4 right-4 z-50 rounded-pill border border-line bg-surface/90 shadow-card backdrop-blur">
      <ThemeToggle />
    </div>
  );
}
