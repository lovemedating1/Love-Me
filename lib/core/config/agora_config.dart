/// Agora (voice/video calling) connection details, injected at build/run time
/// via `--dart-define` — never hardcoded in source control.
///
///   flutter run --dart-define=AGORA_APP_ID=...
///
/// The **App ID** is safe to ship in a client (it is not a secret). The Agora
/// **App Certificate**, by contrast, is a secret and must live ONLY on the
/// server — it is used server-side (a Supabase Edge Function) to mint the
/// short-lived RTC token the client joins a channel with. The client never
/// sees the certificate. See [AgoraConfig.tokenEdgeFunction].
class AgoraConfig {
  AgoraConfig._();

  /// Agora project App ID (public — safe in the client).
  static const appId = String.fromEnvironment('AGORA_APP_ID');

  /// Name of the Supabase Edge Function that returns a short-lived RTC token
  /// for a given channel + uid. Called via `supabase.functions.invoke`.
  ///
  /// The backend must build this function (see BACKEND_CALLS_HANDOFF.md §3).
  static const tokenEdgeFunction = 'get-agora-token';

  /// Whether the app was built with a real App ID. When false, calling is
  /// disabled and the UI shows a "calling not configured" message instead of
  /// crashing on a join with an empty App ID.
  static bool get isConfigured => appId.isNotEmpty;
}
