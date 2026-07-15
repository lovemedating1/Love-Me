/// Supabase connection details, injected at build/run time via `--dart-define`.
///
/// Never hardcode the anon/publishable key as a fallback in source control —
/// pass it explicitly:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class SupabaseConfig {
  SupabaseConfig._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Where a Supabase auth email's link (sign-up confirmation, password
  /// reset) sends the user back to. Must match the Android manifest's
  /// intent-filter (`android/app/src/main/AndroidManifest.xml`) and be
  /// registered as the Redirect URL in the Supabase Auth dashboard — see
  /// `app doctumant/BACKEND_CONFIRM_EMAIL_HANDOFF.md`.
  static const emailRedirectUrl = 'lovemeinternational://login-callback';
}
