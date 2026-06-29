import type { Config } from 'tailwindcss';

// Design system (docs/03a-DESIGN-PHILOSOPHY.md §5) — calm, restrained, theme-aware.
// Structural colors are CSS variables (light/dark in globals.css); status colors are fixed
// (meaningful in both themes). Color = meaning, never decoration.
export default {
  content: ['./src/**/*.{ts,tsx}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        canvas:    'rgb(var(--canvas) / <alpha-value>)',     // page background
        surface:   'rgb(var(--surface) / <alpha-value>)',    // cards
        surface2:  'rgb(var(--surface2) / <alpha-value>)',   // insets
        line:      'rgb(var(--line) / <alpha-value>)',        // borders
        ink:       'rgb(var(--ink) / <alpha-value>)',         // primary text
        muted:     'rgb(var(--muted) / <alpha-value>)',       // secondary text
        faint:     'rgb(var(--faint) / <alpha-value>)',       // tertiary text
        accent:    'rgb(var(--accent) / <alpha-value>)',      // brand / primary action
        'accent-ink': 'rgb(var(--accent-ink) / <alpha-value>)', // text on accent
        status: {
          calm:    '#16a34a',
          busy:    '#d97706',
          delayed: '#dc2626',
          info:    '#2563eb',
        },
      },
      borderRadius: { card: '16px', control: '10px', pill: '999px' },
      fontFamily: { sans: ['var(--font-inter)', 'system-ui', 'sans-serif'] },
      boxShadow: {
        // soft, Stripe-like elevation (kept subtle)
        xs: '0 1px 2px 0 rgb(0 0 0 / 0.04)',
        card: '0 1px 2px rgb(0 0 0 / 0.04), 0 4px 12px -2px rgb(0 0 0 / 0.06)',
        lift: '0 2px 4px rgb(0 0 0 / 0.05), 0 12px 28px -6px rgb(0 0 0 / 0.12)',
        focus: '0 0 0 3px rgb(var(--accent) / 0.25)',
      },
      transitionTimingFunction: { calm: 'cubic-bezier(0.16, 1, 0.3, 1)' },
      keyframes: {
        'fade-up': { '0%': { opacity: '0', transform: 'translateY(6px)' }, '100%': { opacity: '1', transform: 'translateY(0)' } },
        'fade-in': { '0%': { opacity: '0' }, '100%': { opacity: '1' } },
        shimmer: { '100%': { transform: 'translateX(100%)' } },
      },
      animation: {
        'fade-up': 'fade-up 0.4s cubic-bezier(0.16,1,0.3,1) both',
        'fade-in': 'fade-in 0.3s ease both',
      },
    },
  },
  plugins: [],
} satisfies Config;
