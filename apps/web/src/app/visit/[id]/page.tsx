'use client';
import { useCallback, useEffect, useState } from 'react';
import { useParams } from 'next/navigation';
import { getSupabase, supabaseConfigured } from '@/lib/supabase';

type Stage = { name: string; state: string; is_current: boolean };
type Status = {
  branch_name: string; status: string;
  eta_low_s: number | null; eta_high_s: number | null;
  confidence: number | null; reasons: string[]; stages: Stage[];
};
type Leave = {
  state: string | null; travel_seconds: number | null;
  wait_if_join_now_s: number | null; leave_now: boolean;
};
const mins = (s: number) => Math.max(1, Math.round(s / 60));
const TRAVEL_CHOICES = [5, 10, 15, 20, 30, 45]; // minutes away

export default function VisitPage() {
  const id = String(useParams().id);
  const [s, setS] = useState<Status | null>(null);
  const [leave, setLeave] = useState<Leave | null>(null);
  const [acting, setActing] = useState(false);
  const [gpsMsg, setGpsMsg] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!supabaseConfigured) return;
    const sb = getSupabase();
    const [st, lv] = await Promise.all([
      sb.rpc('get_visit_status', { p_visit_id: id }),
      sb.rpc('get_leave_status', { p_visit_id: id }),
    ]);
    if (st.data) setS(st.data as Status);
    if (lv.data) setLeave(lv.data as Leave);
  }, [id]);

  useEffect(() => { load(); const t = setInterval(load, 4000); return () => clearInterval(t); }, [load]);

  if (!s) return <main className="mx-auto max-w-md px-6 py-16 text-sm text-muted">Loading your visit…</main>;

  const current = s.stages.find((x) => x.is_current);
  const isPreQueue = current?.state === 'pre_queue';
  const isCalled = current?.state === 'called';
  const done = s.status === 'completed';

  async function activate() {
    setActing(true);
    try { await getSupabase().rpc('activate_visit', { p_visit_id: id, p_trigger: 'on_my_way' }); await load(); }
    finally { setActing(false); }
  }

  async function setTravel(minutes: number) {
    setActing(true);
    try { await getSupabase().rpc('set_travel_time', { p_visit_id: id, p_travel_seconds: minutes * 60 }); await load(); }
    finally { setActing(false); }
  }

  function setTravelFromGps() {
    if (!('geolocation' in navigator)) { setGpsMsg('Location not available on this device.'); return; }
    setActing(true); setGpsMsg('Measuring your distance…');
    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        try {
          const { data } = await getSupabase().rpc('set_travel_from_gps', {
            p_visit_id: id, p_lat: pos.coords.latitude, p_lng: pos.coords.longitude,
          });
          const r = data as { ok: boolean; reason?: string; travel_seconds?: number } | null;
          if (r?.ok) { setGpsMsg(null); await load(); }
          else setGpsMsg('This branch has no location set; pick your distance below instead.');
        } finally { setActing(false); }
      },
      () => { setGpsMsg('Couldn\'t read your location; pick your distance below.'); setActing(false); },
      { enableHighAccuracy: true, timeout: 10000 },
    );
  }

  function checkInGps() {
    if (!('geolocation' in navigator)) { setGpsMsg('Location not available on this device.'); return; }
    setActing(true); setGpsMsg('Checking your location…');
    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        try {
          const { data } = await getSupabase().rpc('activate_visit_gps', {
            p_visit_id: id, p_lat: pos.coords.latitude, p_lng: pos.coords.longitude,
          });
          const r = data as { ok: boolean; reason?: string; distance_m?: number } | null;
          if (r?.ok) { setGpsMsg('Checked in — you\'re in the queue.'); await load(); }
          else if (r?.reason === 'too_far') setGpsMsg(`You're ${r.distance_m}m away — get closer to check in automatically.`);
          else setGpsMsg('This branch has no geofence set; use "I\'m on my way".');
        } finally { setActing(false); }
      },
      () => { setGpsMsg('Couldn\'t read your location. Use "I\'m on my way" instead.'); setActing(false); },
      { enableHighAccuracy: true, timeout: 10000 },
    );
  }

  return (
    <main className="mx-auto max-w-md px-6 py-10">
      <p className="text-sm font-medium text-accent">{s.branch_name}</p>

      {done ? (
        <h1 className="mt-2 text-2xl font-semibold">✔ Visit complete</h1>
      ) : isCalled ? (
        <div className="mt-4 rounded-card border border-status-info/30 bg-status-info/5 p-5">
          <p className="text-sm text-status-info">● It's your turn</p>
          <p className="mt-1 text-2xl font-semibold">Please proceed to {current?.name}</p>
        </div>
      ) : leave?.leave_now ? (
        <div className="mt-4 rounded-card border border-status-calm/40 bg-status-calm/10 p-5">
          <p className="text-sm font-medium text-status-calm">🚶 Leave now</p>
          <p className="mt-1 text-2xl font-semibold">Head to {s.branch_name}</p>
          <p className="mt-1 text-sm text-muted">You're in the queue — leave now and you'll arrive right as you're called.</p>
        </div>
      ) : (
        <div className="mt-4">
          <p className="text-sm text-muted">You'll be seen in</p>
          <p className="tnum text-4xl font-semibold">
            {s.eta_low_s == null || s.eta_high_s == null
              ? 'calculating…'
              : mins(s.eta_low_s) === mins(s.eta_high_s)
                ? `~${mins(s.eta_high_s)} min`
                : `${mins(s.eta_low_s)}–${mins(s.eta_high_s)} min`}
          </p>
          {s.confidence != null && (
            <div className="mt-2">
              <p className="text-sm text-muted">{Math.round(s.confidence * 100)}% confidence</p>
              <div className="mt-1 h-1.5 w-40 overflow-hidden rounded-full bg-surface2">
                <div className="h-full bg-status-calm" style={{ width: `${Math.round(s.confidence * 100)}%` }} />
              </div>
              {s.reasons?.length > 0 && (
                <ul className="mt-2 text-xs text-muted">
                  {s.reasons.map((r, i) => <li key={i}>• {r}</li>)}
                </ul>
              )}
            </div>
          )}
        </div>
      )}

      {isPreQueue && !done && !leave?.leave_now && (
        <div className="mt-5 space-y-3">
          {leave?.travel_seconds == null ? (
            <div className="rounded-card border border-line p-4">
              <p className="text-sm font-medium">How far away are you?</p>
              <p className="mt-0.5 text-xs text-muted">We'll tell you exactly when to leave — no need to watch this page.</p>
              <button onClick={setTravelFromGps} disabled={acting}
                className="mt-3 w-full rounded-control border border-accent px-3 py-2 text-sm font-medium text-accent">
                📍 Use my location (auto)
              </button>
              <p className="mt-2 text-center text-xs text-faint">or pick manually</p>
              <div className="mt-1 grid grid-cols-3 gap-2">
                {TRAVEL_CHOICES.map((m) => (
                  <button key={m} onClick={() => setTravel(m)} disabled={acting}
                    className="rounded-control border border-line px-2 py-2 text-sm text-ink hover:border-accent">
                    {m} min
                  </button>
                ))}
              </div>
              {gpsMsg && <p className="mt-2 text-center text-xs text-muted">{gpsMsg}</p>}
            </div>
          ) : (
            <div className="rounded-card border border-line p-4">
              <p className="text-sm font-medium">✓ We'll alert you when to leave</p>
              <p className="mt-1 text-sm text-muted">
                You're about <b>{mins(leave.travel_seconds)} min</b> away. Current wait if you left now:{' '}
                <b>~{leave.wait_if_join_now_s != null ? mins(leave.wait_if_join_now_s) : '—'} min</b>. Sit tight.
              </p>
              <button onClick={() => setTravel(-1)} disabled={acting} className="mt-2 text-xs text-muted underline">
                Change distance
              </button>
            </div>
          )}

          <details className="text-sm text-muted">
            <summary className="cursor-pointer">Or check in manually</summary>
            <div className="mt-2 space-y-2">
              <button onClick={activate} disabled={acting}
                className="w-full rounded-control bg-accent px-4 py-3 font-medium text-white">
                {acting ? '…' : "I'm on my way"}
              </button>
              <button onClick={checkInGps} disabled={acting}
                className="w-full rounded-control border border-line px-4 py-3 text-sm font-medium text-muted">
                📍 Check in with my location
              </button>
              {gpsMsg && <p className="text-center text-xs text-muted">{gpsMsg}</p>}
            </div>
          </details>
        </div>
      )}

      <div className="mt-8">
        <h2 className="mb-3 text-sm font-semibold text-muted">Your journey</h2>
        <ol className="space-y-2">
          {s.stages.map((st, i) => (
            <li key={i} className="flex items-center gap-3 text-sm">
              <span className="w-5">{icon(st)}</span>
              <span className={st.is_current ? 'font-medium text-ink' : 'text-muted'}>
                {st.name}{st.is_current ? '  ← you are here' : ''}
              </span>
            </li>
          ))}
        </ol>
      </div>

      <p className="mt-10 text-xs text-faint">Law #0 — we're saving you time. Keep this page; it updates live.</p>
    </main>
  );
}

function icon(st: Stage) {
  if (['completed', 'transferred'].includes(st.state)) return '✔';
  if (st.is_current) return st.state === 'called' ? '●' : '⏳';
  if (st.state === 'cancelled' || st.state === 'no_show') return '✕';
  return '○';
}
