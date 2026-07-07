/// Supabase connection details, injected at build/run time via `--dart-define`.
///
/// Never hardcode the anon/publishable key as a fallback in source control —
/// pass it explicitly:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class SupabaseConfig {
  SupabaseConfig._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}
