/* chatt Web Push service worker. */
const pageVisible = { visible: false };

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'VISIBILITY') {
    pageVisible.visible = !!event.data.visible;
  }
});

self.addEventListener('push', (event) => {
  // The page is open and in front of the user: the foreground socket + Dart
  // local notification already handle it — skip to avoid duplicates.
  if (pageVisible.visible) return;

  let payload = { title: 'Chatt', body: '', data: {} };
  try {
    if (event.data) payload = event.data.json();
  } catch (_) {}

  const conversationId = payload.data && payload.data.conversationId;

  event.waitUntil(
    self.registration.showNotification(payload.title || 'Chatt', {
      body: payload.body || '',
      icon: 'icons/Icon-192.png',
      badge: 'icons/Icon-192.png',
      tag: conversationId || 'chatt',
      data: payload.data || {},
    }),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const data = event.notification.data || {};
  const conversationId = data.conversationId || '';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      for (const client of list) {
        client.postMessage({ type: 'OPEN_CHAT', conversationId });
        if ('focus' in client) return client.focus();
      }
      if (clients.openWindow) {
        return clients.openWindow('/').then((windowClient) => {
          if (windowClient) {
            windowClient.postMessage({ type: 'OPEN_CHAT', conversationId });
          }
        });
      }
    }),
  );
});