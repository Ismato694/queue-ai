import { test } from 'node:test';
import assert from 'node:assert/strict';
import { messageFor, channelFor } from './messages.ts';

test('messageFor maps known events to patient-safe copy (no medical detail)', () => {
  assert.match(messageFor('your_turn'), /almost your turn/i);
  assert.match(messageFor('leave_now'), /leave now/i);
  assert.match(messageFor('delayed'), /wait has increased/i);
  assert.equal(messageFor('something_else'), 'Update on your visit.');
});

test('channelFor is cost-aware: SMS for action events (your_turn, leave_now), push otherwise (R6)', () => {
  assert.equal(channelFor('your_turn'), 'sms');
  assert.equal(channelFor('leave_now'), 'sms');
  assert.equal(channelFor('delayed'), 'push');
  assert.equal(channelFor('anything'), 'push');
});
