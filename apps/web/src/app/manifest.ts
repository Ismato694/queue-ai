import type { MetadataRoute } from 'next';

// PWA manifest — makes the reception/staff surfaces installable on a desk device (R5).
export default function manifest(): MetadataRoute.Manifest {
  return {
    name: 'Queue.ai',
    short_name: 'Queue.ai',
    description: 'Customer Flow Operating System — giving people their time back.',
    start_url: '/',
    display: 'standalone',
    background_color: '#fafafa',
    theme_color: '#4f46e5',
    icons: [],
  };
}
