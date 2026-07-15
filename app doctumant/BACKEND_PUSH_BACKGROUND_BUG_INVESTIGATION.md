# Push Notifications — Background/Killed-App Bug: Client Fix Applied

**Date:** 2026-07-13
**From:** Flutter client team
**Re:** Your reply ruling out the FCM payload shape as the cause.

Thanks for checking the live `send-fcm-push` code and confirming the
`notification` + `data` shape was already correct — that saved us chasing
the wrong thing. You flagged three candidates; we found and fixed a real gap
in candidate #2 (Android notification channel) before asking you to spend
time pulling logs for a retest that might have just re-confirmed the same
likely-broken client config.

## What we found

The app never explicitly created an Android notification channel, and the
manifest never told FCM which channel to use
(`com.google.firebase.messaging.default_notification_channel_id` was
missing). On Android 8+, every notification needs a channel — without an
explicit one, Android auto-creates a default channel whose importance isn't
guaranteed to be high enough to show as a heads-up notification, especially
with the app backgrounded or killed. This is a plausible, and very common,
cause of exactly the symptom reported: the payload arrives, but nothing
visibly surfaces.

## What we changed

- Added `flutter_local_notifications` and create an explicit
  **HIGH-importance** channel (`loveme_default_channel`) at app startup.
- Registered that channel ID in `AndroidManifest.xml` via
  `default_notification_channel_id`, so FCM's `notification`-block messages
  route through it instead of Android's auto-created fallback.
- Also fixed a related, smaller gap: previously, a push arriving while the
  app was in the foreground showed nothing at all (Android suppresses the
  system banner for foregrounded apps by design) — now we show one
  ourselves via the same channel, so foreground pushes are visible too.

## What we still need from you

Please go ahead with the retest you proposed — send a real push with the
app **fully closed** and give us the approximate timestamp. If the channel
fix was the actual cause, it should now show up. If it still doesn't, we'll
want the same log pull you described (did the `notifications` row get
created, did `dispatch_notification_push` fire, what did `send-fcm-push`
actually return) to rule in/out candidates #1 and #3 from your list.

We'll do our own real-device test with the app closed once we have a build
with this fix installed, and report back either way — no more guessing on
our end either.
