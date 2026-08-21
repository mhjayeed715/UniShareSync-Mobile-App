importScripts('https://www.gstatic.com/firebasejs/9.23.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.23.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyCMKXTk2EuoCqTWS6A6DTQy4FQ0LiyIT34",
  authDomain: "unisharesync-mobile-app.firebaseapp.com",
  projectId: "unisharesync-mobile-app",
  storageBucket: "unisharesync-mobile-app.firebasestorage.app",
  messagingSenderId: "940839736695",
  appId: "1:940839736695:web:ab391063b3e4448ab33d72"
});

const messaging = firebase.messaging();

// Firebase Web SDK automatically displays notifications for messages containing a top-level `notification` payload.
// We only invoke `showNotification` manually if the message is a data-only payload to avoid duplicate popups.
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message:', payload);
  if (!payload.notification && payload.data) {
    const notificationTitle = payload.data.title || 'UniShareSync Notice';
    const iconUrl = new URL('icons/Icon-192.png', self.location.origin).href;
    const notificationOptions = {
      body: payload.data.body || '',
      icon: iconUrl,
      // Note: Do NOT set colored images as `badge` on WebPush for Android, as Android forces an alpha-mask causing a black box.
      tag: payload.data.type ? `${payload.data.type}_${payload.data.id ?? Date.now()}` : 'unisharesync-notice',
      data: payload.data,
      renotify: true
    };

    return self.registration.showNotification(notificationTitle, notificationOptions);
  }
});

// Handle notification click to open/focus the UniShareSync web app
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const targetUrl = new URL('/', self.location.origin).href;

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      for (let i = 0; i < windowClients.length; i++) {
        const client = windowClients[i];
        if (client.url.startsWith(self.location.origin) && 'focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
    })
  );
});

