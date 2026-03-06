importScripts("https://www.gstatic.com/firebasejs/8.10.0/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/8.10.0/firebase-messaging.js");

// Initialize Firebase App
firebase.initializeApp({
    apiKey: "AIzaSyB18d1-OXMqGMr80YTJ4VBuER_CxLga-zg",
    authDomain: "leave-management-app-f07b8.firebaseapp.com",
    projectId: "leave-management-app-f07b8",
    storageBucket: "leave-management-app-f07b8.firebasestorage.app",
    messagingSenderId: "476708106662",
    appId: "1:476708106662:web:40db61972509e618e69f67"
});

// Initialize Config
const messaging = firebase.messaging();

// Optional: specific background handler
messaging.onBackgroundMessage((payload) => {
    console.log('[firebase-messaging-sw.js] Received background message ', payload);
    // Customize notification here
    const notificationTitle = payload.notification.title;
    const notificationOptions = {
        body: payload.notification.body,
        icon: '/icons/Icon-192.png',
        data: payload.data // Pass data for click handler
    };

    self.registration.showNotification(notificationTitle, notificationOptions);
});

self.addEventListener('notificationclick', function (event) {
    console.log('[firebase-messaging-sw.js] Notification click Received.', event.notification.data);
    event.notification.close();

    const data = event.notification.data || {};
    const type = data.type || '';
    const id = data.relatedId || '';
    const year = data.academicYearId || '';

    // Construct URL with parameters for deep linking
    let targetPath = '/';
    if (type && id) {
        targetPath = `/?type=${type}&id=${id}&year=${year}`;
    }

    event.waitUntil(
        clients.matchAll({ type: 'window' }).then(windowClients => {
            // Check if there is already a window/tab open with the target URL
            for (var i = 0; i < windowClients.length; i++) {
                var client = windowClients[i];
                // Navigate open client to the deep link
                if ('navigate' in client) {
                    return client.navigate(targetPath).then(c => c.focus());
                }
            }
            // If icon not found or no clients, open new window
            if (clients.openWindow) {
                return clients.openWindow(targetPath);
            }
        })
    );
});
