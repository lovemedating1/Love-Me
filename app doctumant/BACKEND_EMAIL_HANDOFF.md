# Love Me International — Email / Transactional Mail: Backend Requirements

**Date:** 2026-07-11
**From:** Flutter client team
**Purpose:** Every place in the app where a user sends, receives, or is
promised an email — so the backend team can build/confirm the mail
infrastructure needed to make all of them real. This is a full audit of the
current codebase, not a guess — every item below cites the exact file.

**Project ref:** `tamlbnmihdcjiptbezjm`

---

## Current state in one sentence

The app today sends **zero custom emails**. The only emails a user can
receive are Supabase's own default, unbranded auth emails (and even the
sign-up confirmation one is currently switched off project-wide — see 1.1).
Everything else — password reset deep-linking, notification-preference
emails, a support inbox, a child-safety inbox — is either half-wired or a
promise made in the UI/legal text with no backend behind it yet.

---

## 1. Auth emails

### 1.1 Sign-up confirmation email — currently OFF entirely

`auth_controller.dart` calls plain `_client.auth.signUp(email, password)` —
no custom code, this would be Supabase's own default confirmation email.
**However, "Confirm email" is currently disabled in the Supabase dashboard**
(done 2026-07-06, documented in developer.log and CLAUDE.md) because turning
it on breaks the sign-up flow: `signUp()` returns no session until the user
confirms, so the client's `profiles` row insert — which needs `auth.uid()` —
fails with an RLS error.

**Need:** Before production launch, re-enable "Confirm email" and coordinate
with us — the client's sign-up flow will need to move the `profiles` insert
to happen *after* confirmation instead of immediately after `signUp()`
(e.g. via a trigger on `auth.users` confirmation, or the client retrying the
insert once a session exists). Until this is fixed, **no user ever receives
a real confirmation email today.**

### 1.2 Email verification screen — UI exists, not wired to anything real

`email_verified_screen.dart` is a 6-digit OTP entry screen, explicitly
commented in the code as **"UI ONLY — not wired to a real verification
backend."** Both the "resend code" and "submit code" actions currently just
show a "not available yet" message — there is no backend endpoint to call
yet for either.

**Need:** Decide whether email verification should be:
- **(a)** Supabase's own confirmation-link flow (simplest — no OTP needed,
  just a clickable link in the email that confirms `auth.users`), or
- **(b)** A real 6-digit OTP flow, which needs a `send-verification-code` /
  `verify-code` Edge Function pair plus a place to store/expire the code.

If (a), the OTP screen in the app can likely be simplified or removed. If
(b), we need the two endpoints above. **Please advise which approach you
want** — this changes what the client needs to build next.

### 1.3 Password reset — partially working today

`requestPasswordReset()` calls Supabase's real `resetPasswordForEmail()` —
**this part works today** and does send Supabase's default reset email.
The completion screen (`reset_password_screen.dart`) also really works via
`auth.updateUser(password:)`.

**The gap:** the emailed reset link is supposed to deep-link the user back
into the app to `reset_password_screen.dart`, but **no deep-link handler
exists in the app yet** (no custom URL scheme / app link registered), so
today a user who taps the link in the email has nowhere real to land inside
the app. This is partly a client task (registering `loveme://` or an
App Link/Universal Link) but needs the **redirect URL configured in the
Supabase Auth dashboard** to point at whatever scheme we register — please
flag if you want to coordinate on the exact scheme/URL before we build it.

---

## 2. Notification-preference-driven emails

The `notification_preferences` table already has two relevant columns:
`email_enabled` (documented as the "Master Email Switch") and
`marketing_notifications`. The client already reads/writes both.

**The gap:** nothing anywhere — client or backend — currently sends an
email based on these flags. They exist as columns with no behavior behind
them. **Note also:** the in-app Settings screen currently only exposes a
single "Background Alerts" toggle to the user (a deliberate UI simplification
to match the old app) — it does not currently expose a separate "email
notifications" switch in the UI, even though the column exists. If real
email notifications get built, flag whether you want us to add a visible
toggle for it, or whether `email_enabled` should just default to a sensible
value without a dedicated UI control.

**Need (if this is in scope for now — see priority note at the end):**
- A transactional email pipeline: an Edge Function (e.g.
  `send-transactional-email`) triggered off the same events already listed
  in the push-notifications doc (new like, new match, new message, missed
  call, report update, subscription expiring/active) — checking
  `email_enabled`/`marketing_notifications` before sending, the same way the
  push dispatcher checks `push_enabled`.
- `email_send_log` / `email_send_state` tables to track delivery/avoid
  duplicate sends.
- `suppressed_emails` + `email_unsubscribe_tokens` tables and a
  `handle-email-unsubscribe` endpoint — standard unsubscribe-link handling
  so marketing emails are compliant (CAN-SPAM / similar regulations).
- `process-email-queue` — a scheduled job if you want emails queued and
  sent in batches rather than immediately.

---

## 3. Support & contact emails (promises made in the UI — need to be real inboxes)

These aren't backend *code* — they're **email addresses already shown to
users in the app**, so someone needs to make sure these inboxes actually
exist, are monitored, and (for the child-safety one) meet the response-time
commitments already printed in the app's legal text.

| Address | Where it's shown | Status / commitment |
|---|---|---|
| `support@loveme-app.com` | Settings → Help & Support "Contact Us" | Plain display text today, not even a clickable link yet |
| `lovemedatingappchildsafety@gmail.com` | Child Safety legal page (3 places, including the in-app "Report CSAM" dialog) | **Publicly committed 24-hour response for CSAE reports, 72-hour for general child-safety issues** — this is a Google Play Child Safety Standards compliance commitment already printed in the app. This inbox needs to be real and actively monitored regardless of any other email work. |

**Need:**
1. Confirm both inboxes exist and are actively monitored, with the
   child-safety one specifically staffed to meet the 24h/72h SLA already
   promised in the app.
2. (Small client-side follow-up, flagging here for completeness) neither
   address is currently a tappable `mailto:` link in the app — we can fix
   that on our end once you confirm the addresses are final.

---

## 4. Transactional receipts / payment confirmation emails

The subscription screen has an "Upload Order Receipt Screenshot" button and
a "Download Receipt (PDF)" button in Settings — both currently disabled,
waiting on backend (payment verification / PDF generation — covered in the
main backend requirements doc under payments, not repeated here).

**This is a genuine gap, not yet spec'd anywhere:** once real payments exist
(see the main `BACKEND_REQUIREMENTS_HANDOFF.md`, §1.2), there is currently
**no plan for a post-payment confirmation/receipt email**. If you want users
to get an email receipt after a successful subscription payment, that needs
to be added to the payments Edge Function's scope — please confirm if this
should be included.

---

## 5. What's explicitly NOT needed

- Safety report submission is fully in-app/database-backed — no email is
  involved in that flow at all, no action needed there.
- The "Remember email after inactivity logout" toggle in Settings only
  stores the email locally on the device (SharedPreferences) to pre-fill
  the login field — it never gets sent anywhere. No backend involvement.

---

## Suggested priority

1. **Fix the "Confirm email" toggle bug (1.1)** — this is the most urgent:
   right now literally no user gets a real sign-up confirmation email, and
   re-enabling it requires a coordinated client change, so let's schedule
   this together rather than flip the toggle unannounced.
2. **Decide the email-verification approach (1.2)** — blocks whether we
   build/keep the OTP screen or simplify it away.
3. **Wire up the password-reset deep link (1.3)** — smaller, mostly a
   client task, but needs your redirect-URL config to match.
4. **Confirm the two support inboxes are real and monitored (§3)** — no
   engineering work, just an ops confirmation, but time-sensitive given the
   child-safety SLA is already publicly promised.
5. Everything else (§2 preference-driven emails, §4 receipts) — lower
   urgency, nice-to-have polish rather than launch blockers. Flag if you'd
   like these prioritized differently.

Happy to hop on a call to walk through the deep-link/redirect-URL
coordination in particular, since that one needs both sides in sync.
