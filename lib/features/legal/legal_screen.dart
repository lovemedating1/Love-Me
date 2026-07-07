import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// A legal document section.
class LegalSection {
  const LegalSection(this.heading, this.body);
  final String heading;
  final String body;
}

/// 16-19 — shared scrollable-prose scaffold for Privacy / Terms / Refund /
/// Child Safety. Placeholder copy for the front-end phase.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.title, required this.sections});

  final String title;
  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(title, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text('Last updated: July 2026', style: theme.textTheme.bodySmall),
          const SizedBox(height: 20),
          for (final s in sections) ...[
            Text(s.heading, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(s.body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 20),
          ],
          Text('Questions? Contact ${AppConstants.supportEmail}',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ---- Factory builders per document -------------------------------------

  static const _lorem =
      'This is placeholder legal copy for the front-end build. The final, '
      'lawyer-reviewed text will replace it before launch. It describes the '
      'relevant terms in clear, plain language for our users.';

  static LegalScreen privacy() => const LegalScreen(
        title: 'Privacy Policy',
        sections: [
          LegalSection('Data we collect',
              'Account details, profile info, photos, location, and usage. $_lorem'),
          LegalSection('How we use it',
              'To power matching, safety, and support. $_lorem'),
          LegalSection('Sharing', 'We never sell your data. $_lorem'),
          LegalSection('Retention',
              'Data is kept while your account is active and purged after 90 days of inactivity. $_lorem'),
          LegalSection('Your rights',
              'Access, correct, export, or delete your data anytime. $_lorem'),
        ],
      );

  static LegalScreen terms() => const LegalScreen(
        title: 'Terms of Service',
        sections: [
          LegalSection('Eligibility', 'You must be 18 or older. $_lorem'),
          LegalSection('Acceptable use',
              'No harassment, spam, or illegal content. $_lorem'),
          LegalSection('Subscriptions',
              'Premium renews automatically until cancelled. $_lorem'),
          LegalSection('Termination',
              'We may suspend accounts that violate these terms. $_lorem'),
        ],
      );

  static LegalScreen refund() => const LegalScreen(
        title: 'Refund Policy',
        sections: [
          LegalSection('Subscriptions',
              'Refunds follow the app store you purchased through. $_lorem'),
          LegalSection('Coins & gifts',
              'Virtual items are non-refundable once used. $_lorem'),
          LegalSection('How to request',
              'Contact support within 14 days of purchase. $_lorem'),
        ],
      );

  static LegalScreen childSafety() => const LegalScreen(
        title: 'Child Safety',
        sections: [
          LegalSection('Zero tolerance',
              'We prohibit any content that exploits or endangers minors (CSAE). $_lorem'),
          LegalSection('Reporting',
              'Report concerns instantly in-app; we notify authorities. $_lorem'),
          LegalSection('Age verification',
              'We use AI + manual review to keep the platform adults-only. $_lorem'),
        ],
      );
}
