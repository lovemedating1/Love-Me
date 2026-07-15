import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Thrown when the `send-email` Edge Function reports a failure (missing
/// fields, or SMTP not configured server-side — see
/// `app doctumant/BACKEND_EMAIL_HANDOFF.md`'s reply doc).
class SendEmailException implements Exception {
  const SendEmailException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Wraps the live `send-email` Edge Function (generic mailer, confirmed
/// deployed 2026-07-13 — `verify_jwt` is on, so this must go through
/// `functions.invoke` rather than a raw HTTP call). Not tied to any DB
/// trigger — an email only goes out when this is called.
class SupportEmailRepository {
  const SupportEmailRepository();

  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  Future<void> sendSupportMessage({
    required String to,
    required String subject,
    required String body,
  }) async {
    final response = await _client.functions.invoke(
      'send-email',
      body: {'to': to, 'subject': subject, 'text': body},
    );
    if (response.status != 200) {
      throw SendEmailException(
        (response.data is Map ? response.data['error'] as String? : null) ??
            'Could not send your message — please try again later.',
      );
    }
  }
}

final supportEmailRepositoryProvider = Provider<SupportEmailRepository>(
  (ref) => const SupportEmailRepository(),
);
