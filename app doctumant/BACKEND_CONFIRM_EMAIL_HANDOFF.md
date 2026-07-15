# Sign-Up Confirmation Email — Re-enable Request

**Date:** 2026-07-13
**From:** Flutter client team
**Purpose:** Turn on real sign-up confirmation emails. This is the one
remaining item from `BACKEND_EMAIL_HANDOFF.md` §1.1–1.2. We've decided on
the simplest approach (link-based, no OTP code) and are ready to make our
side of the change — we need two things from you first.

**Project ref:** `tamlbnmihdcjiptbezjm`

---

## Current situation

"Confirm email" is disabled in the Supabase Auth dashboard (turned off
2026-07-06) because enabling it broke sign-up: `signUp()` returns no
session until the user confirms, and our client was inserting the
`profiles` row immediately after `signUp()`, which needs `auth.uid()` —
so the insert failed with an RLS error while confirmation was pending.

Because it's off, **no user has ever received a real confirmation email**
— the client's fake 6-digit code screen was standing in for it, and we're
now removing that screen since it never actually verified anything.

## What we're switching to

Simple, standard flow: user signs up → Supabase sends its default
confirmation email → user taps the link in the email → it opens the app
(or a web page that redirects to the app) → account is confirmed → app
creates the `profiles` row now that a real session exists.

## What we need from you

### 1. Confirm the sequencing before you flip the toggle

We're moving our `profiles` insert to happen **after** confirmation instead
of immediately after `signUp()`. Please confirm: once "Confirm email" is
on, does the auth session become available to the client automatically
the moment the user confirms (e.g. via `onAuthStateChange` firing once
they return to the app), or do we need a trigger on `auth.users` (e.g. on
`email_confirmed_at` being set) to do something server-side first? We
believe the client-side approach works with Supabase's standard behavior,
but wanted to confirm before you flip the switch, since re-enabling it in
the dashboard takes effect immediately for all new sign-ups.

### 2. Register this exact redirect URL on your side

We've already registered the scheme client-side:

```
lovemeinternational://login-callback
```

- Added as an Android intent-filter (`android/app/src/main/AndroidManifest.xml`)
  so tapping the link in the email reopens the app directly.
- Passed explicitly as `emailRedirectTo` on both `signUp()` and the
  resend-confirmation call, so it doesn't only rely on dashboard config.
- **Please set this as the Redirect URL** in Supabase Auth dashboard → URL
  Configuration (Authentication → URL Configuration → Redirect URLs — add
  it to the allow-list, since Supabase rejects a redirect that isn't
  registered there).

### 3. Timing

Please don't flip "Confirm email" on until we confirm our client-side
change (moving the `profiles` insert) is deployed — otherwise every new
sign-up between your toggle and our fix ships will hit the same RLS error
this was originally disabled to avoid. We'll ping you when our side is
ready; then it's just a dashboard toggle on your end.

---

Once this is live: real users get a real confirmation email, tap the link,
land back in the app, and their profile gets created — no code to enter,
no fake screen, matches the sign-up flow's actual technical shape.
