# LoveMe — Supabase API Reference (Auth & Profile Layer)

Scope: the 6 tables live as of migrations `001_auth_profiles.sql` + `002_auth_profiles_rls.sql`.
Everything else in the full backend spec (matches, messages, payments, etc.) is **not yet built** — do not integrate against those tables yet.

## Connection

```
Project ref:     tamlbnmihdcjiptbezjm
REST base:       https://tamlbnmihdcjiptbezjm.supabase.co/rest/v1
Auth base:       https://tamlbnmihdcjiptbezjm.supabase.co/auth/v1
Publishable key: sb_publishable_h9pOdpCGZ2wq0KiqTy2vHA_FUkHi-tW
```

Use the publishable key as `anonKey` in `Supabase.initialize(...)`. Never embed the `service_role` / `secret` key in the Flutter app — it bypasses Row Level Security.

Every request needs:
```
apikey: <publishable key>
Authorization: Bearer <user's access_token>
```

## Auth

Standard Supabase Auth flow (email/password). Sign up / sign in via `supabase_flutter`'s `supabase.auth.signUp(...)` / `signInWithPassword(...)`. On success you get a `session` with `access_token` — the client library attaches it to subsequent requests automatically.

## Tables

### `profiles`
One row per user, created by the client right after sign-up.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK, auto-generated |
| `user_id` | uuid | FK → `auth.users.id`, unique, required on insert |
| `name` | text | required (defaults to `''`) |
| `gender` | text | nullable; if set, must be `'male'` or `'female'` |
| `orientation` | text | nullable |
| `interested_in` | text | nullable |
| `birthday` | date | nullable — **no `age` column**; compute age from `birthday` client-side |
| `marital_status` | text | nullable |
| `relationship_goal` | text | nullable |
| `hobbies` | text[] | defaults to `{}` |
| `city`, `country` | text | required (default `''`) |
| `location_lat`, `location_lng` | double | nullable, validated range |
| `location_accuracy_m` | double | nullable |
| `distance_preference_km` | integer | default `50` |
| `photo_url` | text | nullable — single photo only, no gallery table yet |
| `is_verified` | boolean | default `false` |
| `photo_verification` | jsonb | default `{}` |
| `ringtone` | text | required (default `''`) |
| `profile_complete` | boolean | default `false` — client should flip this once onboarding form is done |
| `profiles_viewed_count` | integer | default `0` |
| `profiles_viewed_reset_at` | timestamptz | default `now()` |
| `is_suspended`, `suspension_reason`, `suspended_at`, `policy_violations` | — | trust & safety fields, read-only from client perspective |
| `notify_safety_*` (4 bool columns) | boolean | default `true` |
| `is_premium`, `premium_until` | — | read-only from client, set by payment backend (not built yet) |
| `created_at`, `updated_at` | timestamptz | default `now()` |

**RLS:**
- `SELECT` — open to everyone (`public`), including anonymous.
- `INSERT` / `UPDATE` / `DELETE` — only allowed where `auth.uid() = user_id`.

```
GET  /rest/v1/profiles?select=*&user_id=eq.<uuid>
POST /rest/v1/profiles         body: { user_id, name, city, country, ... }
PATCH /rest/v1/profiles?user_id=eq.<uuid>   body: { name: "Jane" }
```

### `user_roles`
Read-only from the client. Role assignment happens on the backend (admin/moderator grants).

| Column | Type |
|---|---|
| `id` | uuid |
| `user_id` | uuid, FK → `auth.users.id` |
| `role` | enum `app_role`: `admin` \| `moderator` \| `user` |
| `created_at` | timestamptz |

**RLS:** `SELECT` only, scoped to `auth.uid() = user_id`. No insert/update/delete policy exists — the client cannot self-assign roles.

```
GET /rest/v1/user_roles?select=role&user_id=eq.<uuid>
```

### `active_sessions`
Tracks concurrent device sessions per user.

| Column | Type | Notes |
|---|---|---|
| `user_id` | uuid | FK → `auth.users.id`, part of composite PK |
| `session_token` | uuid | part of composite PK — generate client-side per login |
| `device_label` | text | nullable, e.g. `"iPhone 15"` |
| `user_agent` | text | nullable |
| `last_seen_at` | timestamptz | default `now()` — update periodically (heartbeat) |
| `created_at` | timestamptz | default `now()` |

**RLS:** full CRUD, scoped to `auth.uid() = user_id`.

```
POST  /rest/v1/active_sessions   body: { user_id, session_token, device_label }
PATCH /rest/v1/active_sessions?user_id=eq.<uuid>&session_token=eq.<uuid>   body: { last_seen_at: "now()" }
```

### `push_tokens` / `fcm_tokens`
Two separate token tables. `fcm_tokens` is the one Flutter should use (Firebase Cloud Messaging). `push_tokens` is a generic/legacy table — only use it if a specific feature calls for it.

**`fcm_tokens`**

| Column | Type |
|---|---|
| `id` | uuid |
| `user_id` | uuid, FK → `auth.users.id` |
| `token` | text, unique |
| `created_at` | timestamptz, default `now()` |

**`push_tokens`**

| Column | Type |
|---|---|
| `id` | uuid |
| `user_id` | uuid, FK → `auth.users.id` |
| `token` | text, unique |
| `platform` | text, nullable |
| `created_at` | timestamptz, default `now()` |
| `updated_at` | timestamptz, nullable |

**RLS (both tables):** single `ALL` policy scoped to `auth.uid() = user_id` — covers select/insert/update/delete.

```
POST /rest/v1/fcm_tokens   body: { user_id, token }
```
Register the FCM token right after `firebase_messaging` returns it; re-register on token refresh.

### `user_presence`
One row per user, `user_id` is the primary key (no separate `id`).

| Column | Type |
|---|---|
| `user_id` | uuid, PK, FK → `auth.users.id` |
| `is_online` | boolean, default `false` |
| `last_seen` | timestamptz, default `now()` |

**RLS:**
- `SELECT` — any authenticated user (`true`) — needed so other users can see someone's online status.
- `INSERT` / `UPDATE` / `DELETE` — scoped to `auth.uid() = user_id`.

```
POST  /rest/v1/user_presence   body: { user_id, is_online: true }
PATCH /rest/v1/user_presence?user_id=eq.<uuid>   body: { is_online: false, last_seen: "now()" }
```

## Not yet available

The full backend spec documents 30 tables (matches, likes, messages, calls, subscriptions, storage buckets, edge functions for payments/moderation, etc.). None of that exists yet — only the 6 tables above are live. Check back before building against anything else.