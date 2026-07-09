# LoveMe — Media / Image System: Backend Requirements

**To:** Backend team
**From:** Flutter (client) team
**Date:** 2026-07-09
**Project ref:** `tamlbnmihdcjiptbezjm`
**Status:** 🔴 **BLOCKING** — the client-side media feature is fully built and shipped in code, but **cannot function at all** because no Storage buckets exist.

---

## 0. TL;DR — what we need from you

| # | Item | Priority | Blocks |
|---|------|----------|--------|
| 1 | Create **5 Storage buckets** (exact names below) | 🔴 **P0 — blocking today** | All photo/video/voice upload |
| 2 | Add **Storage RLS policies** for those buckets (SQL provided) | 🔴 **P0 — blocking today** | All uploads |
| 3 | Build the **`moderate-image` Edge Function** (NSFW + human check) | 🟠 P1 — launch blocker | Play Store policy compliance |
| 4 | Add a **`conversations` INSERT trigger** on match creation | 🟠 P1 | Chat media can't be sent without a conversation row |
| 5 | Confirm the `profile_photos` / `messages` constraints match §5 | 🟡 P2 | Correctness |
| 6 | Optional: `generate-pdf-thumbnail`, `verify-profile-photo`, `verify-identity` | ⚪ P3 | Future features |

**Verified 2026-07-09 against the live project:**
```
GET  /storage/v1/bucket                    →  []                         (zero buckets exist)
POST /storage/v1/object/avatars/<path>     →  {"error":"Bucket not found"}
```
Every image upload in the app currently fails at the storage layer.

---

## 1. Context — what the client already does

The Flutter app has **fully implemented** the media capture + upload pipeline. It is live in code and passes analysis/tests. It only needs the server side to exist.

**What the client does today, at every media touchpoint:**

1. User taps an "add photo / attach" control.
2. A bottom sheet offers **Take Photo** (camera) or **Choose from Gallery**.
3. `image_picker` returns the file (compressed client-side — see §4 for caps).
4. **For profile photos only:** on-device **Google ML Kit face detection** runs. If no human face is found, the upload is **refused client-side** with:
   > *"That doesn't look like a photo of a person. Please upload a clear photo of yourself."*
5. The bytes are uploaded to Supabase Storage via `supabase_flutter`'s `uploadBinary()`.
6. The resulting URL is written into the relevant DB row (`profile_photos.photo_url` or `messages.media_url`).

> ⚠️ **The client-side face check is a UX convenience, NOT a security control.** It runs on the user's device, can be trivially bypassed (rooted device, modified APK, direct REST call with a stolen JWT), and can be fooled by a photo-of-a-photo or a drawing.
>
> **The authoritative human/NSFW gate MUST be server-side** — see §6 (`moderate-image`). This is also a **Google Play policy requirement** for a dating app that accepts user-uploaded images.

---

## 2. REQUIRED: the 5 Storage buckets

Create these in **Supabase Dashboard → Storage → New bucket**. **Names must match exactly** — they are hard-coded constants in the client (`lib/shared/data/profile_photo_repository.dart`, `lib/shared/data/chat_repository.dart`).

| Bucket name | Public? | Holds | Client path convention | MIME types |
|---|---|---|---|---|
| `avatars` | ✅ **PUBLIC** | Profile photo + gallery (max 4/user) | `<auth_user_id>/<uuid>.<ext>` | `image/jpeg`, `image/png`, `image/webp` |
| `chat-images` | ❌ **PRIVATE** | Chat image messages | `<conversation_id>/<uuid>.<ext>` | `image/jpeg`, `image/png`, `image/webp` |
| `chat-files` | ❌ **PRIVATE** | Chat **video** messages | `<conversation_id>/<uuid>.mp4` | `video/mp4` |
| `chat-file-thumbs` | ❌ **PRIVATE** | Auto-generated video poster frames | `<conversation_id>/<uuid>.jpg` | `image/jpeg` |
| `voice-messages` | ❌ **PRIVATE** | Voice notes (AAC/m4a) | `<conversation_id>/<uuid>.m4a` | `audio/mp4` |

### Why `avatars` is public and the rest are private
- `avatars` — `profiles.photo_url` is read by Discover, Likes, Matches, and the chat list for **other users**. Those screens need a plain, cacheable URL. The client calls `getPublicUrl()`.
- Chat buckets — content is private between two matched users. The client calls `createSignedUrl(path, 604800)` (**7-day TTL**) and stores that signed URL in `messages.media_url`.

> **⚠️ Signed-URL expiry — please advise.** The client currently stores a **7-day signed URL** directly in `messages.media_url`. After 7 days, old chat media will 403. Options:
> **(a)** store the **object path** in `media_url` instead and have the client mint a fresh signed URL on render (client change — we're happy to do this, just say the word), or
> **(b)** make the chat buckets public (weakens privacy — not recommended), or
> **(c)** raise the TTL substantially.
> **We recommend (a).** Please confirm which you want before launch.

---

## 3. REQUIRED: Storage RLS policies

Storage objects live in `storage.objects`. With RLS on and no policy, **every upload 403s**. Paste the following into the **SQL Editor**.

The path convention is `<owner_scope>/<uuid>.<ext>`, so `(storage.foldername(name))[1]` is the first path segment — the user id (avatars) or conversation id (chat buckets).

### 3.1 `avatars` — public read, owner-only write

```sql
-- Anyone (including anonymous) can read avatars: needed for Discover/Likes/Matches.
create policy "avatars_public_read"
on storage.objects for select
to public
using ( bucket_id = 'avatars' );

-- A user may only write into their own <user_id>/ folder.
create policy "avatars_owner_insert"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "avatars_owner_update"
on storage.objects for update
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "avatars_owner_delete"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);
```

> Note: the client uploads with `upsert: true`, so **both INSERT and UPDATE policies are required.**

### 3.2 Chat buckets — participants of the conversation only

A user may read/write chat media only if they are a participant of that conversation (via `conversations.match_id → matches.user1_id / user2_id`).

```sql
-- Helper: is the current user a participant of this conversation?
create or replace function public.is_conversation_participant(p_conversation_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.conversations c
    join public.matches m on m.id = c.match_id
    where c.id = p_conversation_id
      and (m.user1_id = auth.uid() or m.user2_id = auth.uid())
  );
$$;

revoke all on function public.is_conversation_participant(uuid) from public;
grant execute on function public.is_conversation_participant(uuid) to authenticated;
```

Then, **for each** of `chat-images`, `chat-files`, `chat-file-thumbs`, `voice-messages`:

```sql
-- Repeat this block 4x, substituting <BUCKET> each time.
create policy "<BUCKET>_participant_read"
on storage.objects for select
to authenticated
using (
  bucket_id = '<BUCKET>'
  and public.is_conversation_participant( ((storage.foldername(name))[1])::uuid )
);

create policy "<BUCKET>_participant_insert"
on storage.objects for insert
to authenticated
with check (
  bucket_id = '<BUCKET>'
  and public.is_conversation_participant( ((storage.foldername(name))[1])::uuid )
);

create policy "<BUCKET>_participant_update"
on storage.objects for update
to authenticated
using (
  bucket_id = '<BUCKET>'
  and public.is_conversation_participant( ((storage.foldername(name))[1])::uuid )
);
```

> `createSignedUrl()` requires a passing **SELECT** policy, so the read policy above is mandatory even though the bucket is private.
>
> ⚠️ If you choose to store **object paths** instead of signed URLs (§2 recommendation (a)), these policies stay exactly the same.

### 3.3 Optional hardening (recommended)

Set per-bucket limits in the dashboard (or via `storage.buckets`):

| Bucket | `file_size_limit` | `allowed_mime_types` |
|---|---|---|
| `avatars` | `5MB` | `image/jpeg,image/png,image/webp` |
| `chat-images` | `10MB` | `image/jpeg,image/png,image/webp` |
| `chat-files` | `50MB` | `video/mp4` |
| `chat-file-thumbs` | `2MB` | `image/jpeg` |
| `voice-messages` | `10MB` | `audio/mp4,audio/aac` |

---

## 4. What the client sends (exact contract)

So you can size limits and validation correctly. All values are **after** client-side compression.

| Surface | Source | Compression applied by client | Face-checked client-side? | Uploaded to |
|---|---|---|---|---|
| Onboarding avatar | camera / gallery | `imageQuality: 85`, max **1440×1440** | ✅ **Yes** | `avatars` |
| Onboarding gallery (3 extra) | camera / gallery | `imageQuality: 85`, max **1440×1440** | ✅ **Yes** | `avatars` |
| Profile gallery "+" | camera / gallery | `imageQuality: 85`, max **1440×1440** | ✅ **Yes** | `avatars` |
| Profile avatar badge (change primary) | camera / gallery | `imageQuality: 85`, max **1440×1440** | ✅ **Yes** | `avatars` |
| Chat image | camera / gallery | `imageQuality: 85`, max **1920×1920** | ❌ No (memes/screenshots allowed) | `chat-images` |
| Chat video | camera / gallery | max duration **60s**, no re-encode | ❌ No | `chat-files` |
| Chat video thumbnail | auto-generated | JPEG, max width **640**, quality 75 | ❌ No | `chat-file-thumbs` |
| Chat voice note | mic | AAC-LC → `.m4a` | ❌ No | `voice-messages` |

**Upload call shape (all buckets):**
```dart
supabase.storage.from(<bucket>).uploadBinary(
  '<scope_id>/<uuid>.<ext>',
  bytes,
  fileOptions: FileOptions(contentType: '<mime>', upsert: true),
);
```

**URL retrieval:**
- `avatars` → `getPublicUrl(path)`
- chat buckets → `createSignedUrl(path, 604800)` *(7 days — see §2 caveat)*

---

## 5. Database columns the URLs land in (please confirm these still match)

### 5.1 `profile_photos` (live — migration 009/010)
The client writes the **public** avatar URL into `photo_url`.

Constraints the client already respects — **please confirm they are unchanged**:
- `photo_url` non-empty (`23514` on violation).
- `display_order` in **1–4** (`23514`). **Max 4 photos per user.**
- Unique `(user_id, display_order)` (`23505` if the slot is taken).
- Unique partial index: at most one `is_primary = true` per user (`23505`).
- Trigger `sync_primary_profile_photo` mirrors the primary photo's URL onto `profiles.photo_url`. ✅ The client relies on this — it never writes `profiles.photo_url` directly.
- RPC `set_primary_profile_photo(photo_id uuid)` is used to switch the primary.

> ⚠️ **Known gap (not blocking, please advise):** deleting the current primary photo does **not** auto-promote another photo to primary. `profiles.photo_url` keeps its last-synced value and the user is left with **zero** primary photos. Please add an auto-promote trigger, or confirm the client should handle it (we can call `set_primary_profile_photo` on the next photo after a delete).
>
> ⚠️ **Also:** there is **no RPC to add or reorder photos** — the client inserts directly into `profile_photos` under RLS. That's fine, just confirming it's intended.

### 5.2 `messages` (live — migration 005/006)
The client writes the **signed** URL into `media_url`, and (for video) `thumbnail_url`.

Server-enforced rules the client already respects (all raise `23514`):

| `message_type` | `message` (text) | `media_url` | `thumbnail_url` |
|---|---|---|---|
| `text` | **required, non-empty** | must be NULL | must be NULL |
| `image` | **must be NULL** | **required** | — |
| `video` | **must be NULL** | **required** | **required** |
| `audio` | **must be NULL** | **required** | — |
| `gif`, `sticker` | **must be NULL** | **required** | — |
| `location` | — | — | — |

> ⚠️ **`location` messages have no lat/lng columns.** The client does not send them. If you want location sharing, add coordinate columns and tell us.
>
> ⚠️ **We do not send `gif` or `sticker` yet** — no picker exists client-side. The enum values are supported server-side; we'll wire them when a picker is built.

---

## 6. REQUIRED (P1): `moderate-image` Edge Function — the real human/NSFW gate

This is specified in your own `LoveMe-Backend-API-Documentation` §8 but **is not built**. It is a **Google Play policy requirement** for a dating app accepting user images, and it is the **only trustworthy** enforcement of "must be a real person, no nudity."

### Why the client cannot do this
Our on-device ML Kit check only proves "a face-shaped thing is present." It cannot detect nudity, violence, CSAM, a photo-of-a-photo, or a celebrity/stock image, and it can be bypassed entirely by a modified client. **It must not be the last line of defence.**

### Requested contract

```
POST /functions/v1/moderate-image
Headers: Authorization: Bearer <user jwt>, apikey: <anon key>
Body:    { "imageUrl": "https://.../avatars/<uid>/<uuid>.jpg", "context": "profile" | "chat" }
```

**Success (200):**
```json
{ "safe": true, "isHuman": true, "categories": [] }
```

**Rejected (200 with safe=false — please don't use a 4xx for a normal rejection):**
```json
{
  "safe": false,
  "isHuman": false,
  "categories": ["not_a_person"],
  "reason": "No human face detected in this image."
}
```

**Categories we want to distinguish** so we can show the right message:
- `not_a_person` → *"Please upload a clear photo of yourself."*
- `nudity` / `sexual` → *"This image violates our content policy."*
- `violence`, `gore`
- `minor` → **must hard-block and flag** (child-safety / CSAE policy)
- `multiple_faces` (optional — for profile photos we may want exactly one person)

**Rules requested:**
| `context` | `isHuman` required? | NSFW blocked? |
|---|---|---|
| `profile` | ✅ **yes — reject if no human** | ✅ yes |
| `chat` | ❌ no (memes/screenshots allowed) | ✅ yes |

**When it should run — please decide and tell us:**

- **Option A (client calls it):** client uploads → calls `moderate-image` with the URL → if unsafe, client deletes the object and shows the error.
  *Simple, but the bad image exists in the bucket for a moment and a modified client can just skip the call.*
- **Option B (server trigger — RECOMMENDED):** a Storage webhook / DB trigger runs moderation on every new object in `avatars` / `chat-images` / `chat-file-thumbs`. Unsafe → delete the object, delete/flag the referencing row, write to `content_flags`, and (repeat offenders) increment `profiles.policy_violations`.
  *Cannot be bypassed. This is what we recommend.*

We're happy to implement whichever you choose — **Option B needs no client change at all.**

Please also populate the **`content_flags`** table (already in your spec) on every rejection.

---

## 7. REQUIRED (P1): conversations must exist before chat media can be sent

**Chat media upload is currently unreachable in production**, independent of buckets.

Per `migration_003.md` §1/§9, and confirmed by us:
- `conversations` has **no INSERT policy** — the client cannot create one.
- **No trigger** creates a `conversations` row when a match forms.

Result: a brand-new match has **no conversation**, so there is nothing to attach media to. The client currently shows *"Chat isn't available for this match yet."*

**Please add a trigger:** on `matches` INSERT (status `active`), create the corresponding `conversations` row.

*(Related, and also missing: `conversations.last_message_id` / `last_message_at` are never populated. The client works around this by querying `messages` directly for previews, but a trigger would be cleaner and faster.)*

---

## 8. Nice-to-have / future (P3) — not blocking

These are in your API spec, referenced by client screens that **don't exist yet**. No action needed now, but flagging so nothing is forgotten:

| Function / bucket | Used by (future screen) |
|---|---|
| `verify-profile-photo` | AI face-authenticity check on profile photos |
| `verify-identity` | ID document + selfie liveness → sets `profiles.is_verified` |
| `generate-pdf-thumbnail` | PDF/doc chat attachments (`chat-files`) |
| `wise-proofs` bucket | Wise bank-transfer receipt upload (Subscription flow) |
| Video-profile storage | "Video Profile" from the product roadmap (Phase 6) |

Also not yet built client-side: **GIF / sticker pickers** (DB enum already supports them), and **file/document attachments** in chat.

---

## 9. Error contract — what the client expects back

The client maps storage errors to user-facing messages. Please keep these shapes.

| Situation | Expected response | Client shows |
|---|---|---|
| Bucket missing | `404` / `{"error":"Bucket not found"}` | *"Storage bucket "X" does not exist…"* |
| RLS denies upload | `403` (or message containing `row-level security`) | *"Not allowed to upload to "X". Check the bucket's storage policies."* |
| `profile_photos` slot taken | Postgres `23505` | *"That slot is taken — try again."* |
| `profile_photos` bad data | Postgres `23514` | Constraint message |
| Message shape violation | Postgres `23514` | Constraint message |
| Moderation rejects image | `{ "safe": false, "reason": "..." }` (HTTP 200) | The `reason` text verbatim |

> **Please do not** return a bare `500` for a normal moderation rejection — the client treats non-`safe:false` failures as transient and tells the user to retry, which would loop them forever on a genuinely-banned image.

---

## 10. Acceptance checklist — how we'll verify

Please tick these off; we'll re-test on-device once they're green.

**Buckets & policies (P0)**
- [ ] `GET /storage/v1/bucket` returns all 5 buckets.
- [ ] Signed-in user **can** upload to `avatars/<their-own-uid>/x.jpg`.
- [ ] Signed-in user **cannot** upload to `avatars/<someone-else-uid>/x.jpg` → `403`.
- [ ] Anonymous request **can** read a public avatar URL.
- [ ] Conversation participant **can** upload to `chat-images/<their-conversation-id>/x.jpg`.
- [ ] Non-participant **cannot** upload/read that conversation's media → `403` / empty.
- [ ] `createSignedUrl()` succeeds for a participant on all 4 private buckets.
- [ ] Uploading with `upsert: true` twice to the same path succeeds (needs INSERT **and** UPDATE policies).

**Photos (P0)**
- [ ] Uploading a 1st photo with `is_primary: true` updates `profiles.photo_url` via the trigger.
- [ ] `set_primary_profile_photo(photo_id)` swaps the primary and re-syncs `profiles.photo_url`.
- [ ] Inserting a 5th photo, or `display_order` outside 1–4, raises `23514`/`23505`.

**Chat media (P1)**
- [ ] A new `matches` row auto-creates a `conversations` row.
- [ ] `image` message with `media_url` and NULL `message` inserts OK.
- [ ] `video` message **without** `thumbnail_url` is rejected with `23514`.
- [ ] `audio` message with `media_url` inserts OK.

**Moderation (P1)**
- [ ] `moderate-image` exists and returns the §6 shape.
- [ ] A non-person image with `context: "profile"` → `safe:false, categories:["not_a_person"]`.
- [ ] An NSFW image → `safe:false` in **both** contexts.
- [ ] Rejected images are removed from the bucket and logged to `content_flags`.

---

## 11. Open questions we need answered

1. **Signed-URL expiry (§2):** store object paths instead of 7-day signed URLs? *(We recommend yes.)*
2. **Moderation trigger point (§6):** client-invoked (Option A) or storage-webhook (Option B)? *(We recommend B.)*
3. **Primary-photo deletion (§5.1):** will you add auto-promotion, or should the client handle it?
4. **Max photo count:** DB enforces **4**. Our `AppConstants` says 6 (unused). **Confirm 4 is final.**
5. **`chat-files` bucket** currently holds videos. Your spec describes it as PDFs/docs, with videos unspecified. **Confirm videos belong in `chat-files`,** or give us a dedicated `chat-videos` bucket name.
6. **Voice message max length:** client caps recording implicitly; spec says ≤60s. Any server-side limit?
7. **`location` message type (§5.2):** add lat/lng columns, or drop the enum value?

---

## 12. Contact / references

- Client code: `lib/core/media/` (capture + face check), `lib/shared/data/profile_photo_repository.dart`, `lib/shared/data/chat_repository.dart`
- Bucket names are constants: `kAvatarsBucket`, `kChatImagesBucket`, `kChatVideosBucket`, `kChatThumbsBucket`, `kVoiceMessagesBucket`
- Related internal docs: `BACKEND_REMAINING.md` (items **[BE-5]**, **[BE-8]**, **[BE-11]**), `FRONTEND_REMAINING.md`
- Migrations this depends on: `009_profile_photos.sql`, `010_profile_photos_rls.sql`, `013_rpc_functions.sql`, `005_chat.sql`, `006_chat_rls.sql`

**Once §2 + §3 are done, the profile-photo feature works immediately with zero client changes.** Everything else in this doc is additive.
