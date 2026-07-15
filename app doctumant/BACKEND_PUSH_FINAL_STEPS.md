# Push Notifications — Remaining Backend Steps

**Date:** 2026-07-11
**From:** Flutter client team

The client side is fully done: the app requests permission, gets a device
token, and saves it into your `fcm_tokens` table on every sign-in. Confirmed
working against the live table.

Two things are left on your side before a push actually reaches a phone:

---

## 1. Insert a `notifications` row on each event

Nothing currently creates a row in `notifications` when a like, match,
message, missed call, report update, or subscription change happens. Add a
trigger (or equivalent) for each:

| Event | `type` to insert |
|---|---|
| Someone likes a user | `new_like` |
| Mutual match forms | `new_match` *(confirm whether your existing `create_match_on_mutual_like` trigger already does this — if not, add it here)* |
| New chat message | `new_message` |
| Missed call | `call_missed` |
| Report status changes | `report_update` |
| Subscription expiring/active | `subscription_expiring` / `subscription_active` |

Populate `actor_user_id` and the `data` jsonb so the app can deep-link:
- `new_match` → `{ "match_id": "<uuid>" }`
- `new_message` → `{ "conversation_id": "<uuid>", "message_id": "<uuid>" }`
- `profile_view` → `{ "viewer_id": "<uuid>" }`

## 2. Send the push (the actual missing piece)

An Edge Function, triggered on `INSERT` into `notifications`, that:
1. Checks the receiving user's `notification_preferences` (`push_enabled` +
   the matching per-type toggle) — skip sending if off.
2. Looks up that user's token(s) in `fcm_tokens`.
3. Calls the **Firebase Cloud Messaging HTTP v1 API** using a Firebase
   **service-account key** (Firebase console → `love-me-international`
   project → Project Settings → Service accounts → generate key). Keep this
   key server-side only — never send it to us, never put it in the app.
4. If FCM reports a token as invalid, delete it from `fcm_tokens`.

---

## One small ask: `fcm_tokens` constraint

Right now the unique constraint is on `token` alone. Please change it to
`(user_id, token)` instead — a token-alone constraint means a reused/reissued
token could silently reassign an existing row to a different user. Small
change, no client-side impact.

---

Once steps 1 and 2 are live, push notifications work end-to-end — nothing
further needed from us except testing.
