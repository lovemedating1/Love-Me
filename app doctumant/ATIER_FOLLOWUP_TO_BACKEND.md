# Love Me International — A-TIER Follow-up: Response to Your 2026-07-14 Reply

**To:** Backend team
**From:** Flutter (client) team
**Date:** 2026-07-14
**Project ref:** `tamlbnmihdcjiptbezjm`
**Re:** Your `Safety.Trust Backend.md` reply. Thanks for the fast, thorough
turnaround — most of this is genuinely done. One real gap found on our side
while re-verifying against the actual client code, plus answers to your 3
open questions.

---

## 0. TL;DR

| # | Item | Our verdict |
|---|---|---|
| 1 | Reports | ✅ Confirmed — matches client exactly, no action needed |
| 2 | Blocked users — table/RLS | ✅ Confirmed |
| 2b | Blocked users — **filtering** | 🔴 **Won't take effect as shipped — see §1 below** |
| 3 | Account deletion | ✅ Confirmed, **one client bug found + fixed** (see §2) |
| 3a | Orphaned conversations vs. hard-delete | **Decision: leave orphaned** (see §3) |
| 3b | Chat-media storage cleanup | **Decision: yes, please fix now** (see §4) |
| 4 | Quota RPCs | ✅ Confirmed, `record_profile_view` shape change is fine, client already coded for it |
| 5 | Image moderation | ✅ Acknowledged as infra-only, no action needed from either side yet |

---

## 1. 🔴 Blocked-users filtering won't actually take effect — please re-target it

Your `031_blocked_users_filtering.sql` patches `get_discover_profiles()`,
`get_matches()`, and `get_chat_list()` (the RPCs from `013_rpc_functions.sql`).

**Problem: the Flutter client never calls any of those three RPCs.** We
checked the actual repository code just now to be sure before writing this:

- `SupabaseProfileRepository.discoverFeed()` — plain `SELECT` against
  `profiles` directly (`lib/shared/data/repositories.dart`), not `rpc('get_discover_profiles')`.
- `SupabaseMatchRepository.myMatches()` — plain `SELECT` against `matches`
  directly (`lib/shared/data/match_repository.dart`), not `rpc('get_matches')`.
- `SupabaseConversationRepository.conversationsForMe()` — plain `SELECT`
  against `conversations`/`messages`/`profiles` directly
  (`lib/shared/data/conversation_repository.dart`), not `rpc('get_chat_list')`.

This was a deliberate client-side decision made earlier in the project
(before blocking existed) — the client's own code comments say things like
"no server-side discovery/ranking RPC yet" — so it queries tables directly
instead of via those RPCs. We didn't know those 3 RPCs existed server-side
until your reply; they must predate this doc thread.

**Net effect: right now, a user can block someone and still see them in
Discover, still match with them, and still see them in the chat list.** The
filtering you built is correct and well-designed, it's just attached to
functions that aren't in this client's call path.

**Our ask: please move the filter to the tables themselves** (RLS policy or
a view) rather than the 3 RPCs, so it applies no matter how the client
queries — this is more robust anyway (works for any future client code path,
not just today's). Concretely, something like: a policy or `WHERE NOT
EXISTS (...)` clause against `blocked_users` (both directions) applied
directly to whatever `profiles`/`matches`/`conversations` selects return to
an authenticated user. If that's awkward for some reason (e.g.
`profiles` needs to stay universally readable for non-Discover purposes),
an alternative is a Postgres **view** (`profiles_unblocked_for_me` or
similar) that the client could switch to instead — but that *would* require
a small client change (swap the table name in 3 call sites), so we'd rather
you confirm which approach before we touch anything. Let us know which is
easier on your end and we'll adjust if a client-side change ends up being
part of the fix.

---

## 2. Account deletion — bug found and fixed on our side

Your §3.3 point 1 (anonymize `sender_id` to `NULL`) is the right call and we
agree with the reasoning. While re-verifying your reply against our code we
found: `lib/shared/models/message.dart`'s `ChatMessage.senderId` was a
**non-nullable `String`**, so `ChatMessage.fromJson()` would have **thrown**
the first time it hit a real row with `sender_id = null` — a hard crash
opening any conversation with an orphaned message, not a graceful
degradation.

**Already fixed, merged, verified:**
- `senderId` is now `String?`.
- `ChatMessage.isMine()` treats a `null` sender as "not mine" (safe default —
  renders on the left side of the chat like any other-party message).
- Chat bubbles now show a small "Deleted user" italic label above any
  message with a `null` sender, so it's not confused with an ordinary
  message from the (still-present) other participant.
- `flutter analyze` clean, no new issues.

No further client work needed here — **§3 is fully closed once `034` runs.**

---

## 3. Decision: leave conversations orphaned (your §3.3 point 2)

Confirmed — go with what you already built. Keep the surviving participant's
message history and conversation intact; no hard-delete. This matches the
message-anonymization approach and needs no further client change (the
"Deleted user" label from §2 above already covers the UI side of this).

---

## 4. Decision: please do fix chat-media storage cleanup on deletion

We'd like the follow-up you flagged (§3, "one gap") done rather than
deferred — please enumerate the deleting user's conversations *before*
deleting them (per your own note: "would need to enumerate the user's
conversations before they're deleted, not after") and clean up the objects
they own in `chat-images`/`chat-files`/`chat-file-thumbs`/`voice-messages`
for those conversations. `avatars` cleanup is already covered per your
reply — no change needed there.

If there's a reason this is meaningfully more expensive or risky than it
sounds (e.g. shared media where the other participant also needs their copy
to survive — unlikely given media is per-message, not per-conversation, but
flagging in case), let us know and we can revisit the priority.

---

## 5. Everything else — no action needed

- §1 (reports), §2 (blocked_users schema/RLS), §4 (quota RPCs) — all
  confirmed matching spec, client already coded against them, will start
  working the moment `029`/`030`/`032` run. No client changes.
- §5 (image moderation) — agreed this is "infrastructure ready, not
  enforced" until a classifier provider is picked. No urgency beyond
  "sooner is better," as already stated in our original doc. We have no
  provider preference (AWS Rekognition / Google Cloud Vision SafeSearch /
  Sightengine all fine) — your call.
- `record_profile_view` return-type change (`void` → `json`) — no issue,
  client was already coded against the `json`/`{"allowed": ...}` contract
  from the start (see `BACKEND_ATIER_HANDOFF.md` §4.4), so this "just
  works" once `032` runs.

---

## 6. Summary of what we need from you next

1. Re-target the blocked-users filter from the 3 RPCs to the underlying
   tables/RLS (§1) — this is the one real blocker before A-TIER can be
   called done.
2. Build the chat-media storage cleanup in `delete-account` (§4).
3. Everything else in your reply is accepted as-is — proceed to deploy
   `029`–`032` and `034` to the live project whenever ready; `033`
   (moderation) can follow once a classifier is chosen, no rush.

Once §1 and §4 land, we'll re-verify end-to-end and confirm A-TIER closed
on our side.
