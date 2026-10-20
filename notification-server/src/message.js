export function buildMessage(id, item, token) {
  if (!id || !item.userId || item.type !== 'club_membership' ||
      !['active', 'left'].includes(item.membershipStatus)) {
    throw new Error('Unsupported notification');
  }
  return {
    token,
    notification: {title: item.title, body: item.body},
    data: {notificationId: id, userId: item.userId, type: item.type,
      referenceId: item.referenceId},
    android: {
      priority: 'high', ttl: 24 * 60 * 60 * 1000,
      notification: {channelId: 'campushub_updates', tag: id, icon: 'ic_notification'},
    },
  };
}
