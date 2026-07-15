# Love Me International — C-TIER Backend Requirements

**Date:** 2026-07-14
**From:** Flutter (client) team
**Purpose:** Backend contract for the one genuinely-missing C-TIER chat
feature (typing indicator), plus corrections to stale prior docs about the
other 3 chat items on the C-TIER list. This is the **C-TIER** pass of the
launch tier list (see CLAUDE.md "LAUNCH TIER LIST" and developer.log).
Subscription/payments remain out of scope (final tier). Several other
C-TIER items (Refund Policy copy, ringtone audio, release signing, iOS
track, the unanswered schema-verification thread) are content/ops tasks
with no code for this doc to cover — not addressed here.

**Project ref:** `tamlbnmihdcjiptbezjm`

---

## 0. Important correction to the C-TIER list

CLAUDE.md's C-TIER description said: "chat emoji picker/edit/delete/
typing-indicator" as if all 4 were missing. **Only the typing indicator
was actually missing.** Verified directly against the live client code
before writing anything:

- **Emoji picker** — already fully built. Two separate pickers exist:
  a 20-emoji inline reaction picker (`+` button on each bubble) and a
  48-emoji composer picker (😊 icon in the message field, inserts at
  cursor position). Both are hand-rolled (`const` emoji lists +
  `GridView`/`Wrap`), no third-party package. **No backend involvement
  needed** — reactions already persist to the live `message_reactions`
  table.
- **Edit message** — already fully built (`chat_screen.dart`'s
  `_editMessage`, long-press menu on own text messages → dialog → calls
  `ChatRepository.editMessage()` → `UPDATE messages SET message=...,
  is_edited=true, edited_at=now()`). Already live against real
  `messages.is_edited`/`edited_at` columns (migration 005_chat.sql).
  **No backend work needed.**
- **Delete message** — already fully built (`_deleteMessage`, confirm
  dialog → `ChatRepository.deleteMessage()` → soft-delete via
  `is_deleted=true, deleted_at=now()`). Already live, `getMessages()`
  filters `is_deleted=false` server-side. **No backend work needed.**
- **Onboarding GPS step** — verified genuinely real, not faked.
  `lib/core/location/location_service.dart` calls the actual `geolocator`
  plugin (`Geolocator.getCurrentPosition`, `LocationAccuracy.high`,
  20s timeout), handles service-disabled and permission-denied exceptions
  distinctly, and persists the real fix to `profiles.location_lat`/
  `location_lng`/`location_accuracy_m` on onboarding finish. **Nothing to
  fix — this item can be struck from the tier list.**

So this doc is entirely about the one real gap: **typing indicator.**

---

## 1. Typing indicator

### 1.1 Why

Neither `BACKEND_REMAINING.md` nor any migration doc mentions a typing
indicator anywhere — no table, no column, no RPC, no realtime config. This
needed a design decision, not just a missing piece of an existing plan.

### 1.2 Design chosen: Supabase Realtime Broadcast, not a table

A typing indicator is inherently ephemeral — nobody needs "was typing at
3:42pm yesterday" persisted anywhere. **Realtime Broadcast** (pub/sub over
a WebSocket channel, no Postgres row involved) is the correct fit, not a
new table + Postgres Changes + a cleanup job for stale rows. This requires
**zero schema migration** — it's purely a Realtime/channel-config concern.

### 1.3 What's needed from Supabase project config (not a migration)

By default, Realtime Broadcast on a per-conversation channel name (e.g.
`typing:<conversation_id>`) works for any authenticated client without
additional setup — broadcast doesn't have RLS in the same sense
Postgres Changes does, since there's no table backing it. **Please confirm**:

1. Broadcast is enabled for this project (should be, by default, but
   worth a explicit check since some projects opt out for cost reasons at
   the org level).
2. If your project has **Realtime Authorization** turned on (private
   channels), a channel name pattern like `typing:*` needs an RLS-style
   policy granting `authenticated` users broadcast/receive on it — see
   [Supabase's Realtime Authorization docs] if that's active on this
   project. If Authorization is OFF (the default for most projects), no
   action needed at all.

**This is the only thing we need from backend for this feature** — there
is no schema/RPC/Edge Function to build. If Realtime Authorization isn't
enabled on this project, this doc needs zero action from you; the feature
is already fully live client-side.

### 1.4 Wire shape (for reference — not something you need to build)

```dart
// Sender side (broadcast):
channel('typing:<conversationId>').sendBroadcastMessage(
  event: 'typing',
  payload: {'user_id': '<my auth uid>'},
);

// Receiver side (subscribe):
channel('typing:<conversationId>').onBroadcast(
  event: 'typing',
  callback: (payload) { /* payload['user_id'] != me → show "Typing…" */ },
).subscribe();
```

### 1.5 Client code already wired

- `lib/shared/data/chat_repository.dart` — `ChatRepository.broadcastTyping()`/
  `subscribeToTyping()`, implemented in `SupabaseChatRepository` using
  `sendBroadcastMessage`/`onBroadcast` on a per-conversation channel named
  `typing:<conversationId>`. Self-echo (broadcast delivers to the sender
  too) is filtered client-side by comparing `payload['user_id']` against
  the current user.
- `lib/features/chat/chat_screen.dart` — `_onComposerChanged()` (leading-edge
  debounce, broadcasts at most once per 3s while the user keeps typing,
  called from the message `TextField`'s `onChanged`); `subscribeToTyping`
  wired alongside the existing message-realtime subscription in `_subscribe()`;
  a 4-second silence timeout clears the "Typing…" indicator if no further
  broadcast arrives (broadcast has no explicit "stopped typing" event by
  design — it's a fire-and-forget signal, not a stateful presence channel).
  The chat header's subtitle shows "Typing…" in place of "Online now"/
  "Offline" while `_partnerTyping` is true.

**No further client work needed** once (or if) the Realtime Authorization
question in §1.3 is answered — the feature is complete and should work
end-to-end against the live project as-is if Authorization is off (the
common default).

---

## 2. Summary for planning

This is the smallest backend ask across all 3 tier-handoff docs so far —
potentially **zero action needed** if Realtime Authorization isn't active
on this project (please just confirm either way so the client team knows
whether to expect it to work immediately or needs a policy added first).
