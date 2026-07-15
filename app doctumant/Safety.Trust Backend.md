# Love Me International — A-TIER Safety/Trust Backend: Response

**To:** Flutter (client) team
**From:** Backend team
**Date:** 2026-07-14
**Project ref:** `tamlbnmihdcjiptbezjm`
**Status:** 🟢 All 5 items built. Not yet deployed to the live project — see §7.

Responding point-by-point to your 2026-07-14 A-TIER requirements doc. New
migrations added: `029`–`034`. Two new Edge Functions: `delete-account`,
`moderate-image`.

---

## 0. TL;DR — status against your table

| # | Item | Status |
|---|---|---|
| 1 | `reports` table + RLS | ✅ **Done** — `029_reports.sql`, matches your schema/RLS exactly |
| 2 | `blocked_users` table + RLS + Discover/matching filtering | ✅ **Done** — `030_blocked_users.sql` + `031_blocked_users_filtering.sql` (server-side, see §3) |
| 3 | `delete-account` Edge Function | ✅ **Done** — `functions/delete-account/`, see §4 for the two design calls we made |
| 4 | Quota RPCs | ✅ **Done** — `032_quota_rpcs.sql`, all 4 functions match your signatures |
| 5 | `moderate-image` + `moderation_status` + gating | 🟡 **Schema/plumbing done, classifier stubbed** — `033_photo_moderation.sql` + `functions/moderate-image/`, see §5 |

**Run migrations `029` through `034` before re-testing.** Nothing has been
pushed to the live project yet — see §7 for what we need from you before we do.

---

## 1. §1 — reports: done, no deviations

`029_reports.sql` matches your spec exactly: same columns, same `reason`
check constraint (all 6 values), same `status` values, same RLS (insert-own,
select-own, no client update/delete). Your `SupabaseSafetyRepository`
should start working immediately once this migration runs — no client
change needed.

---

## 2. §2 — blocked_users: done, plus we picked an answer to your open question

`030_blocked_users.sql` matches your schema/RLS exactly (insert/select/
delete-own, unique `(blocker_user_id, blocked_user_id)`).

**§2.5 (your open question) — we went with server-side filtering, not
client-side.** Rationale is the same as yours: a modified client could
otherwise just ignore `blockedUsersProvider` and keep seeing/matching with
someone it blocked, which defeats the point of a safety feature.
`031_blocked_users_filtering.sql` updates the three RPCs that already exist
(`get_discover_profiles`, `get_matches`, `get_chat_list`, all from
`013_rpc_functions.sql`) to exclude any pair with a `blocked_users` row in
**either** direction — so it doesn't matter who blocked whom, both parties
stop seeing each other everywhere: Discover, active matches, and the chat
list.

**No client change needed for this to take effect** — same query shape,
just fewer rows come back. `blockedUsersProvider`'s existing empty-list
fallback and the standalone Blocked Users screen are unaffected.

---

## 3. §3 — delete-account: done, two design calls made (flagged, not silent)

`functions/delete-account/index.ts` follows your spec's call flow exactly:
resolves `auth.uid()` from the JWT via an anon client, then does everything
else with the service-role client, ending with
`supabase.auth.admin.deleteUser(userId)`.

**Your doc flagged two "your call" decisions in §3.3 — here's what we picked:**

1. **Messages sent by the deleted user: anonymized, not deleted.**
   `sender_id` is set to `NULL` rather than removing the row, so the other
   participant's conversation history stays intact (matches your "keep the
   other participant's history intact" framing). This required a schema
   change: `messages.sender_id` was `not null ... on delete cascade`, which
   can't hold a `NULL` — `034_messages_sender_id_nullable.sql` relaxes it
   to nullable with `on delete set null`. **Please handle `sender_id ==
   null` in the chat UI** (e.g. render as "Deleted user" instead of trying
   to look up a profile that no longer exists) — this is now a reachable
   state for any conversation where the other person deleted their account.
2. **Conversations are left orphaned, not deleted**, for the same reason —
   consistent with #1, the surviving participant keeps their message
   history and can still open the conversation (it'll just have no live
   match/other-user profile behind it). If you'd rather we hard-delete
   conversations instead, tell us and we'll flip this — it's a one-line
   change in the Edge Function, not a schema migration, since
   `conversations` isn't touched today.

**Every step in the teardown aborts the whole request on its first
failure** rather than silently continuing past a broken step — so a 500
from this function means nothing was left half-deleted in a way you can't
retry; the client's existing "non-2xx → generic retry messaging" handling
is the right behavior as-is, no change needed there.

**Order implemented:** storage (avatars only — see below) → `profile_photos`
→ messages (anonymize) → `message_reads`/`message_reactions`/`call_logs` →
`matches`/`likes`/`passes`/`profile_views` → `notifications`/
`notification_preferences`/`fcm_tokens`/`push_tokens` → `active_sessions`/
`user_presence` → `reports`/`blocked_users`/`content_flags` →
`user_roles`/`profiles` → `auth.users`.

**One gap, flagged honestly:** we only clean up the `avatars` bucket
(scoped by `auth_user_id` path prefix, per `016_storage_policies.sql`).
The 4 chat buckets (`chat-images`/`chat-files`/`chat-file-thumbs`/
`voice-messages`) are scoped by `conversation_id`, not `user_id` — there's
no user-prefix listing we can do to find "this user's chat media" without
scanning every conversation the user was ever part of. Since we're leaving
conversations orphaned anyway (see #2 above), we left chat-bucket objects
in place too, consistent with that call. If you want those actually
cleaned up, that's a bigger follow-up (would need to enumerate the user's
conversations before they're deleted, not after) — flag it if it matters
for your storage-cost/privacy bar.

---

## 4. §4 — quota RPCs: done, one breaking-ish change to flag

`032_quota_rpcs.sql` adds `can_send_like()`, `get_like_quota()`, and
`get_view_quota()` exactly per your spec (50/24h likes, 50/calendar-month
views, premium = unlimited via `{"remaining": null}`).

**Heads up on `record_profile_view`:** this RPC already existed
(`013_rpc_functions.sql`) as a `void`-returning function with just the
5-minute duplicate-view dedup, no quota check. We replaced it with your
`json`-returning, quota-checked version — **same function name and
argument**, but the return shape changed from nothing to
`{"allowed": true|false}`. Since your doc says the client already "prefers
the RPC, but falls back to the old direct best-effort insert if the RPC
doesn't exist," and the client is coded against the `json` contract, this
should just start working once `032` runs — but flagging the signature
change explicitly in case any client code was calling this RPC and
ignoring the return value in a way that assumed `void`.

The 5-minute dedup window from the original RPC is preserved (a
rapid-repeat view within 5 minutes returns `{"allowed": true}` without
inserting a new row or counting against quota).

---

## 5. §5 — image moderation: schema and gating are real, classifier is stubbed

**What's actually live once `033` runs:**
- `profile_photos.moderation_status` column, backfilled to `'approved'`
  for every existing row (so nothing currently live disappears), defaulting
  to `'pending'` for new rows going forward — exactly as you specified.
- **§5.5 (your open question) — we went with "hide until approved,"** but
  with one adjustment we need to flag: a photo can still be **inserted**
  as primary regardless of moderation status (so first-photo-upload UX is
  unchanged — your client inserts `profile_photos` directly with
  `is_primary: true` on first upload, per
  `PROFILE_PHOTOS_INTEGRATION_GUIDE.md`, and isn't coded to poll/retry, so
  blocking that insert would break onboarding for every new user). What's
  actually gated is **promotion**: `set_primary_profile_photo` (and the
  auto-promote-on-delete trigger from `017`) now refuse to make an
  already-existing non-primary photo primary unless it's `approved`. In
  practice: your first photo is visible immediately like today and its
  badge updates in place once moderation runs; only *switching* primary to
  a different gallery photo requires that photo to already be approved.
  **No client change needed** — this matches the badge-only UX your
  `PhotoModerationStatus` enum already describes.

**What's stubbed:** `functions/moderate-image/index.ts` exists, is
correctly wired (fetches the photo row, would call a classifier, updates
`moderation_status`, logs a `content_flags` row and sends a "Photo
rejected" notification on reject), but its `classifyImage()` function is a
placeholder that **always returns approved**. We haven't picked an NSFW/
content-safety provider yet (AWS Rekognition vs. Google Cloud Vision
SafeSearch vs. Sightengine, your doc left this to us) — that's a real
follow-up, not "done." Swapping in a real provider only touches that one
function body, nothing else.

**Also not yet wired:** the trigger that's supposed to call
`moderate-image` automatically on every `profile_photos` insert (your
doc's recommended pg_net-webhook approach, "can't be bypassed by a modified
client"). We held off on this until the classifier is real — wiring the
trigger today would just auto-approve everything, which isn't meaningfully
different from not having moderation at all yet, and we didn't want to
create a false sense that moderation is enforced. Function can be invoked
manually today (`{"photo_id": "<uuid>"}`) for testing.

**Recommendation:** treat this whole item as "infrastructure ready,
enforcement not live" until we come back with a provider choice — same
framing as the media-system doc's original moderation section.

---

## 6. Deviations from your spec, summarized

Only two, both already covered above, repeated here for visibility:

1. **§4.4 `record_profile_view`** — signature/name unchanged, return type
   changed from `void` to `json` (it wasn't `void` in a way anything relied
   on before, but flagging since this required `drop function` +
   `create function` rather than a plain `create or replace`, which
   Postgres doesn't allow across a return-type change).
2. **§5.5 primary-photo gating** — gate applies to *promotion*, not
   *insertion*, to avoid breaking first-photo-upload UX. See §5 above.

Everything else matches your spec's schema/RLS/wire-shape as written.

---

## 7. What we need from you

1. **Nothing blocking** — every item degrades to today's behavior until
   its migration/function ships, per your own doc's framing, and that held
   up on our end too.
2. Decide whether chat-bucket storage cleanup on account deletion (§3, the
   one flagged gap) is worth a follow-up — not urgent, just flagging the
   cost/privacy tradeoff of orphaned chat media.
3. Tell us if you'd rather `delete-account` hard-delete conversations
   instead of leaving them orphaned (§3, easy to flip).
4. No urgency on moderation (§5) beyond "sooner is better," per your own
   doc — we'll come back once we've picked a classifier provider.
5. Confirm the chat UI handles `messages.sender_id == null` gracefully
   (§3) — this is a new reachable state as of `034`.

---

## 8. Migrations and functions added this round

- `029_reports.sql` — reports table + RLS
- `030_blocked_users.sql` — blocked_users table + RLS
- `031_blocked_users_filtering.sql` — server-side block filtering in
  `get_discover_profiles`/`get_matches`/`get_chat_list`
- `032_quota_rpcs.sql` — `can_send_like`, `get_like_quota`,
  `record_profile_view` (replaced), `get_view_quota`
- `033_photo_moderation.sql` — `moderation_status` column + promotion
  gating (`set_primary_profile_photo`, `sync_primary_profile_photo`,
  `promote_primary_profile_photo_on_delete`, all `create or replace`)
- `034_messages_sender_id_nullable.sql` — relaxes `messages.sender_id` to
  nullable, companion to `delete-account`
- `functions/delete-account/index.ts` — account teardown Edge Function
- `functions/moderate-image/index.ts` — photo moderation Edge Function
  (classifier stubbed pending provider choice)