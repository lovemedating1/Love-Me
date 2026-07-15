# Love Me International — Email: Everything Backend Needs To Do

**Date:** 2026-07-13
**From:** Flutter client team
**Supersedes:** `BACKEND_EMAIL_HANDOFF.md` (2026-07-11) and
`BACKEND_CONFIRM_EMAIL_HANDOFF.md` (2026-07-13) — this single doc has the
current, up-to-date ask for everything email-related. Please work from this
one; the two older docs are now historical record only.

**Project ref:** `tamlbnmihdcjiptbezjm`

---

## Status in one sentence

Since the last doc, you deployed a generic `send-email` function and we
wired it into a real "Contact Support" feature — that part works today. Auth
emails (sign-up confirmation, password reset deep link) are still broken and
are the main ask in this doc.

---

## What already works — no action needed

- **Contact Support**: Settings → Help & Support → "Send us a message" calls
  your live `send-email` Edge Function and really sends. Confirmed working.
- **Password reset (partially)**: `resetPasswordForEmail()` sends Supabase's
  default reset email and the in-app reset screen works — but see the
  deep-link gap below.

---

## 1. Sign-up confirmation email — the main ask

### Current situation

"Confirm email" is disabled in your Supabase Auth dashboard (turned off
2026-07-06) because turning it on previously broke sign-up: `signUp()`
returns no session until the user confirms, and our client was inserting the
`profiles` row immediately after `signUp()` — which needs `auth.uid()`, so
it failed with an RLS error while confirmation was pending.

Because it's off, **no user has ever received a real confirmation email**.
We had a fake 6-digit code screen standing in for verification — it's now
removed. We're switching to the simplest standard flow: sign up → Supabase
sends its default confirmation email → user taps the link → app reopens →
account confirmed → app creates the profile row now that a session exists.

### What we've already done on our side (client is ready)

- Removed the fake OTP screen; replaced it with a "Check Your Email" screen
  (resend button, no code entry).
- Fixed the sign-up code so the `profiles` row gets created at the right
  time whether a session comes back immediately (today) or only after
  confirmation (once you flip the toggle) — same code path handles both,
  so there's no extra client deploy needed when you make the change.
- Registered a deep link so tapping the emailed link reopens the app:
  ```
  lovemeinternational://login-callback
  ```
  This is wired into the Android app and passed explicitly as
  `emailRedirectTo` on the sign-up and resend calls.

### What we need from you

1. **Add `lovemeinternational://login-callback` to your Redirect URLs
   allow-list** — Supabase Auth dashboard → Authentication → URL
   Configuration → Redirect URLs. Supabase rejects a redirect that isn't on
   this list, so this must happen before the toggle flip does anything
   useful.
2. **Confirm the sequencing**: once "Confirm email" is on, does the client
   get the real session automatically via `onAuthStateChange` the moment the
   user taps the link and returns to the app? Or is there a server-side step
   (e.g. a trigger on `auth.users.email_confirmed_at`) we should know about
   first? We believe standard Supabase behavior just works here, but want
   your confirmation before you flip it.
3. **Timing — please wait for our go-ahead** before flipping "Confirm
   email" on. Our client fix is written and tested, but flipping the toggle
   before it's actually deployed to users would reproduce the original bug
   for anyone signing up in that window. We'll tell you when it's live.

---

## 2. Password reset — deep-link gap

`requestPasswordReset()` and the reset-completion screen both work today.
The one gap: the emailed reset link has nowhere to land — no deep link was
registered for it (separate from the sign-up one above, since the reset
flow is a different Supabase redirect).

**Need:** Once the sign-up deep link above is confirmed working, we'll
register a second one for password reset and let you know the exact scheme
so you can add it to the same Redirect URLs list. Flagging now so it's on
your radar; not urgent yet.

---

## 3. Support inboxes — ops confirmation, not engineering

These addresses are already shown to users in the app. Please confirm both
are real, monitored mailboxes:

| Address | Where shown | Note |
|---|---|---|
| `support@loveme-app.com` | Settings → Help & Support | Now has a real "Send us a message" form behind it (see above) — please make sure this inbox is actually monitored. |
| `lovemedatingappchildsafety@gmail.com` | Child Safety legal pages (3 places) | **Publicly committed 24h response for CSAE reports, 72h for general issues** — a Google Play Child Safety Standards compliance commitment already printed in the app. Needs to be real and staffed regardless of anything else in this doc. |

---

## 4. Lower priority — flag if you want these, not needed for launch

- **Notification-preference-driven emails**: `notification_preferences.
  email_enabled`/`marketing_notifications` columns exist but nothing sends
  email off them. Would need a `send-transactional-email`-style trigger
  pipeline (same events as push notifications) + unsubscribe handling
  (`suppressed_emails`, `email_unsubscribe_tokens`). Not built, not asked
  for yet — say the word if you want this scoped.
- **Post-payment receipt emails**: no plan exists yet for emailing a
  receipt after a successful subscription payment. Flag if wanted once
  payments are being built.

---

## Priority order

1. **Sign-up confirmation** (§1) — the real blocker right now, no user gets
   a real confirmation email until this is done.
2. **Confirm support inboxes are monitored** (§3) — no engineering work,
   just ops confirmation, but the child-safety SLA is already live/public.
3. **Password reset deep link** (§2) — smaller, follow-up once §1 is done.
4. Everything in §4 — nice-to-have, not blocking.

Happy to hop on a call for the redirect-URL/sequencing coordination in §1 —
that's the one part that needs both sides in sync before flipping anything.
