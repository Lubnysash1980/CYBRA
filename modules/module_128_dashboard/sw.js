// Service Worker для PWA — кешує статику, /api/state завжди свіжий
const CACHE = 'cybra-v1';
const STATIC = ['/', '/manifest.json'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(STATIC)));
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(keys =>
    Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))));
});

self.addEventListener('fetch', e => {
  const url = new URL(e.request.url);
  // API — завжди з мережі
  if (url.pathname.startsWith('/api/')) {
    e.respondWith(fetch(e.request));
    return;
  }
  // статика — cache-first
  e.respondWith(
    caches.match(e.request).then(r => r || fetch(e.request))
  );
});
