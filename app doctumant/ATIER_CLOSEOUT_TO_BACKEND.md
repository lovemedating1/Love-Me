# Love Me International — A-TIER Close-out: Response to Your Follow-up Reply

**To:** Backend team
**From:** Flutter (client) team
**Date:** 2026-07-14
**Project ref:** `tamlbnmihdcjiptbezjm`
**Re:** Your `a-tierfollow up.md` reply. §1's client change is done and
merged. Decision made on §2 (chat-media storage). This closes out A-TIER
on our side, pending your confirmation.

---

## 0. TL;DR

| # | Item | Status |
|---|---|---|
| 1 | `discoverFeed()` swapped to `profiles_discoverable` | ✅ **Done, merged, verified** |
| 2 | Chat-media storage cleanup vs. "history intact" conflict | **Decision: keep media, drop cleanup** — do not build the placeholder-flag path |
| — | End-to-end re-verification | See §3 — real-device verification still pending (no live Supabase test session run yet this round) |

---

## 1. §1 — `discoverFeed()` now queries `profiles_discoverable`

Done. `lib/shared/data/repositories.dart`,
`SupabaseProfileRepository.discoverFeed()` now selects from
`profiles_discoverable` instead of `profiles` — same shape, same
`.neq('user_id', myId).eq('profile_complete', true)` filters on top, same
client-side already-swiped exclusion kept as a defensive no-op (harmless
now that the view already excludes already-liked/passed/matched, but cheap
insurance against any timing lag between a same-session swipe and the
view's own exclusion catching up).

Verified: `flutter analyze` clean (same 5 pre-existing style infos, zero
new issues), `flutter test` green (2, unchanged).

**Not yet done: a real authenticated end-to-end pass** (two real accounts,
one blocks the other, confirm they disappear from Discover/matches/chat).
We don't have a live Supabase session running in this environment to
exercise it — this needs a manual `flutter run` walkthrough on a device/
emulator, which is already S-TIER item 2 on our own launch tier list
(pending regardless of A-TIER). We'll fold this specific check into that
pass rather than standing up a separate one now — flagging so it's not
mistaken for "confirmed working," it's "wired correctly by inspection, not
yet run."

---

## 2. §2 — decision: keep media, drop the storage-cleanup ask

We're going with your recommended option (#1): **do nothing further here.**
Deleted users' images/videos/voice notes stay in the surviving
participant's conversation history, exactly like the text messages already
do under the `sender_id = null` anonymization. No storage cleanup, no new
placeholder-flag machinery, no client change.

Reasoning, since you asked rather than assumed: your framing that "history
stays intact" should mean *all* history, not just text, is the more
internally consistent reading of what we already agreed to in the original
§3 — and the alternative (a new boolean flag distinguishing "media gone
because the owner deleted their account" from any other reason media might
be missing) is real, non-trivial scope for a problem (storage cost of
orphaned media) that isn't urgent today. If storage cost becomes a real
concern later, we can revisit as its own follow-up rather than bolting it
onto account deletion now.

**Please leave `delete-account` exactly as it is — no further change
needed on your side for this item.**

---

## 3. What's left before A-TIER is fully closed

Nothing further needed from backend right now. On our side:

1. A live-device end-to-end walkthrough of blocking (Discover/matches/
   chat all correctly hide a blocked user) — folded into our existing
   S-TIER "run the app on a real device" item, not a new ask of you.
2. Once that walkthrough passes, we'll consider A-TIER closed and move to
   B-TIER per our internal tier list.

Thanks for the fast turnaround on both rounds — the table-level RLS
approach for `matches`/`conversations` plus a dedicated
`profiles_discoverable` view for Discover is exactly the right shape, and
we appreciate you flagging the media conflict instead of just picking a
side.
