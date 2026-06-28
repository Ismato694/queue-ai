// Reception offline cache (R5). The desk must keep showing the queue during a network
// blip. We cache the last-good queue per (branch, dept) in localStorage and read it back
// when a refresh fails. Full conflict-resolving write-sync is a documented fast-follow.

export function cacheGet<T>(key: string): T | null {
  if (typeof window === 'undefined') return null;
  try { const v = window.localStorage.getItem(`qai:${key}`); return v ? (JSON.parse(v) as T) : null; }
  catch { return null; }
}

export function cacheSet<T>(key: string, value: T): void {
  if (typeof window === 'undefined') return;
  try { window.localStorage.setItem(`qai:${key}`, JSON.stringify(value)); } catch { /* quota/private mode */ }
}
