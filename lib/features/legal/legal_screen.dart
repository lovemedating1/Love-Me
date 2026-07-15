import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/sub_page_header.dart';

/// A legal document section: a heading + body, optionally a bulleted list,
/// optionally styled as a red warning block (prohibited-content sections).
class LegalSection {
  const LegalSection(
    this.heading,
    this.body, {
    this.bullets = const [],
    this.warning = false,
    this.warningNote,
  });

  final String heading;
  final String body;
  final List<String> bullets;

  /// Renders the heading/warning note in red, matching the old app's
  /// "strictly prohibited" content-policy sections.
  final bool warning;

  /// A bold red closing line (e.g. "Violations will result in immediate
  /// account suspension...").
  final String? warningNote;
}

/// 16-19 — shared scrollable-prose scaffold for Terms / Refund / Child
/// Safety, transcribed from the old app's real published copy (see
/// `old app ss/` legal screenshots, 2026-07-11). Privacy Policy content
/// lives directly on [LegalHubScreen] (old app merges Privacy content into
/// the "Privacy & Terms" hub itself rather than a separate page).
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.title, required this.sections});

  final String title;
  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: SubPageHeader(title: title),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [for (final s in sections) _sectionCard(s)],
      ),
    );
  }

  Widget _sectionCard(LegalSection s) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: s.warning ? const Color(0xFFFFF0F0) : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (s.warning)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(
                    LucideIcons.ban,
                    color: AppColors.destructive,
                    size: 18,
                  ),
                ),
              Expanded(
                child: Text(
                  s.heading,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: s.warning
                        ? AppColors.destructive
                        : AppColors.fgLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s.body,
            style: const TextStyle(
              color: AppColors.mutedFg,
              height: 1.4,
              fontSize: 13.5,
            ),
          ),
          if (s.bullets.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final b in s.bullets)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '•  ',
                      style: TextStyle(color: AppColors.mutedFg),
                    ),
                    Expanded(
                      child: Text(
                        b,
                        style: const TextStyle(
                          color: AppColors.mutedFg,
                          height: 1.4,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (s.warningNote != null) ...[
            const SizedBox(height: 8),
            Text(
              s.warningNote!,
              style: const TextStyle(
                color: AppColors.destructive,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
          ],
        ],
      ),
    ),
  );

  // ---- Factory builders per document -------------------------------------

  static LegalScreen terms() => const LegalScreen(
    title: 'Terms & Conditions',
    sections: [
      LegalSection(
        'Age Requirement',
        'You must be at least 18 years old to use this application. If '
            'you are under 18, you must stop using this app immediately. '
            'We reserve the right to terminate accounts of users who do '
            'not meet this age requirement. By creating an account, you '
            'certify that you are at least 18 years of age. Any '
            'misrepresentation of your age may result in legal '
            'consequences and permanent account suspension.',
      ),
      LegalSection(
        'Voluntary Use',
        'By using this application, you confirm that you are doing so '
            'voluntarily and of your own free will. No one has forced, '
            'coerced, or pressured you into creating an account or using '
            'any features of this app. You acknowledge that your '
            'participation on this platform is entirely your own choice '
            'and that you may delete your account at any time without '
            'consequence.',
      ),
      LegalSection(
        'Explicit Content & Nudity Policy',
        'Sharing, requesting, or distributing nude, sexually explicit, '
            'or pornographic content is strictly prohibited on this '
            'platform. This includes but is not limited to:',
        warning: true,
        bullets: [
          'Sending nude or explicit photos, videos, or links via chat',
          'Requesting other users to share nude or sexual content',
          'Uploading explicit images as profile photos',
          'Sharing links to adult or pornographic websites',
          'Any form of sexual solicitation or harassment',
        ],
        warningNote:
            'Violations will result in immediate account suspension, '
            'permanent ban, and permanent deletion of all account data. '
            'Severe cases may be reported to law enforcement authorities.',
      ),
      LegalSection(
        'Terrorism, Violence & War Content Policy',
        'Sharing, requesting, or distributing content related to '
            'terrorism, acts of violence, war glorification, or '
            'extremist propaganda is strictly prohibited on this '
            'platform. This includes but is not limited to:',
        warning: true,
        bullets: [
          'Discussing, planning, or promoting terrorist activities or '
              'attacks',
          'Sharing extremist propaganda, recruitment material, or '
              'radicalisation content',
          'Glorifying war crimes, genocide, or acts of mass violence',
          'Distributing graphic or violent content depicting human '
              'suffering',
          'Promoting hate-based ideologies linked to terrorism or '
              'violent extremism',
        ],
        warningNote:
            'Violations will result in immediate account suspension, '
            'permanent ban, and permanent deletion of all account data. '
            'Severe cases will be reported to law enforcement '
            'authorities.',
      ),
      LegalSection(
        'Content Moderation & Chat Safety',
        'All messages sent through this platform are subject to '
            'automated content moderation. Our system detects and '
            'blocks messages containing explicit, abusive, or harmful '
            'content before they are delivered. Users who repeatedly '
            'attempt to send prohibited content will be flagged for '
            'review and may face account suspension or permanent ban.\n\n'
            'Our moderation system filters messages for:',
        bullets: [
          'Sexually explicit language and solicitation',
          'Threats, harassment, and hate speech',
          'Spam, scams, and fraudulent content',
          'Content promoting illegal activities',
          'Underage exploitation or references',
          'Terrorism, war glorification, and violent extremist content',
        ],
      ),
      LegalSection(
        'Blocking & Reporting Users',
        'You can block any user at any time. Blocked users will not be '
            'able to see your profile, send you messages, or interact '
            'with you in any way. You can also report users for '
            'violations of our community guidelines. All reports are '
            'reviewed by our moderation team and appropriate action is '
            'taken, including warnings, temporary suspensions, or '
            'permanent bans.\n\nWhen you report a user, the reported '
            'user is automatically blocked. Reports are confidential — '
            'the reported user will not know who filed the report.',
      ),
      LegalSection(
        'Account Banning & Permanent Deletion',
        'Accounts found in violation of our policies — particularly '
            'those involving sharing nude or explicit content — will be '
            'permanently banned and deleted. This includes:',
        warning: true,
        bullets: [
          'Immediate suspension of all account access',
          'Permanent deletion of profile, photos, messages, and all '
              'data',
          'IP and device-level restrictions to prevent re-registration',
          'Reporting to relevant authorities in cases of illegal '
              'content',
        ],
        warningNote:
            'Banned users may not create new accounts. Any attempt to '
            'circumvent a ban may result in further legal action.',
      ),
      LegalSection(
        'Data Safety & Privacy',
        'We take your privacy seriously. All personal data is stored '
            'securely using industry-standard encryption and security '
            'practices. Your information is never sold to third '
            'parties. We only collect data necessary to provide and '
            'improve our services, and you can request deletion of '
            'your data at any time. Your profile information, '
            'messages, and interactions are protected with '
            'end-to-end security measures. We regularly audit our '
            'systems to ensure compliance with global data protection '
            'standards. Location data is only collected with your '
            'explicit consent and is used solely for matching purposes.',
      ),
      LegalSection(
        'User Responsibility',
        'You are responsible for your interactions on this platform. '
            'Any form of harassment, hate speech, or illegal activity '
            'will result in immediate account termination. Please '
            'treat all users with respect and dignity. You agree not '
            'to share explicit, offensive, or misleading content. '
            'Users found violating these guidelines will be reported '
            'to the appropriate authorities where applicable.',
      ),
      LegalSection(
        'Intellectual Property',
        'All content you upload to this platform remains your '
            'property. However, by uploading content, you grant us a '
            'limited license to display it within the app for the '
            'purpose of providing our services. You may not copy, '
            'reproduce, or distribute other users\' content without '
            'their explicit permission.',
      ),
      LegalSection(
        '90-Day Data Retention Policy',
        'All user accounts are subject to a 90-day data retention '
            'period starting from your signup date. After 90 days, '
            'all your data — including your profile, photos, matches, '
            'messages, likes, and interactions — will be automatically '
            'and permanently deleted. You will be notified daily of '
            'your remaining days each time you log in. After expiry, '
            'you are welcome to sign up again with a fresh account. '
            'This policy exists to protect user privacy and ensure '
            'data freshness.',
      ),
      LegalSection(
        'Account Termination',
        'We reserve the right to suspend or terminate any account '
            'that violates our terms of service, engages in '
            'fraudulent activity, or poses a risk to other users. '
            'Upon account deletion, all personal data will be '
            'permanently removed from our servers within 30 days in '
            'accordance with applicable data protection laws.',
      ),
    ],
  );

  static LegalScreen refund() => const LegalScreen(
    title: 'Refund Policy',
    sections: [
      LegalSection(
        'Subscriptions',
        'Refunds for subscription purchases follow the policy of the '
            'app store you purchased through (Google Play or the App '
            'Store). We are unable to issue refunds directly for '
            'purchases made through a platform billing system — please '
            'contact that platform\'s support to request a refund.',
      ),
      LegalSection(
        'Coins & Virtual Items',
        'Coins, gifts, and other virtual items are non-refundable once '
            'purchased or used. Please review your purchase carefully '
            'before confirming.',
      ),
      LegalSection(
        'How to Request a Refund',
        'If you believe you were charged in error, contact our '
            'support team within 14 days of the purchase date with '
            'your order details. We will review each request on a '
            'case-by-case basis.',
      ),
      LegalSection(
        'Account Deletion & Refunds',
        'Deleting your account does not automatically entitle you to '
            'a refund of any remaining subscription time or unused '
            'virtual items. Refund eligibility is governed by the '
            'terms above.',
      ),
    ],
  );

  static LegalScreen _childSafetyBody() => const LegalScreen(
    title: 'Child Safety Standards',
    sections: [
      LegalSection(
        'Zero Tolerance Policy',
        'Love Me International Dating App maintains an absolute zero '
            'tolerance policy towards Child Sexual Abuse and '
            'Exploitation (CSAE), Child Sexual Abuse Material (CSAM), '
            'grooming, sextortion, trafficking, and any content or '
            'behaviour that sexualises, endangers, or harms minors in '
            'any way. Any violation will result in immediate and '
            'permanent account termination, preservation of evidence, '
            'and reporting to the National Center for Missing & '
            'Exploited Children (NCMEC) via CyberTipline and to '
            'relevant local law enforcement agencies as required by '
            'law.',
        warning: true,
      ),
      LegalSection(
        'Age Requirement & Verification',
        'All users of Love Me International Dating App must be at '
            'least 18 years old. By signing up, users certify their '
            'age. We employ identity verification (government-issued '
            'ID and selfie liveness checks) and reserve the right to '
            'request proof of age at any time. Accounts belonging to '
            'users under 18 will be immediately suspended, all data '
            'permanently deleted, and the incident reported to the '
            'appropriate authorities.',
      ),
      LegalSection(
        'In-App User Feedback & Reporting Mechanism',
        'Love Me provides an in-app reporting and feedback mechanism '
            'available on every user profile and inside every chat '
            'conversation. Users can tap the Report button to flag '
            'suspected CSAE, CSAM, grooming, or any other '
            'child-safety concern. Reports are triaged by our Trust & '
            'Safety team within 24 hours, the reported account is '
            'automatically blocked from contacting the reporter, and '
            'confirmed CSAE reports are escalated immediately to '
            'NCMEC and law enforcement. Reporter identities are kept '
            'strictly confidential.',
      ),
      LegalSection(
        'How We Address CSAM',
        'When suspected CSAM is detected — through automated '
            'scanning of uploaded photos, AI-based chat moderation, '
            'or a user report — Love Me takes the following actions:',
        bullets: [
          'The content is removed from the platform immediately',
          'The offending account is suspended and permanently banned',
          'All associated evidence (media, messages, account '
              'metadata, IP addresses, device identifiers) is '
              'preserved in a secure forensic store',
          'A CyberTipline report is filed with NCMEC in compliance '
              'with 18 U.S.C. § 2258A',
          'Local law enforcement and, where applicable, INTERPOL or '
              'equivalent international bodies are notified',
          'The user\'s IP and device are added to our '
              're-registration blocklist',
        ],
      ),
      LegalSection(
        'Prohibited Content & Behaviour',
        'The following are strictly prohibited and will be treated '
            'as serious violations:',
        warning: true,
        bullets: [
          'Any imagery, video, or media depicting the sexual abuse '
              'or exploitation of minors',
          'Sharing, distributing, storing, or soliciting child '
              'sexual abuse material (CSAM)',
          'Grooming behaviour — any attempt to build trust with a '
              'minor for sexual purposes',
          'Soliciting sexual content, images, or contact from anyone '
              'under 18',
          'Using the platform to arrange or facilitate meetings with '
              'minors for exploitative purposes',
          'Creating accounts that misrepresent age to interact with '
              'or exploit minors',
          'Sharing links to external sites containing child '
              'exploitation material',
        ],
      ),
      LegalSection(
        'Detection & Prevention',
        'We employ a multi-layered approach to detect and prevent '
            'child exploitation on our platform:',
        bullets: [
          'Automated content moderation: All messages are scanned '
              'in real-time for explicit, predatory, or grooming '
              'language patterns',
          'Image screening: Uploaded photos are reviewed against '
              'known CSAM databases',
          'User reporting: All users can report suspicious '
              'behaviour, which is reviewed promptly',
          'Identity verification: Users may be required to verify '
              'their identity and age through government-issued '
              'documents',
          'Behavioural monitoring: Suspicious account activity '
              'patterns are flagged for manual review',
        ],
      ),
      LegalSection(
        'Reporting & Law Enforcement Cooperation',
        'When CSAM or child exploitation activity is identified or '
            'reported:',
        bullets: [
          'The offending account is immediately suspended',
          'All relevant evidence (messages, media, account data, IP '
              'addresses) is preserved',
          'A report is filed with the National Center for Missing & '
              'Exploited Children (NCMEC) via CyberTipline',
          'Local and international law enforcement agencies are '
              'notified as required by law',
          'The offending user is permanently banned with no '
              'possibility of account reinstatement',
        ],
      ),
      LegalSection(
        'How to Report',
        'If you encounter any content or behaviour on Love Me '
            'International Dating App that you believe involves the '
            'sexual abuse or exploitation of a child, please take the '
            'following steps immediately:',
        bullets: [
          'In-app: Use the report button on any user\'s profile or '
              'within a chat to flag the content',
          'Email: Contact us at ${AppConstants.supportEmail} '
              'with details',
          'NCMEC CyberTipline: Report directly at report.cybertip.org',
          'Emergency: If a child is in immediate danger, contact '
              'your local emergency services (911 in the US)',
        ],
        warningNote:
            'All reports are treated with the highest priority, and '
            'reporter identities are kept strictly confidential.',
      ),
      LegalSection(
        'Child Safety Point of Contact',
        'In accordance with the Google Play Child Safety Standards '
            'policy, Love Me International Dating App has designated '
            'and published a dedicated Child Safety point of contact '
            'who is prepared to discuss our organisation\'s CSAM '
            'prevention practices and compliance with Google Play\'s '
            'Child Safety policies. This contact information is kept '
            'current in our Child Safety Standards declaration.\n\n'
            'Designated Contact: Child Safety Officer\n'
            'Organisation: The Orbit Devs (developer of Love Me '
            'International Dating App)\n'
            'Primary email: ${AppConstants.supportEmail}\n'
            'Subject line for priority routing: "CHILD SAFETY — '
            'URGENT"\n'
            'Response time: within 24 hours for CSAE reports; within '
            '72 hours for general inquiries\n'
            'Scope: CSAM prevention practices, Google Play Child '
            'Safety Standards compliance, NCMEC CyberTipline liaison, '
            'and law enforcement cooperation.\n\n'
            'This point of contact is the same contact published in '
            'our Google Play Console Child Safety Standards '
            'declaration and is kept current at all times.',
      ),
      LegalSection(
        'Legal & Regulatory Compliance',
        'Love Me complies with all applicable child safety laws and '
            'regulations, including 18 U.S.C. § 2258A (mandatory '
            'NCMEC reporting), the PROTECT Act, the EU Digital '
            'Services Act, the UK Online Safety Act 2023, Australia\'s '
            'Online Safety Act 2021, and equivalent statutes in every '
            'market where the App operates. We cooperate fully with '
            'subpoenas, preservation requests, and emergency '
            'disclosure requests from law enforcement worldwide.',
      ),
      LegalSection(
        'Our Commitment',
        'Love Me International Dating App is committed to creating a '
            'safe environment free from the exploitation of children. '
            'We continuously update our detection systems, train our '
            'moderation teams, and cooperate fully with law '
            'enforcement agencies worldwide. The safety of minors is '
            'non-negotiable, and we will pursue every available legal '
            'avenue against those who use our platform to harm '
            'children.',
      ),
    ],
  );
}

/// 16 — the "Privacy & Terms" hub screen (old app: shield title, link cards
/// to Terms & Refund, then Age/Voluntary-Use/Content-Policy sections and
/// the rest of the privacy content inline). This is the screen the
/// [RoutePaths.privacy] route resolves to — the old app doesn't have a
/// separate standalone Privacy Policy page; privacy content lives on this
/// hub alongside links out to the other 2 documents. Child Safety is a
/// separate top-level page (has its own red "Report CSAM" button + Google
/// Play compliance statement) — not linked from this hub in the old app.
class LegalHubScreen extends StatelessWidget {
  const LegalHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: const SubPageHeader(title: 'Privacy & Terms'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: const [
              Icon(LucideIcons.shield, color: AppColors.pink, size: 22),
              SizedBox(width: 8),
              Text(
                'Privacy & Terms',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Last updated: ${_lastUpdated()}',
            style: const TextStyle(color: AppColors.mutedFg, fontSize: 12),
          ),
          const SizedBox(height: 16),
          _linkCard(
            context,
            icon: LucideIcons.fileText,
            title: 'Terms & Conditions',
            subtitle: 'Read the full Terms governing your use of the App',
            route: RoutePaths.terms,
          ),
          const SizedBox(height: 10),
          _linkCard(
            context,
            icon: LucideIcons.rotateCcw,
            title: 'Refund Policy',
            subtitle: 'Learn about refunds and eligible cases',
            route: RoutePaths.refund,
          ),
          const SizedBox(height: 20),
          const _HubSection(
            title: 'Age Requirement',
            body:
                'You must be at least 18 years old to use this application. '
                'If you are under 18, you must stop using this app '
                'immediately. We reserve the right to terminate accounts of '
                'users who do not meet this age requirement. By creating an '
                'account, you certify that you are at least 18 years of '
                'age. Any misrepresentation of your age may result in '
                'legal consequences and permanent account suspension.',
            highlight: '18 years old',
          ),
          const _HubSection(
            title: 'Voluntary Use',
            body:
                'By using this application, you confirm that you are doing '
                'so voluntarily and of your own free will. No one has '
                'forced, coerced, or pressured you into creating an account '
                'or using any features of this app. You acknowledge that '
                'your participation on this platform is entirely your own '
                'choice and that you may delete your account at any time '
                'without consequence.',
          ),
          const SizedBox(height: 8),
          _hubGoTo(
            context,
            'For our full content and safety policy, see the '
            'Terms & Conditions above.',
          ),
          const SizedBox(height: 8),
          _hubGoTo(
            context,
            'For Child Safety Standards and how to report a concern, see '
            'the Child Safety page in Settings.',
          ),
        ],
      ),
    );
  }

  Widget _hubGoTo(BuildContext context, String text) => Text(
    text,
    style: const TextStyle(color: AppColors.mutedFg, fontSize: 12.5),
  );

  String _lastUpdated() {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final now = DateTime.now();
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  Widget _linkCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) => Material(
    color: const Color(0xFFFCE4EE),
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(route),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.pink, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.mutedFg,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              color: AppColors.pink,
              size: 18,
            ),
          ],
        ),
      ),
    ),
  );
}

class _HubSection extends StatelessWidget {
  const _HubSection({required this.title, required this.body, this.highlight});

  final String title;
  final String body;
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),
          highlight == null
              ? Text(
                  body,
                  style: const TextStyle(color: AppColors.mutedFg, height: 1.4),
                )
              : _highlighted(body, highlight!),
          const SizedBox(height: 8),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _highlighted(String text, String phrase) {
    final idx = text.indexOf(phrase);
    if (idx == -1) {
      return Text(
        text,
        style: const TextStyle(color: AppColors.mutedFg, height: 1.4),
      );
    }
    return Text.rich(
      TextSpan(
        style: const TextStyle(color: AppColors.mutedFg, height: 1.4),
        children: [
          TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: phrase,
            style: const TextStyle(
              color: AppColors.destructive,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: text.substring(idx + phrase.length)),
        ],
      ),
    );
  }
}

/// 20 — Child Safety Standards page. Own top-level screen (not nested under
/// the Privacy & Terms hub in the old app): a solid-red "Report CSAM / Child
/// Safety Concern" button, the app/developer identity line, and the
/// published Google Play Child Safety Standards compliance statement box —
/// all ahead of the same [LegalScreen.terms]-style section list used for
/// the rest of the document's real content.
class ChildSafetyScreen extends StatelessWidget {
  const ChildSafetyScreen({super.key});

  static const _playListingUrl =
      'play.google.com/store/apps/details?id=com.loveme.intldating';

  @override
  Widget build(BuildContext context) {
    final body = LegalScreen._childSafetyBody();
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: const SubPageHeader(title: 'Child Safety Standards'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _reportCsam(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.destructive,
                minimumSize: const Size.fromHeight(50),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(LucideIcons.flag, size: 18),
              label: const Text(
                'Report CSAM / Child Safety Concern',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Love Me International Dating App — Published Standards Against '
            'Child Sexual Abuse & Exploitation (CSAE)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Applies to: Love Me International Dating App (developer: The '
            'Orbit Devs). Last updated: 5th June 2026',
            style: TextStyle(color: AppColors.mutedFg, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F0),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.destructive.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GOOGLE PLAY CHILD SAFETY STANDARDS — COMPLIANCE '
                  'STATEMENT',
                  style: TextStyle(
                    color: AppColors.destructive,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      color: AppColors.fgLight,
                      height: 1.4,
                      fontSize: 13.5,
                    ),
                    children: [
                      const TextSpan(
                        text:
                            'Love Me International Dating App '
                            '(developer: ',
                      ),
                      const TextSpan(
                        text: 'The Orbit Devs',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const TextSpan(text: ', Google Play listing: '),
                      TextSpan(
                        text: _playListingUrl,
                        style: const TextStyle(
                          color: AppColors.pink,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const TextSpan(
                        text:
                            ') explicitly prohibits Child Sexual Abuse '
                            'and Exploitation (CSAE), including the '
                            'creation, possession, distribution, '
                            'solicitation, or facilitation of Child Sexual '
                            'Abuse Material (CSAM), grooming, sextortion, '
                            'and the trafficking or sexualisation of '
                            'minors in any form. These published standards '
                            'are functional, publicly accessible at this '
                            'URL, reference the app and developer name as '
                            'displayed on the Google Play store listing, '
                            'and are enforced globally without exception in '
                            'compliance with the Google Play Child Safety '
                            'Standards policy.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _reportCsam(context),
                  icon: const Icon(LucideIcons.shieldAlert, size: 16),
                  label: const Text('Child Safety Statement'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.destructive,
                    side: const BorderSide(color: AppColors.destructive),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(RoutePaths.privacy),
                  icon: const Icon(LucideIcons.fileText, size: 16),
                  label: const Text('Privacy Policy'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.pink,
                    side: const BorderSide(color: AppColors.pink),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          for (final s in body.sections) body._sectionCard(s),
        ],
      ),
    );
  }

  void _reportCsam(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report CSAM / Child Safety Concern'),
        content: Text(
          'If a child is in immediate danger, contact your local emergency '
          'services first.\n\n'
          'Email ${AppConstants.supportEmail} with details, or '
          'report directly to NCMEC at report.cybertip.org. All reports are '
          'confidential and reviewed within 24 hours.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
