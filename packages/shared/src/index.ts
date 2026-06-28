// Queue.ai shared domain types — mirror docs/04-DATABASE.md.
// Single source of truth for enums/shapes across web + worker.

// ── Enums (match Postgres types in supabase/migrations/0001_init.sql) ──
export type StaffRole = 'super_admin' | 'org_admin' | 'manager' | 'receptionist' | 'staff';
export type StaffStatus = 'online' | 'away' | 'break' | 'offline';
export type Acuity = 'routine' | 'priority' | 'emergency';
export type VisitStatus = 'active' | 'completed' | 'cancelled';
export type JoinChannel = 'receptionist' | 'qr' | 'web' | 'whatsapp' | 'sms';
export type IndustryTemplate = 'hospital' | 'bank' | 'passport' | 'custom';
export type ActivationTrigger = 'gps' | 'on_my_way' | 'qr' | 'receptionist';
export type PredictionKind = 'stage_eta' | 'visit_eta' | 'leave_by' | 'dept_load';
export type NotifChannel = 'push' | 'sms' | 'whatsapp' | 'email' | 'voice';

// The canonical ticket/stage state machine (docs/02-USER-FLOWS.md §2)
export type StageState =
  | 'booked' | 'pre_queue' | 'active' | 'called' | 'serving'
  | 'completed' | 'transferred' | 'no_show' | 'expired' | 'cancelled';

// Allowed transitions — the engine validates against this map.
export const STAGE_TRANSITIONS: Record<StageState, StageState[]> = {
  booked:      ['pre_queue', 'active', 'cancelled', 'expired'],
  pre_queue:   ['active', 'cancelled', 'expired'],
  active:      ['called', 'cancelled'],
  called:      ['serving', 'no_show', 'active'],     // active = requeue within grace (R4)
  serving:     ['completed', 'transferred', 'active'], // active = delay back to queue
  transferred: ['active'],                           // next stage activates
  completed:   [],
  no_show:     [],
  expired:     [],
  cancelled:   [],
};

export function canTransition(from: StageState, to: StageState): boolean {
  return STAGE_TRANSITIONS[from]?.includes(to) ?? false;
}

// ── Core shapes ──
export interface Prediction {
  kind: PredictionKind;
  valueLowS: number;
  valueHighS: number;
  confidence: number;       // 0..1
  reasons: string[];        // Trust Engine F11: the "why"
  modelVersion: string;
}

export interface JourneyStage {
  name: string;
  state: StageState;
  isCurrent: boolean;
  position?: number;
}

// Realtime channel naming (docs/05-API.md §5)
export const channels = {
  visit: (visitId: string) => `visit:${visitId}`,
  branchQueue: (branchId: string) => `branch:${branchId}:queue`,
  branchTwin: (branchId: string) => `branch:${branchId}:twin`,
  display: (branchId: string) => `display:${branchId}`,
};
