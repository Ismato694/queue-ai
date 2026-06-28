import type { Config } from 'tailwindcss';

// Design tokens from docs/03a-DESIGN-PHILOSOPHY.md §5 — calm, restrained, semantic.
export default {
  content: ['./src/**/*.{ts,tsx}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        // semantic status — color = meaning, never decoration; always paired with icon/label
        status: {
          calm:    '#16a34a', // free / on-track / healthy
          busy:    '#d97706', // busy / watch
          delayed: '#dc2626', // delayed / bottleneck (used rarely → stays meaningful)
          info:    '#2563eb', // changed / neutral info (Q6)
        },
        accent: '#4f46e5', // single brand accent (primary actions, "you")
      },
      borderRadius: { card: '14px', control: '8px' },
      fontFamily: { sans: ['Inter', 'system-ui', 'sans-serif'] },
      transitionTimingFunction: { calm: 'cubic-bezier(0.16, 1, 0.3, 1)' },
    },
  },
  plugins: [],
} satisfies Config;
