import './globals.css';
import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import { FloatingThemeToggle } from '@/lib/floating-theme';

const inter = Inter({ subsets: ['latin'], variable: '--font-inter', display: 'swap' });

export const metadata: Metadata = {
  title: 'Queue.ai — Customer Flow OS',
  description: 'Removing decisions, giving people their time back.',
};

// Set the theme class before paint to avoid a flash of the wrong theme.
const themeInit = `(function(){try{var t=localStorage.getItem('qai-theme');var d=t?t==='dark':window.matchMedia('(prefers-color-scheme: dark)').matches;if(d)document.documentElement.classList.add('dark');}catch(e){}})();`;

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={inter.variable} suppressHydrationWarning>
      <head><script dangerouslySetInnerHTML={{ __html: themeInit }} /></head>
      <body className="font-sans">{children}<FloatingThemeToggle /></body>
    </html>
  );
}
