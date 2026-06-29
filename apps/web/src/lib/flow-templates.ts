// Industry flow templates (Phase 16) — proof that the engine is industry-agnostic (F1).
// A template is just a list of stage names + a duration seed. The admin maps each stage
// to one of their own departments in the Flow Builder. Same engine, different rows.

export type IndustryTemplate = 'hospital' | 'bank' | 'passport' | 'university' | 'custom';

export interface TemplateStage { name: string; minutes: number }

export const FLOW_TEMPLATES: Record<Exclude<IndustryTemplate, 'custom'>, TemplateStage[]> = {
  hospital: [
    { name: 'Reception', minutes: 3 },
    { name: 'Vitals', minutes: 5 },
    { name: 'Consultation', minutes: 12 },
    { name: 'Laboratory', minutes: 9 },
    { name: 'Review', minutes: 5 },
    { name: 'Pharmacy', minutes: 5 },
    { name: 'Cashier', minutes: 3 },
  ],
  bank: [
    { name: 'Reception', minutes: 2 },
    { name: 'Customer Service', minutes: 8 },
    { name: 'Cashier', minutes: 5 },
    { name: 'Manager Approval', minutes: 6 },
  ],
  passport: [
    { name: 'Security', minutes: 3 },
    { name: 'Biometrics', minutes: 7 },
    { name: 'Document Verification', minutes: 8 },
    { name: 'Interview', minutes: 10 },
    { name: 'Collection', minutes: 4 },
  ],
  university: [
    { name: 'Reception', minutes: 3 },
    { name: 'Registration', minutes: 8 },
    { name: 'Bursary / Fees', minutes: 6 },
    { name: 'ID Card', minutes: 5 },
  ],
};

export const TEMPLATE_LABELS: Record<Exclude<IndustryTemplate, 'custom'>, string> = {
  hospital: 'Hospital — outpatient visit',
  bank: 'Bank — branch service',
  passport: 'Passport / Government office',
  university: 'University — enrolment',
};
