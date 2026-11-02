importScripts("https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js");

// Inisialisasi Firebase di Service Worker
firebase.initializeApp({
  apiKey: "true",
  projectId: "true",
  messagingSenderId: "true",
  appId: "true",
});

const messaging = firebase.messaging();

// Tangani notifikasi saat tab browser di-minimize / berada di background
messaging.onBackgroundMessage(function (payload) {
  console.log("[firebase-messaging-sw.js] Notifikasi background:", payload);
  const notificationTitle = payload.notification ? payload.notification.title : "Notifikasi Baru";
  const notificationOptions = {
    body: payload.notification ? payload.notification.body : "",
    icon: "/icons/Icon-192.png",
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});