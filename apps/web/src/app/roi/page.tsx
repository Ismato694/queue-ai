'use client';
import { useState } from 'react';

// Live ROI calculator (Phase 17 sales tool) — the BUSINESS-OS model, interactive.
// Pure client, no auth/DB. Use it with a prospect to size their return on their numbers.
const ngn = (n: number) => '₦' + Math.round(n).toLocaleString();

export default function RoiPage() {
  const [visitsPerDay, setVisitsPerDay] = useState(300);
  const [daysPerMonth, setDaysPerMonth] = useState(26);
  const [contribution, setContribution] = useState(12000);     // ₦ per visit
  const [lossPct, setLossPct] = useState(8);                    // current abandon/no-show %
  const [reductionPct, setReductionPct] = useState(40);         // relative reduction Queue.ai delivers
  const [monthlyCost, setMonthlyCost] = useState(360000);       // all-in ₦/mo (Growth + SMS)
  const [baselineWaitMin, setBaselineWaitMin] = useState(40);
  const [newWaitMin, setNewWaitMin] = useState(28);

  const visitsMonth = visitsPerDay * daysPerMonth;
  const lostNow = visitsMonth * (lossPct / 100);
  const recovered = lostNow * (reductionPct / 100);
  const recoveredRevenue = recovered * contribution;
  const net = recoveredRevenue - monthlyCost;
  const roiX = monthlyCost > 0 ? recoveredRevenue / monthlyCost : 0;
  const hoursReturnedMonth = (visitsMonth * Math.max(baselineWaitMin - newWaitMin, 0)) / 60;

  return (
    <main className="mx-auto max-w-3xl px-6 py-12">
      <p className="text-sm font-medium text-accent">Queue.ai · ROI</p>
      <h1 className="mt-1 text-3xl font-semibold tracking-tight">What is your queue costing you?</h1>
      <p className="mt-2 text-neutral-600">Adjust to your numbers. This models recovered revenue from fewer abandoned/no-show visits.</p>

      <div className="mt-8 grid gap-6 md:grid-cols-2">
        <div className="space-y-4">
          <Num label="Patient visits / day" value={visitsPerDay} set={setVisitsPerDay} />
          <Num label="Operating days / month" value={daysPerMonth} set={setDaysPerMonth} />
          <Num label="Revenue per visit (₦)" value={contribution} set={setContribution} step={1000} />
          <Num label="Current loss rate (% abandon/no-show)" value={lossPct} set={setLossPct} />
          <Num label="Loss reduction Queue.ai delivers (%)" value={reductionPct} set={setReductionPct} />
          <Num label="Queue.ai all-in cost (₦/mo)" value={monthlyCost} set={setMonthlyCost} step={10000} />
          <div className="grid grid-cols-2 gap-3">
            <Num label="Baseline wait (min)" value={baselineWaitMin} set={setBaselineWaitMin} />
            <Num label="New wait (min)" value={newWaitMin} set={setNewWaitMin} />
          </div>
        </div>

        <div className="space-y-4">
          <Stat label="Visits recovered / month" value={Math.round(recovered).toLocaleString()} />
          <Stat label="Recovered revenue / month" value={ngn(recoveredRevenue)} />
          <Stat label="Queue.ai cost / month" value={ngn(monthlyCost)} muted />
          <div className="rounded-card bg-neutral-900 p-5 text-white">
            <p className="text-xs uppercase tracking-widest text-neutral-400">Net benefit / month</p>
            <p className={`tnum text-4xl font-semibold ${net >= 0 ? 'text-status-calm' : 'text-status-delayed'}`}>{ngn(net)}</p>
            <p className="mt-1 text-sm text-neutral-300">≈ {roiX.toFixed(1)}× return on cost</p>
          </div>
          <Stat label="⏱ Hours Returned / month" value={`${Math.round(hoursReturnedMonth).toLocaleString()} h`} highlight />
          <p className="text-xs text-neutral-400">
            Annual net ≈ {ngn(net * 12)}. Modeled estimate — the pilot measures your actual numbers, free, in 2 weeks.
          </p>
        </div>
      </div>
    </main>
  );
}

function Num({ label, value, set, step = 1 }: { label: string; value: number; set: (n: number) => void; step?: number }) {
  return (
    <label className="block text-sm">
      <span className="mb-1 block text-neutral-600">{label}</span>
      <input type="number" value={value} step={step} onChange={(e) => set(Number(e.target.value) || 0)}
        className="tnum w-full rounded-control border border-neutral-300 px-3 py-2" />
    </label>
  );
}
function Stat({ label, value, muted, highlight }: { label: string; value: string; muted?: boolean; highlight?: boolean }) {
  return (
    <div className="flex items-baseline justify-between border-b border-neutral-100 pb-2">
      <span className="text-sm text-neutral-500">{label}</span>
      <span className={`tnum text-lg font-semibold ${muted ? 'text-neutral-400' : highlight ? 'text-status-calm' : ''}`}>{value}</span>
    </div>
  );
}
