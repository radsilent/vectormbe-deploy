window.__VSS_ENV = window.__VSS_ENV || {};
// No API key required — server runs in open mode (all requests treated as admin).
window.__VSS_ENV.VECTOROWL_API_KEY = "";
// Override the Tauri-baked http://localhost:8080 so web deploys route through nginx.
window.__VSS_ENV.VITE_VECTOROWL_API_URL = "/api";
