import './globals.css';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Queue.ai — Customer Flow OS',
  description: 'Removing decisions, giving people their time back.',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
