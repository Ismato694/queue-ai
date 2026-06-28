// Flow Intelligence assistant (docs/07 §9). GROUNDED: answers are built only from the
// live `overview` metrics — never invented (R7). The generation step is MOCKED here;
// it's structured as a clean swap-in for Claude (Sonnet 4.6) later — when ANTHROPIC_API_KEY
// is wired through the worker/an API route, replace `mockGenerate` with the real call.
// The grounding contract (answer + citations from real numbers) stays identical.

export interface Overview {
  flow_score: number;
  waiting_total: number;
  avg_wait_seconds: number;
  no_show_rate: number;
  served_today: number;
  time_saved_seconds: number;
  departments: { name: string; waiting: number; longest_wait_s: number; status: string }[];
}

export interface AssistantResult {
  answer: string;
  citations: string[];   // the metrics each claim is grounded in
}

const mins = (s: number) => Math.round(s / 60);

function worstDept(o: Overview) {
  return [...o.departments].sort((a, b) => b.longest_wait_s - a.longest_wait_s)[0];
}
function bestDept(o: Overview) {
  const active = o.departments.filter((d) => d.waiting > 0);
  return (active.length ? active : o.departments).sort((a, b) => a.longest_wait_s - b.longest_wait_s)[0];
}

/** Deterministic, grounded daily summary (mock of the Claude-generated report). */
export function dailySummary(o: Overview): string {
  const worst = worstDept(o); const best = bestDept(o);
  const parts = [`Flow Score is ${o.flow_score}/100 with ${o.waiting_total} waiting and an average wait of ${mins(o.avg_wait_seconds)} min.`];
  if (best) parts.push(`${best.name} is running smoothly.`);
  if (worst && worst.status === 'delayed') parts.push(`${worst.name} is the constraint (longest wait ~${mins(worst.longest_wait_s)} min) — consider opening another counter there.`);
  parts.push(`You've saved patients ~${Math.round(o.time_saved_seconds / 3600)}h today.`);
  return parts.join(' ');
}

/** Grounded Q&A (mock). Pattern-matches the question, answers from real numbers + cites them. */
export async function askAssistant(question: string, o: Overview): Promise<AssistantResult> {
  // ↳ swap-in point: send `question` + `o` (de-identified metrics only, docs/08 §7.1)
  //   to Claude with structured outputs, return {answer, citations}. Mock below.
  return mockGenerate(question, o);
}

function mockGenerate(question: string, o: Overview): AssistantResult {
  const q = question.toLowerCase();
  const worst = worstDept(o);

  if (q.includes('slow') || q.includes('bottleneck') || q.includes('delay')) {
    return {
      answer: worst
        ? `${worst.name} is the bottleneck right now — ${worst.waiting} waiting, longest wait ~${mins(worst.longest_wait_s)} min (status: ${worst.status}). Opening another counter there would cut the wait fastest.`
        : `No department is currently a bottleneck — all queues are calm.`,
      citations: [`departments.${worst?.name}.longest_wait_s`, 'departments[].status'],
    };
  }
  if (q.includes('time') && q.includes('save')) {
    return { answer: `Today you've returned about ${Math.round(o.time_saved_seconds / 3600)} hours to patients vs. the baseline wait.`,
             citations: ['time_saved_seconds'] };
  }
  if (q.includes('no') && q.includes('show')) {
    return { answer: `Today's no-show rate is ${Math.round(o.no_show_rate * 100)}%.`, citations: ['no_show_rate'] };
  }
  if (q.includes('how') || q.includes('today') || q.includes('overall')) {
    return { answer: dailySummary(o), citations: ['flow_score', 'avg_wait_seconds', 'time_saved_seconds'] };
  }
  return {
    answer: `Right now: Flow Score ${o.flow_score}/100, ${o.waiting_total} waiting, avg wait ${mins(o.avg_wait_seconds)} min. Ask about bottlenecks, no-shows, or time saved.`,
    citations: ['flow_score', 'waiting_total', 'avg_wait_seconds'],
  };
}
