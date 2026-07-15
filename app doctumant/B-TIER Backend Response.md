# Love Me International — B-TIER Backend Response

**To:** Flutter (client) team
**From:** Backend team
**Date:** 2026-07-14
**Project ref:** `tamlbnmihdcjiptbezjm`
**Status:** 🟢 All 3 items done and deployed. One naming deviation from your
spec, flagged in §2 — please read before wiring the call site.

Responding point-by-point to your 2026-07-14 B-TIER requirements doc. New
migrations added: `036`–`039` (`038` shipped a bug, `039` fixes it — see §2).

---

## 0. TL;DR — status against your table

| # | Item | Status |
|---|---|---|
| 1 | `get_country_counts()` RPC | ✅ **Done** — `037_country_counts.sql`, exact name/shape you asked for |
| 2 | Discovery pagination RPC | ✅ **Done, but renamed** — `get_discover_profiles_page()`, not `get_discover_profiles()`. See §2, this is the one thing you need to change your call site for |
| 3 | `profiles.bio` / `interests` / `occupation` columns | ✅ **Done** — `036_extended_profile_fields.sql` |
| 4 | PostGIS distance | ⚪ Not started, matches your "not requested for this pass" |

**Run migrations `036` through `039` before re-testing.** All 4 are already
applied to the live project — nothing further needed on our side unless you
hit something in re-testing.

We built these in your recommended order: §3 first (only item with a
user-visible failure mode), then §1, then §2 (thin pagination wrapper only,
no ranking algorithm — see §2 below for why we didn't go further).

---

## 1. §3 — extended profile columns: done, exact spec

`036_extended_profile_fields.sql` adds `bio` (capped at 500 chars via
`profiles_bio_length`, matching `AppConstants.maxBioChars`), `interests`
(`text[]`, same pattern as the existing `hobbies` column, no DB-level cap —
you already cap entry count client-side at `AppConstants.maxInterests`), and
`occupation` (uncapped, per your spec). No RLS changes needed — the
existing owner-only UPDATE / open SELECT policies on `profiles` already
cover new columns since RLS is row-level, not column-level.

`updateMyProfile()` should stop throwing on a bio/interests/occupation
save immediately — please re-verify the Edit Profile sheet's "Could not
save" failure mode is actually gone now.

---

## 2. §1 — get_country_counts: done, exact spec

`037_country_counts.sql` matches your proposal verbatim: same function
name, same `security invoker` choice (so a blocked user is correctly
excluded from another user's country counts, same as Discover — consistent
with the A-TIER blocking work), same `{country, count}` shape, ordered by
count descending. `countryCountsProvider`'s RPC-first path should just
start returning real numbers — no client change needed.

---

## 3. §2 — discovery pagination: done, but under a different name than your spec — please read this before wiring anything

**We did not build `get_discover_profiles(limit, offset)` as your §2.3
proposed it — the function is called `get_discover_profiles_page(limit,
offset)` instead.** Here's exactly why, since it matters for how you wire
the call site:

An older `get_discover_profiles()` (no arguments) already existed server-side
(`013_rpc_functions.sql`, later updated for blocking in
`031_blocked_users_filtering.sql`) — this predates your doc and, per the
A-TIER follow-up thread, isn't in your current call path either (you query
`profiles_discoverable` directly). We didn't know that when we first wrote
this migration, and initially did exactly what your §2.3 proposed:
overloaded `get_discover_profiles()` with a same-named `(int, int)`
version.

**That broke the existing 0-argument function.** PostgREST resolves RPC
calls by name, and since every parameter on the new overload has a
default, an empty-body call to `/rpc/get_discover_profiles` became
ambiguous between the two — PostgREST returned `PGRST203 "Could not choose
the best candidate function"` instead of picking one, for *both* versions,
not just the new one. We caught this via a live smoke test immediately
after deploying (before telling you about it, and before any real
integration), fixed it same-day: `039_fix_discover_profiles_overload_ambiguity.sql`
drops the `(int, int)` overload and re-adds the identical pagination logic
under the name `get_discover_profiles_page` instead. Verified live:
the original 0-arg `get_discover_profiles()` resolves cleanly again, and
`get_discover_profiles_page()` works standalone with no ambiguity either
way (explicit params or defaults).

**What to actually call:**

```dart
supabase.rpc('get_discover_profiles_page', params: {
  'p_limit': 100,   // optional, defaults to 100
  'p_offset': 0,    // optional, defaults to 0
});
```

Returns `setof profiles_discoverable` — same row shape as querying
`profiles_discoverable` directly, just paginated and server-side,
newest-first (`order by created_at desc`), exactly matching your current
client-side query's order. No ranking algorithm, no daily-candidate-cap
enforcement — per your own §2.1/§2.3, we're treating both of those as
needing product confirmation before we build anything further, and this
thin wrapper as an acceptable v1 on its own. Tell us if product wants real
ranking and we'll scope that as its own piece of work rather than guess.

**Distance (§2.2):** no server-side change here — your client-side
Haversine calc against `location_lat`/`location_lng` is what's live today,
we didn't touch it, nothing in this migration set affects it.

---

## 4. §4 — PostGIS: not started, as expected

Matches your doc's own framing — not requested for this pass, noted for
whenever geo-ranking/server-side radius filtering becomes an actual
requirement. No action taken.

---

## 5. What we need from you

1. **Wire `discoverFeed()`'s pagination path to `get_discover_profiles_page`,
   not `get_discover_profiles`** — the one required naming change from
   your original spec. Everything else (shape, params, defaults, ordering)
   matches what you asked for exactly.
2. Re-verify Edit Profile bio/interests/occupation saves succeed (§3) —
   this was your priority item and should now just work.
3. Confirm `countryCountsProvider` is pulling real numbers via the RPC
   path now, not falling back to the client-side paged count (§1).
4. No urgency on ranking/daily-cap — flag it to product when convenient,
   we'll wait for that signal before building anything beyond today's
   pagination wrapper.

---


## 6. Migrations added this round

- `036_extended_profile_fields.sql` — `bio`/`interests`/`occupation` columns
- `037_country_counts.sql` — `get_country_counts()` RPC
- `038_discover_pagination.sql` — initial pagination RPC attempt; **left
  in the migration history as originally shipped** (including the
  overload bug) rather than rewritten, so the history accurately reflects
  what was actually deployed at each point. Comments in the file explain
  the bug and point to `039`.
- `039_fix_discover_profiles_overload_ambiguity.sql` — drops the broken
  overload, adds `get_discover_profiles_page(limit, offset)` under its own
  name. This is the one your client should actually call.