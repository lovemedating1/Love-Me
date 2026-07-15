# Love Me International — Push Notifications: Backend Requirements

**Date:** 2026-07-11
**From:** Flutter client team
**Purpose:** Everything the backend (Supabase) side needs to build so push
notifications can actually reach a user's phone. The client half is already
built and waiting — this doc is scoped to just that remaining backend piece
so it can be picked up on its own, independent of any other backend work.

**Project ref:** `tamlbnmihdcjiptbezjm`

---

## Where things stand today

**Client side — done (2026-07-11):**
- A real Firebase project (`love-me-international`) exists, with an Android
  app registered under the app's real package name (`com.loveme.international`).
- The Flutter app requests notification permission, obtains a device's FCM
  token, listens for token refreshes, and handles a notification tap whether
  the app is in the foreground, background, or fully closed — routing the
  user to the right screen based on the notification's type.
- The one thing the client is missing is somewhere to send that device
  token to — because that table doesn't exist yet (see below).

**Backend side — what exists today:**
- `notifications` table (live, migration_004): `id`, `user_id`,
  `actor_user_id`, `type` (enum), `title`, `body`, `data` (jsonb, deep-link
  payload), `is_read`, `read_at`, `created_at`. RLS: a user can `SELECT`/
  `UPDATE`/`DELETE` only their own rows. **No `INSERT` policy exists for the
  client — this is intentional and correct; nothing below should change that.**
- `notification_preferences` table (live): one row per user with 8 boolean
  toggles (`push_enabled`, `email_enabled`, `like_notifications`,
  `match_notifications`, `message_notifications`, `call_notifications`,
  `profile_view_notifications`, `marketing_notifications`). Client already
  reads/writes this in Settings.
- `notification_queue` table (live): reserved for backend/service-role use
  only. Flutter never touches it and never will.
- **Nothing currently inserts a row into `notifications`.** A user only sees
  a notification today if one is manually inserted by hand. There is no
  trigger, no Edge Function, and no push delivery of any kind yet.

So there are two separate gaps to close, and either can be done first:

---

## Gap 1 — Something has to actually create notification rows

Right now, no event in the app (a like, a match, a message, a missed call,
etc.) causes a row to appear in `notifications`. Need trigger functions (or
equivalent) that insert a row when:

| Event | Notification `type` to insert |
|---|---|
| Someone likes a user | `new_like` |
| A mutual match forms | `new_match` *(the `create_match_on_mutual_like` trigger already exists and creates the match + conversation — please confirm whether it also inserts a `new_match` notification row today; if not, add it here)* |
| A new chat message arrives | `new_message` |
| A call goes unanswered | `call_missed` |
| A safety report's status changes | `report_update` |
| A subscription is about to expire / becomes active | `subscription_expiring` / `subscription_active` |

Each insert should populate `actor_user_id` (who triggered it) and `data`
(jsonb) with whatever the client needs to deep-link correctly — see
"Deep-link payload shape" below for the exact keys the client already
expects per type.

**Deep-link payload shape (client already parses these exact keys):**
- `new_match` → `data: { "match_id": "<uuid>" }`
- `new_message` → `data: { "conversation_id": "<uuid>", "message_id": "<uuid>" }`
- `profile_view` → `data: { "viewer_id": "<uuid>" }`
- Other types can have an empty/minimal `data` object — the client routes
  purely off `type` for those (e.g. `new_like` → Likes tab, `report_update`
  → Safety Reports).

---

## Gap 2 — Actually sending a push to the device (the missing piece)

This is the part that gets a notification to actually appear on a user's
phone, even when the app is closed.

### 2.1 New table: `fcm_tokens`

```
fcm_tokens
  id          uuid (pk)
  user_id     uuid (fk -> auth.users, not null)
  token       text (not null)  -- the FCM device token
  platform    text             -- 'android' | 'ios' | 'web'
  updated_at  timestamptz (not null, default now())
```

**RLS:** a user can `INSERT`/`UPDATE`/`SELECT`/`DELETE` only rows where
`user_id = auth.uid()`. No public read.

A sensible uniqueness constraint: one row per `(user_id, token)` — a user
may have multiple devices, and a token can be replaced on refresh (upsert on
conflict is the simplest pattern for the client to call).

**The client is ready for this today** — the moment this table exists,
we'll wire the already-built `FcmService.deviceToken` value into a write to
this table on login and on token refresh. No other client change is needed
for this part.

### 2.2 A dispatcher that sends the actual push

An Edge Function (recommended trigger: on `INSERT` into `notifications`,
either via a Postgres trigger calling the function or a `pg_net`/webhook
call) that:

1. Looks up the `notifications` row that was just inserted.
2. Checks the receiving user's `notification_preferences` — respect
   `push_enabled` (master switch) and the matching per-type toggle (e.g.
   don't push a `new_like` notification if `like_notifications` is off).
3. Looks up all of that user's rows in `fcm_tokens`.
4. Calls the **Firebase Cloud Messaging HTTP v1 API** for each token, using
   a Firebase **service-account key** (JSON) as credentials.
5. Optionally removes/flags a token from `fcm_tokens` if FCM reports it as
   invalid/unregistered (keeps the table clean over time).

**Where to get the service-account key:** Firebase console → the
`love-me-international` project → Project Settings → **Service accounts**
tab → "Generate new private key". This produces a JSON file.

**Handling the key:** this key must live only in Supabase (as an Edge
Function secret/environment variable), **never** in the Flutter app, never
in this repo, never in client-visible config. It's the credential that lets
a server impersonate the Firebase project to send pushes — treat it like a
password.

### 2.3 (Optional, nice-to-have) Realtime on `notifications`

Right now the in-app notifications screen only refreshes via pull-to-refresh
— there's no realtime subscription. If Realtime is enabled on the
`notifications` table (`public:notifications`), the client can update the
in-app list live when a push arrives while the app is open, instead of
waiting for a manual refresh. Not required for push to work — just a nicer
in-app experience. Flag if you'd like this included in the same pass or
deferred.

---

## Summary — what to build, in order

1. **`fcm_tokens` table** + RLS (small, self-contained, unlocks everything else).
2. **Trigger functions** that insert `notifications` rows for each event
   listed in Gap 1 (if not already partially done via `create_match_on_mutual_like`).
3. **Dispatcher Edge Function** that reads a new `notifications` row, checks
   preferences, and calls the FCM v1 API using the service-account key.
4. *(Optional)* Realtime on `notifications` for a live in-app feed.

Once step 1 lands, tell us and we'll immediately wire the token write —
that part takes minutes on the client side, it's just waiting on the table.
Steps 2–3 are what's needed before any push actually reaches a phone.
