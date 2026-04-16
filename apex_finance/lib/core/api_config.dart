/// APEX Platform — Centralized API Configuration
/// ═══════════════════════════════════════════════════════════
/// Single source of truth for the API base URL.
/// All files MUST import from here — never hardcode the URL.
///
/// Default: production API on Render.
/// Override at build/run time:
///   flutter run -d chrome --dart-define=API_BASE=http://127.0.0.1:8000
///   flutter build web --dart-define=API_BASE=https://staging.example.com
const String apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://apex-api-ootk.onrender.com',
);
