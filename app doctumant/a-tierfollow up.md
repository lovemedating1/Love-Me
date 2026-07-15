# Love Me International — A-TIER Follow-up: Backend Reply

**To:** Flutter (client) team
**From:** Backend team
**Date:** 2026-07-14
**Project ref:** `tamlbnmihdcjiptbezjm`
**Re:** Your `A-TIER Follow-up` doc. Thanks for catching the RPC-vs-actual-
query-path gap and for the `sender_id` nullability fix on your side — both
real findings. §1 fixed and deployed. §4 has a real conflict with what we
already agreed in §3 of the original reply; flagging it back to you rather
than silently building it or silently skipping it.

---

## 0. TL;DR

| # | Item | Status |
|---|---|---|
| 1 | Blocked-users filtering re-targeted to actual query paths | ✅ **Done and deployed** — `035_blocked_users_table_level_gating.sql` |
| 2 | `sender_id` client-side crash fix | ✅ Acknowledged, thanks |
| 3 | Orphaned conversations | ✅ Confirmed, no change |
| 4 | Chat-media storage cleanup | 🔴 **Conflict found — see §2, need your call before we build anything** |
| 5 | Image moderation | ✅ No action either side, unchanged |

---

## 1. §1 — blocked-users filtering: fixed, matches/conversations gated directly, Discover needs one client change

Good catch, and thanks for actually checking the repo instead of taking our
RPC-based reply at face value — you were right, and it would have shipped
broken otherwise.

We went with **table-level RLS**, not a client-facing RPC, split two ways
depending on what each table actually is:

**`matches` and `conversations` — fixed with zero client change.** Both
already had owner-scoped SELECT policies (`auth.uid() = user1_id/user2_id`,
or the equivalent join through `matches` for `conversations`) — a row in
either table is only ever meaningful to its two specific parties, so we
added a `blocked_users` exclusion (either direction) directly into those
existing policies. `035_blocked_users_table_level_gating.sql`,
already deployed. **`SupabaseMatchRepository.myMatches()` and
`SupabaseConversationRepository.conversationsForMe()` will now honor blocks
automatically** — no client change, nothing to swap, it just starts
filtering. Please re-verify on your end since we can't run your Flutter
code to confirm end-to-end ourselves.

**`profiles` / Discover — needs the one client change you flagged as
likely.** We deliberately did **not** filter the base `profiles` table's
own SELECT policy, because it's intentionally open (`using (true)`) for
legitimate non-Discover reasons — a blocked user's own profile page, your
Blocked Users screen listing their name/photo, anything that navigates to
a specific profile by id. Blanket-filtering that policy would silently
return empty/missing data in those places instead of the row you expect,
which reads as a data bug, not a feature.

Instead we added a view, `public.profiles_discoverable`, that mirrors
`get_discover_profiles()`'s existing exclusion logic exactly (self,
suspended, already-liked, already-passed, already-matched) plus the same
either-direction `blocked_users` exclusion:

```sql
select * from public.profiles_discoverable
-- same shape as `profiles`, pre-filtered for the calling user
```

It's `security_invoker = true`, so it runs under the querying user's own
RLS grants — behaves like querying `profiles` directly, just pre-filtered.
Granted to `authenticated`. **The one thing we need from you: swap
`SupabaseProfileRepository.discoverFeed()`'s table name from `profiles` to
`profiles_discoverable`** — same columns, same select shape, just a
different source table. That's the only client change needed for blocking
to be fully closed.

---

## 2. §4 — chat-media storage cleanup: conflicts with what we already agreed in §3, need your call

Your own doc flagged this as a possible issue and called it "unlikely" —
we think it's real, so flagging before building anything rather than
guessing at which side of the tradeoff you'd pick.

**The conflict:** §3.3 of our original reply (which you confirmed in your
§3, "leave orphaned") anonymizes the deleted user's messages
(`sender_id = null`) specifically so the *conversation history stays
intact* for the surviving participant — text, images, videos, voice notes,
all of it, still there, just attributed to "Deleted user."

But `image`/`video`/`audio` messages aren't really their text — the
content **is** the media file at `media_url`/`thumbnail_url`, which lives
in `chat-images`/`chat-files`/`chat-file-thumbs`/`voice-messages`. If we
delete those storage objects on account deletion, the message *row*
survives (per §3) but renders as a broken image/video/audio icon — which
is arguably worse than deleting the message outright, since the client's
existing "Deleted user" label design implies the content is still there to
look at, just unattributed. For text messages there's no conflict at all;
this is specifically an image/video/voice-note problem.

We did **not** implement the cleanup — chat-bucket objects are unchanged
from our original reply, still left in place, exactly as before. Two ways
to resolve this, your call:

1. **Keep §3 as agreed, drop the storage-cleanup ask.** Deleted users'
   media stays in the surviving participant's history, consistent with
   "history stays intact" applying to media too, not just text. Storage
   cost is the tradeoff — orphaned media accumulates over time with no
   cleanup path.
2. **Cleanup wins, and the "Deleted user" message shows as an explicit
   removed-media placeholder** (something like your existing
   `is_deleted`/soft-delete rendering, reused for this case) instead of a
   broken image. This needs a small client change (recognize "media
   message from a null-sender AND the object is gone" — though note the
   client can't actually distinguish "object deleted because owner's
   account was deleted" from "object deleted for some other reason"
   without a new signal, so this would likely need a new boolean/flag we
   add to the row, not something inferable purely from `sender_id = null`).

We lean toward #1 (do nothing further, which is also the zero-risk/
zero-new-work option) given the "history intact" framing you already
confirmed, but we're not going to unilaterally decide this reverses part
of what you just signed off on — tell us which one and we'll build
whichever storage behavior you pick. If you want #2, we'll also need to
scope the new-flag piece as an actual client+backend change, not just a
storage-deletion loop.

---

## 3. Everything else — confirmed, no action

- §2 (`sender_id` nullable model fix) — good catch on your side, thanks for
  closing that before it hit a real orphaned message in production.
- §3 (leave conversations orphaned) — confirmed, unchanged from our
  original reply.
- §5 (moderation, no client preference on provider) — noted, we'll pick
  one when we get to it, no urgency either side.
- `record_profile_view` return-type change — confirmed no issue on either
  side, already covered in our original reply.

---

## 4. What we need from you next

1. Swap `discoverFeed()` to query `profiles_discoverable` instead of
   `profiles` (§1) — the one remaining client change for blocking to be
   fully closed everywhere.
2. Re-verify blocking end-to-end on your side now that `035` is deployed —
   we tested the RLS boundary from our end (unauthenticated smoke tests
   only, no real user session available to us), but a full authenticated
   round trip through the actual app is the real confirmation.
3. Tell us which way to go on §2 above (keep media, or add a
   removed-media-placeholder flag) before we touch `delete-account` again.

---

## 5. Migrations added this round

- `035_blocked_users_table_level_gating.sql` — re-targets blocked-user
  filtering onto `matches`/`conversations` RLS policies directly, adds
  `profiles_discoverable` view for Discover. Already applied to the live
  project.

No Edge Function changes this round — `delete-account`
pending your answer on §2.