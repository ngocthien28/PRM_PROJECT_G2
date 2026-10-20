import {test} from 'node:test';
import assert from 'node:assert/strict';
import {buildMessage} from '../src/message.js';

test('delivery keeps stable notification identity for Android deduplication', () => {
  const message = buildMessage('n1', {userId: 'u1', title: 'Club joined',
    body: 'Joined Sport', type: 'club_membership', membershipStatus: 'active', referenceId: 'c1'}, 'token');
  assert.equal(message.android.notification.tag, 'n1');
  assert.equal(message.data.userId, 'u1');
  assert.equal(message.data.notificationId, 'n1');
  assert.equal(message.android.notification.channelId, 'campushub_updates');
});
test('unsupported payload cannot be sent', () => {
  assert.throws(() => buildMessage('n1', {userId: 'u1', type: 'unknown'}, 'token'));
});
