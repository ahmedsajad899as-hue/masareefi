const CACHE_NAME = 'masareefi-v5';
const PRECACHE = [];  // Never precache — avoids stale HTML

// Install — activate immediately, no precaching
self.addEventListener('install', e => {
  e.waitUntil(self.skipWaiting());
});

// Activate — clean ALL old caches
self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.map(k => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

// Fetch — network first for EVERYTHING (no caching causes issues with stale HTML/JS)
self.addEventListener('fetch', e => {
  // Skip non-GET and API calls
  if (e.request.method !== 'GET' || e.request.url.includes('/api/')) return;

  // Always fetch fresh — no SW caching
  e.respondWith(fetch(e.request).catch(() => new Response('', { status: 503 })));
});

