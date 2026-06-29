// Typed shapes for DB rows / RPC results (audit M3 — replace Record<string, any>).
import type { StageState, Acuity, StaffStatus, StaffRole } from './index.ts';

export interface Branch { id: string; name: string; organization_id?: string; qr_token?: string }
export interface Department { id: string; name: string; branch_id?: string }
export interface Service { id: string; name: string; department_id?: string; avg_duration_seconds?: number }
export interface StaffMember {
  id: string; user_id?: string; display_name: string; role: StaffRole;
  department_id?: string | null; status: StaffStatus;
}
export interface Flow { id: string; name: string; is_published: boolean; current_version_id?: string | null }

/** Row from the reception_queue view (RLS-scoped; phone is masked). */
export interface QueueRow {
  stage_id: string; visit_id: string; department_id: string; branch_id: string;
  state: StageState; acuity: Acuity; position: number | null;
  entered_state_at: string; grace_deadline: string | null;
  ticket_no: string; patient_name: string | null; patient_phone: string | null;
}

export interface HoursReturned { today_seconds: number; month_seconds: number; lifetime_seconds: number }
export interface PredictiveOp {
  department: string; waiting: number; servers: number;
  clear_min: number; recommend: string; projected_clear_min: number;
}
export interface SimResult {
  waiting: number; servers: number; new_servers: number;
  current_avg_wait_min: number; projected_avg_wait_min: number; delta_pct: number;
}
