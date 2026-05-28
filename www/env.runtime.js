window.__VSS_ENV = window.__VSS_ENV || {};
// No API key required — server runs in open mode (all requests treated as admin).
window.__VSS_ENV.VECTOROWL_API_KEY = "";
// NOTE: VITE_VECTOROWL_API_URL is intentionally NOT set here.
// Dev mode (npm run dev): falls back to "/api" → Vite proxy → vectorowld on :8080.
// Tauri builds: beforeBuildCommand sets VITE_VECTOROWL_API_URL=http://localhost:8080
// at build time, which is baked into import.meta.env and used directly.
// window.__VSS_ENV.VITE_VECTOROWL_API_URL = "http://localhost:8080";
