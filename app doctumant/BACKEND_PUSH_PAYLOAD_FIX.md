# Push Notifications — Fix Needed: Notifications Don't Show When App Is Closed

**Date:** 2026-07-13
**From:** Flutter client team
**Bug:** In-app notifications (the bell icon screen, read from the
`notifications` table) work fine. Push notifications while the app is
backgrounded or fully closed do **not** show anything on the device.

---

## Root cause (client-side diagnosis)

FCM supports two different message shapes:

1. **A message with a `notification` block** — Android's OS shows a real
   system-tray notification automatically, even if the app isn't running at
   all. No app code needs to be active for this to appear.
2. **A `data`-only message** (no `notification` block) — silent by design.
   Only your app's own running code can react to it. If the app is
   backgrounded or killed, there's no active code to show anything, so
   **nothing visibly happens** — which matches exactly what we're seeing.

Our client's `send-fcm-push` consumer code (`FcmService`) only reads
`message.data['type']` for deep-linking after a tap — it was written
assuming your function's payload includes a `notification` block for the OS
to display, plus a `data` block for us to route on tap. If `send-fcm-push`
is currently sending data-only messages, that would fully explain this bug.

## What we need

Please check the `send-fcm-push` Edge Function's call to the FCM v1 API and
confirm the request body includes **both** a `notification` and a `data`
object, e.g.:

```json
{
  "message": {
    "token": "<device token>",
    "notification": {
      "title": "New match!",
      "body": "You and Priya matched 🎉"
    },
    "data": {
      "type": "new_match",
      "match_id": "<uuid>"
    }
  }
}
```

- **`notification.title` / `notification.body`** — use the same `title`/
  `body` text you already write into the `notifications` table row for
  this event.
- **`data`** — same `type` + payload keys already documented in
  `BACKEND_PUSH_FINAL_STEPS.md` (e.g. `new_match` → `{"match_id": "..."}`)
  — this part your function may already be sending correctly, since it's
  needed for deep-linking.

If your function is currently sending `data` only (no `notification` key),
adding the `notification` object should be the entire fix — no other
changes needed on your end or ours.

## How to verify the fix

1. Send a test push to a real device with the app fully closed (swiped
   away from recents).
2. Confirm a real notification appears in the Android notification shade.
3. Tap it — confirm the app opens and navigates correctly (this part
   already works today per your case, so it should be unaffected).

Once confirmed, please let us know — we'll do the same test on our end
with a real like/match/message once a physical device is available.
