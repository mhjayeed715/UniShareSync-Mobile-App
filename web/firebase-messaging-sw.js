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

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification?.title || payload.data?.title || 'UniShareSync Notice';
  const notificationOptions = {
    body: payload.notification?.body || payload.data?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
