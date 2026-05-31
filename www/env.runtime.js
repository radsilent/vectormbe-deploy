window.__VSS_ENV = window.__VSS_ENV || {};
// No API key required — server runs in open mode (all requests treated as admin).
window.__VSS_ENV.VECTORMBE_API_KEY = "";
// NOTE: VITE_VECTORMBE_API_URL is intentionally NOT set here.
// Dev mode (npm run dev): falls back to "/api" → Vite proxy → vectormbed on :8080.
// Tauri builds: beforeBuildCommand bakes VITE_VECTORMBE_API_URL=http://localhost:8080
// into import.meta.env at build time, which the client uses directly.
// Web deploys: set this via Cloudflare Workers env.js or at deploy time.
// window.__VSS_ENV.VITE_VECTORMBE_API_URL = "http://localhost:8080";
