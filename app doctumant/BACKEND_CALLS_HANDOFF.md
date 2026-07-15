# Love Me International — Voice / Video Calling (Agora): Backend Requirements

**Date:** 2026-07-13
**From:** Flutter client team
**Purpose:** Everything the backend (Supabase) side needs to build so the
**already-built** Agora calling client can go live end-to-end. The client is
done and merged (see developer.log 2026-07-13); this doc is the server-side
contract it is written against.

**Project ref:** `tamlbnmihdcjiptbezjm`
**Media stack chosen:** **Agora** (agora.io) RTC. Media transport is Agora;
**all signaling** (who is calling whom, ring / accept / decline / end) rides on
the **existing `call_logs` table + Supabase Realtime** — no third-party
signaling server, no self-hosted WebRTC/TURN needed.

---

## 0. TL;DR — the 5 things you need to build

| # | Item | Type | Blocker? |
|---|---|---|---|
| 1 | Add 3 columns to `call_logs` (`channel_name`, `caller_agora_uid`, `receiver_agora_uid`) + a trigger to auto-fill `channel_name` on insert | Schema + trigger | **Yes** |
| 2 | INSERT/UPDATE RLS on `call_logs` so a participant can create/advance a call | RLS | **Yes** |
| 3 | `get-agora-token` Edge Function (mints a short-lived Agora RTC token) | Edge Function + secret | **Yes** |
| 4 | Enable **Realtime** on `public.call_logs` (INSERT + UPDATE) | Realtime config | **Yes** |
| 5 | `notify_on_missed_call` trigger → `call_missed` notification row | Trigger | No (push nicety) |

Plus **one ops task**: create an Agora project and give the client the **App
ID** (public) and keep the **App Certificate** server-side (secret, §3).

Once 1–4 are live, calling works in-app (foreground/both-apps-open). Item 5 and
the "native ringing when the app is killed" note in §7 are enhancements, not
launch blockers for the in-app experience.

---

## 1. Architecture — how a call flows (so the schema makes sense)

```
CALLER                          SUPABASE                         CALLEE
  |                                |                                |
  | 1. INSERT call_logs           |                                |
  |    (status='ringing')  ─────► call_logs row                    |
  |                                | ── Realtime INSERT ──────────► | 2. Incoming-call
  |                                |    (filter receiver_id=me)     |    screen rings
  |                                |                                |
  |                                | ◄──── 3. UPDATE status='answered'
  | 4. Realtime UPDATE ◄───────────|    (callee accepted)           |
  |    (status='answered')         |                                |
  |                                |                                |
  | 5. BOTH sides call get-agora-token (channel = call id) ───────► |
  |    ◄──── short-lived RTC token ──────────────────────────────► |
  |                                |                                |
  | 6. BOTH join the Agora channel with (App ID + token + uid) ───► AGORA (media)
  |         ...audio/video flows peer-to-peer via Agora...          |
  |                                |                                |
  | 7. Either side hangs up: UPDATE status='ended',                |
  |    ended_at, ended_by, duration_seconds ─────► call_logs        |
  |    ◄──── Realtime UPDATE tells the other side to tear down ───► |
```

**Key point:** Agora only moves media once both sides are in the channel.
Everything about *making the phone ring, accepting, rejecting, and ending* is
just **status transitions on the `call_logs` row**, observed live over
Realtime. That is why the only "new" backend piece unique to Agora is the token
function (§3).

---

## 2. `call_logs` schema changes

### 2.1 What exists today (migration 005_chat.sql — do not change)

Columns the client already reads/writes:
`id`, `conversation_id`, `caller_id`, `receiver_id`, `call_type`
(`'audio'`|`'video'`), `call_status`, `started_at`, `ended_at`, `ended_by`,
`duration_seconds`. Constraint `call_logs_ended_by_requires_ended_at` (the
client always sends `ended_by` + `ended_at` together — keep this).

`call_status` must support all of: **`ringing`, `answered`, `declined`,
`missed`, `cancelled`, `ended`** (these are the exact enum values the client
writes; if `call_status` is a Postgres enum type, ensure every one exists).

### 2.2 Add these 3 columns

```sql
ALTER TABLE public.call_logs
  ADD COLUMN channel_name        text,
  ADD COLUMN caller_agora_uid    bigint,
  ADD COLUMN receiver_agora_uid  bigint;
```

- **`channel_name`** — the Agora channel both participants join. **Recommended:
  set it equal to the call row's `id`** (a UUID is globally unique, so no two
  calls ever collide). See the trigger in §2.3.
- **`caller_agora_uid` / `receiver_agora_uid`** — *optional*. Stable numeric
  Agora uids per participant. **If you leave these null, the client falls back
  to a deterministic uid it derives locally from the user's id** (a stable
  31-bit hash), so calling still works. Only populate them if you want the
  server to be the single source of truth for uids (e.g. to validate a token
  request is for the right uid). If you *do* populate them, the token function
  (§3) should mint the token for that exact uid.

> **Why the client can't just set `channel_name` itself:** it could, but having
> the DB assign it on insert guarantees both participants agree on the channel
> without a round-trip, and keeps it authoritative. The client already tolerates
> a null (`channel_name ?? id`) so you're free to do it either way — the trigger
> below is the clean version.

### 2.3 Trigger: auto-fill `channel_name` on insert

```sql
CREATE OR REPLACE FUNCTION public.set_call_channel_name()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.channel_name IS NULL THEN
    NEW.channel_name := NEW.id::text;   -- channel = the call's own UUID
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_set_call_channel_name
  BEFORE INSERT ON public.call_logs
  FOR EACH ROW EXECUTE FUNCTION public.set_call_channel_name();
```

---

## 3. `get-agora-token` Edge Function ← the one genuinely Agora-specific piece

The client **cannot** mint Agora tokens itself, because that requires the Agora
**App Certificate**, which is a secret that must never ship in the app. So the
client calls this Edge Function, which mints a short-lived RTC token server-side.

### 3.1 Secrets (Supabase project env)

From the Agora Console (create a project with **"Secured mode: APP ID + Token"**
enabled):
- `AGORA_APP_ID` — also given to the client via `--dart-define` (public, fine).
- `AGORA_APP_CERTIFICATE` — **server-only secret**. Set as a Supabase Edge
  Function secret. **Never send this to the client.**

### 3.2 Request (what the client sends)

Invoked via `supabase.functions.invoke('get-agora-token', body: {...})` with the
user's normal auth JWT (so the function knows who is calling). Body:

```json
{
  "channel_name": "<the call_logs.channel_name, i.e. the call UUID>",
  "uid": 123456789,
  "call_type": "audio"        // or "video"
}
```

### 3.3 Response (what the client expects — exact keys)

```json
{
  "channel_name": "<echo back>",
  "uid": 123456789,
  "token": "006<...agora rtc token...>",
  "expires_at": "2026-07-13T12:34:56.000Z"   // ISO-8601, optional but preferred
}
```

The client parses exactly these keys (`AgoraToken.fromJson`). `token` may be
`null` **only** if you run the Agora project in testing/App-ID-only mode (no
certificate) — then the client joins with a null token. **For production, always
return a real token.**

### 3.4 Token parameters to use when minting

- **Role:** publisher / `RtcRole.PUBLISHER` (both participants send media).
- **TTL:** ~1 hour (3600s) is plenty for a call; the client fetches a fresh
  token per call and never renews mid-call (calls are short). If you want to be
  safe on very long calls, the client can be extended to renew on the Agora
  `onTokenPrivilegeWillExpire` event later — not needed for v1.
- **Channel:** exactly the `channel_name` passed in.
- **uid:** exactly the `uid` passed in (the token is uid-bound).

### 3.5 Authorization checks the function SHOULD do (defense in depth)

The client is trusted only as far as its RLS. The token function should verify
the caller is actually a participant in a real, current call for that channel:

1. `channel_name` corresponds to a `call_logs` row whose `caller_id` **or**
   `receiver_id` equals `auth.uid()`.
2. That call's status is `ringing` or `answered` (don't hand out tokens for
   `ended`/`declined`/`cancelled`/`missed` calls).
3. Optionally: the requested `uid` matches the stored `*_agora_uid` for that
   participant (only if you populated §2.2's uid columns).

If any check fails, return a non-2xx (the client surfaces "Could not get a call
token" and aborts the call cleanly).

> **Reference:** Agora publishes ready-made token-server samples (Node/Deno) —
> the `RtcTokenBuilder.buildTokenWithUid(appId, appCertificate, channel, uid,
> role, expireTs)` call is the whole job. A Deno/TypeScript port drops straight
> into a Supabase Edge Function.

---

## 4. Realtime on `call_logs` (this is how the phone rings)

Enable Supabase Realtime for `public.call_logs` for **INSERT and UPDATE**
(add it to the `supabase_realtime` publication).

The client opens two kinds of realtime subscriptions:

1. **Incoming-call listener** (always on while signed in):
   `INSERT` on `call_logs` filtered `receiver_id=eq.<me>`. A new row with
   `call_status='ringing'` pops the incoming-call screen.
2. **Per-call listener** (while a specific call is in flight):
   `UPDATE` on `call_logs` filtered `id=eq.<callId>`. This is how the **caller**
   learns the callee answered/declined, and how **either** side learns the other
   ended the call.

**RLS interaction:** Realtime respects RLS. Make sure the SELECT policy on
`call_logs` lets a user see rows where they are `caller_id` **or** `receiver_id`
(it already must, for call history to work) — otherwise the receiver won't
receive the INSERT event and the phone won't ring.

---

## 5. RLS on `call_logs`

The client needs these policies (adjust to your existing style):

```sql
-- SELECT: either participant can read the call (likely already present).
CREATE POLICY call_logs_select_participant ON public.call_logs
  FOR SELECT USING (auth.uid() IN (caller_id, receiver_id));

-- INSERT: only the caller may create a call, only as themselves, and only
-- into a conversation they're part of.
CREATE POLICY call_logs_insert_caller ON public.call_logs
  FOR INSERT WITH CHECK (
    auth.uid() = caller_id
    AND public.is_conversation_participant(conversation_id)  -- existing helper
  );

-- UPDATE: either participant may advance the call's status / end it.
CREATE POLICY call_logs_update_participant ON public.call_logs
  FOR UPDATE USING (auth.uid() IN (caller_id, receiver_id));
```

`public.is_conversation_participant(uuid)` is the same `SECURITY DEFINER` helper
already used to gate the chat-media storage buckets (per the 2026-07-10 deploy
memo) — reuse it so a user can't fabricate a call into a conversation they're
not in.

> If you want to be strict about *who* can flip *which* status (e.g. only the
> receiver may `decline`, only the caller may `cancel`), you can encode that in
> the UPDATE `WITH CHECK`. The client already only writes the "correct" status
> from each side, so this is optional hardening, not required for correctness.

---

## 6. `notify_on_missed_call` trigger (optional, push nicety)

Per the earlier push-notifications handoff, a `call_missed` notification type
already exists but nothing inserts it. Add a trigger so a missed/declined call
creates a notification (which your live `send-fcm-push` function then delivers):

```sql
-- On UPDATE of call_logs to status 'missed', insert a notification for the
-- receiver so they get a "missed call" push + in-app row.
CREATE OR REPLACE FUNCTION public.notify_on_missed_call()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.call_status = 'missed' AND OLD.call_status <> 'missed' THEN
    INSERT INTO public.notifications (user_id, type, actor_user_id, data)
    VALUES (
      NEW.receiver_id,
      'call_missed',
      NEW.caller_id,
      jsonb_build_object('conversation_id', NEW.conversation_id, 'call_id', NEW.id)
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_on_missed_call
  AFTER UPDATE ON public.call_logs
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_missed_call();
```

The client already deep-links `call_missed` notifications to the Messages list
(the `data` payload carries `conversation_id`). This matches the existing
notification `data` shape convention.

---

## 7. Out of scope for v1 (flagging so nothing is assumed)

- **Native ringing when the app is killed / backgrounded.** Today the ring works
  when the callee's app is open (foreground/background with the socket alive).
  Full "wake a killed app and show a native call screen" needs **FCM
  high-priority data pushes per call** + Android **ConnectionService** /
  iOS **CallKit + PushKit**. That's a substantial separate feature — if you want
  it, the smallest backend addition is: on `call_logs` INSERT (status
  `ringing`), fire an FCM **data** message (not a notification message) to the
  receiver's tokens with the call payload, so the client can raise a full-screen
  incoming-call intent. Flag if/when you want to prioritize this; the client
  hooks are straightforward to add on top of what's built.
- **Group calls** — not built, single 1:1 only (Agora supports it; the schema
  would need to change). Not in the product roadmap for v1.
- **Call recording / cloud recording** — none. (Agora offers it; would be a
  separate compliance + storage decision.)
- **TURN/STUN / self-hosted media** — **not needed**; Agora's SDN handles
  transport and NAT traversal. No infra for you to run.

---

## 8. What the client already does (so you know the contract is real)

All of this is built, compiles, and is merged (developer.log 2026-07-13):

- **Model:** `CallLog` reads the 3 new columns defensively (null-safe) — it
  works today against the current schema and lights up when you add them.
- **Repository** (`SupabaseCallRepository`): `startCall` (inserts `ringing`),
  `answerCall`/`declineCall`/`cancelCall`/`markMissed`/`endCall` (status
  updates), `getAgoraToken` (invokes `get-agora-token`),
  `subscribeToIncomingCalls` + `subscribeToCall` (the two Realtime subscriptions
  in §4).
- **Engine wrapper** (`AgoraCallService`): owns the `RtcEngine`, join/leave,
  mute/camera/speaker/flip, remote-user join/leave events.
- **State machine** (`CallController`): the full lifecycle in §1, including a
  35-second ring timeout → `missed`, and duration tracking.
- **UI:** one full-screen `CallScreen` for outgoing-ring / incoming-ring /
  connecting / connected (audio + video, with local preview picture-in-picture)
  / ended, plus an app-wide `CallOverlay` that rings on any screen.
- **Entry points:** the voice + video buttons in the chat header, and tapping a
  row in the Messages "Calls" tab to call that person back.
- **Config:** `AGORA_APP_ID` via `--dart-define` (public); the App Certificate
  is expected only on your side.

**To test end-to-end once §1–4 are live:** give the client team the Agora App ID
+ confirm `get-agora-token` is deployed, then two devices signed in as matched
users can call each other. Report anything that doesn't ring and we'll check the
Realtime subscription + RLS SELECT policy together (that's the usual culprit).

---

## 9. Suggested build order (backend)

1. **§2** columns + channel-name trigger (5 min).
2. **§5** RLS INSERT/UPDATE (+ confirm SELECT covers both participants).
3. **§4** enable Realtime on `call_logs`.
4. **§3** `get-agora-token` Edge Function + Agora project/secrets. ← the only
   non-trivial one; use Agora's token-server sample.
5. **§6** missed-call notification trigger (optional, after the above works).

Steps 1–4 are the launch set. Happy to jump on a call for the token-function
wiring — that's the piece most worth pairing on.
