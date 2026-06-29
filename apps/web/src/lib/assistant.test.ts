import { test } from 'node:test';
import assert from 'node:assert/strict';
import { askAssistant, dailySummary, type Overview } from './assistant.ts';

const o: Overview = {
  flow_score: 88,
  waiting_total: 14,
  avg_wait_seconds: 900,           // 15 min
  no_show_rate: 0.07,
  served_today: 120,
  time_saved_seconds: 41 * 3600,   // 41h
  departments: [
    { name: 'Reception',    waiting: 2,  longest_wait_s: 120,  status: 'calm' },
    { name: 'Laboratory',   waiting: 9,  longest_wait_s: 1500, status: 'delayed' },
    { name: 'Pharmacy',     waiting: 0,  longest_wait_s: 0,    status: 'calm' },
  ],
};

test('daily summary is grounded in the numbers', () => {
  const s = dailySummary(o);
  assert.match(s, /88\/100/);          // flow score
  assert.match(s, /15 min/);           // avg wait
  assert.match(s, /41h/);              // hours returned
  assert.match(s, /Laboratory/);       // names the worst dept
});

test('bottleneck question identifies the delayed department with citations', async () => {
  const r = await askAssistant('why is today slower?', o);
  assert.match(r.answer, /Laboratory/);
  assert.ok(r.citations.length > 0, 'must cite the metrics it used');
});

test('no-show question returns the real rate', async () => {
  const r = await askAssistant('what is the no show rate', o);
  assert.match(r.answer, /7%/);
  assert.deepEqual(r.citations, ['no_show_rate']);
});

test('time-saved question reports hours returned', async () => {
  const r = await askAssistant('how much time saved today?', o);
  assert.match(r.answer, /41 hours/);
});

test('grounding: it never invents a department not in the data', async () => {
  const r = await askAssistant('where is the bottleneck', o);
  assert.doesNotMatch(r.answer, /Radiology|Cardiology|Cashier/); // not in this overview
});
