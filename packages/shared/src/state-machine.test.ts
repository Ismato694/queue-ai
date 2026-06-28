import { test } from 'node:test';
import assert from 'node:assert/strict';
import { canTransition, STAGE_TRANSITIONS, channels, type StageState } from './index.ts';

test('valid forward transitions', () => {
  assert.equal(canTransition('pre_queue', 'active'), true);
  assert.equal(canTransition('active', 'called'), true);
  assert.equal(canTransition('called', 'serving'), true);
  assert.equal(canTransition('serving', 'completed'), true);
  assert.equal(canTransition('serving', 'transferred'), true);
});

test('grace re-queue and delay are allowed', () => {
  assert.equal(canTransition('called', 'active'), true);   // requeue within grace (R4)
  assert.equal(canTransition('serving', 'active'), true);  // delay back to queue
});

test('terminal states cannot transition out', () => {
  for (const t of ['completed', 'no_show', 'expired', 'cancelled'] as StageState[]) {
    assert.deepEqual(STAGE_TRANSITIONS[t], []);
    assert.equal(canTransition(t, 'active'), false);
  }
});

test('illegal jumps are rejected', () => {
  assert.equal(canTransition('pre_queue', 'serving'), false);  // must go via active->called
  assert.equal(canTransition('active', 'completed'), false);
  assert.equal(canTransition('booked', 'serving'), false);
});

test('channel naming is stable (matches API contract)', () => {
  assert.equal(channels.visit('v1'), 'visit:v1');
  assert.equal(channels.branchQueue('b1'), 'branch:b1:queue');
  assert.equal(channels.display('b1'), 'display:b1');
});
