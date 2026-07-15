# Love Me International — Identity Verification Backend Requirements

**Date:** 2026-07-15
**From:** Flutter (client) team
**Purpose:** Everything Supabase (Storage + Postgres + RLS) needs to build
so the **already-built** client-side identity-verification submission flow
has somewhere real to land. The client is done and merged; this doc is the
server-side contract it's written against. iOS is explicitly out of scope
for the whole project right now (Android-only target) — nothing here is
platform-specific regardless.

**Project ref:** `tamlbnmihdcjiptbezjm`

---

## 0. Why this exists — a real problem, not just a missing feature

The Settings → Verification flow (doc-type picker → upload ID → upload
selfie) was previously **fully local-only**: both photos were uploaded to
the `avatars` bucket, and "submitted"/"under review" was just a
`setState` boolean that reset the moment the user left the screen. Two
concrete issues found while fixing this, not just "it's not wired to a
backend yet":

1. **Privacy/security issue**: `avatars` is a **public** bucket (used for
   profile photos precisely because those are meant to be publicly
   visible). Uploading a passport scan or a selfie-holding-ID to a public
   bucket means anyone with the resulting URL could view it — the exact
   opposite of what an identity document needs. This needed a private
   bucket, not just "any bucket."
2. **No persistence**: there was no way to know a user had ever submitted
   anything, no record of which document type, and no real status —
   "Not verified" never changed no matter what happened, since nothing
   was ever actually checked against `profiles.is_verified` (the real,
   live, admin-set column that already exists and already gates the
   verified badge everywhere else in the app).

---

## 1. `verification_requests` table

### 1.1 Schema

```sql
create table public.verification_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  document_type text not null check (document_type in (
    'national_id', 'passport', 'birth_certificate', 'driving_license'
  )),
  document_path text not null,   -- object path in verification-documents bucket
  selfie_path text not null,     -- object path in verification-documents bucket
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  rejection_reason text,
  reviewed_by uuid references auth.users(id),  -- admin/reviewer, nullable
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create index verification_requests_user_idx on public.verification_requests(user_id);
```

### 1.2 RLS

```sql
alter table public.verification_requests enable row level security;

-- Users can submit their own requests.
create policy "insert own verification requests" on public.verification_requests
  for insert with check (user_id = auth.uid());

-- Users can see their own requests (to check status).
create policy "select own verification requests" on public.verification_requests
  for select using (user_id = auth.uid());

-- No client UPDATE/DELETE — status/rejection_reason/reviewed_by/reviewed_at
-- are admin-only, set via whatever review tooling you build (service role
-- or an authenticated admin role, your call).
```

### 1.3 What should happen on approval (your review pipeline, not prescribed here)

When a reviewer approves a request, set `status = 'approved'` and —
critically — **also set `profiles.is_verified = true` for that user** in
the same transaction/action. The client reads `profiles.is_verified` as
the source of truth for the verified badge shown everywhere (Discover
cards, chat header, profile screen) — it does NOT read
`verification_requests.status` for that purpose, only to show the
submission's own review status back to the submitter. If you approve a
request but forget to flip `is_verified`, the user will see "Under review"
change to nothing meaningful and never get their badge.

### 1.4 Exact wire shape the client sends

`POST /rest/v1/verification_requests`:
```json
{
  "user_id": "<uuid, auth.uid()>",
  "document_type": "national_id",
  "document_path": "<uuid>/<uuid>.jpg",
  "selfie_path": "<uuid>/<uuid>.jpg",
  "status": "pending"
}
```

Client reads via `GET /rest/v1/verification_requests?user_id=eq.<uuid>&order=created_at.desc&limit=1`.

---

## 2. `verification-documents` storage bucket

### 2.1 Why a new, separate, private bucket

Every other private chat-media bucket in this app (`chat-images`,
`chat-files`, `chat-file-thumbs`, `voice-messages`) already follows this
exact pattern — private bucket + short-lived signed URLs for anyone who
needs to view the content. Verification documents need the same treatment,
just with **no client-side read path at all** (a user never needs to view
their own submitted ID back — the client only writes here) and a
reviewer/admin-only read path (however your review tooling authenticates).

### 2.2 Bucket + policy

```sql
-- Create the bucket (private).
insert into storage.buckets (id, name, public)
values ('verification-documents', 'verification-documents', false);

-- Users can upload to their own path prefix (<user_id>/...), matching the
-- `avatars`/chat-media bucket policy pattern already in use.
create policy "users upload own verification documents"
  on storage.objects for insert
  with check (
    bucket_id = 'verification-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- No client SELECT policy — only a service-role/admin context should ever
-- read these back (via your review tooling), not the app's anon-key client.
```

### 2.3 Object path shape the client uses

`<user_id>/<uuid>.<ext>` — identical pattern to the `avatars` bucket's
existing path convention, just under the new bucket name.

---

## 3. Client code already wired

- `lib/shared/models/verification_request.dart` (NEW) — `VerificationDocType`
  (4-value enum matching the `document_type` check constraint exactly),
  `VerificationStatus`, `VerificationRequest.fromJson`.
- `lib/shared/data/verification_repository.dart` (NEW) —
  `SupabaseVerificationRepository`: `uploadDocument()` (private bucket,
  returns an object path — never a public URL), `submitRequest()`,
  `myLatestRequest()`. Catches Postgrest `42P01`/`PGRST205` and storage
  "missing bucket" errors and throws `VerificationFeatureUnavailableException`
  — the UI shows "not available yet" instead of a raw error until you ship
  the table/bucket.
- `lib/core/media/photo_picker_service.dart` — new `pickVerificationDocument()`
  (no on-device face-check, since a scanned ID legitimately may not have a
  clean face crop the detector recognizes — unlike the selfie step, which
  still uses the existing `pickProfilePhoto()` face-check).
- `lib/features/settings/settings_screen.dart` — `_verificationCard()` now
  reads real status (`myVerificationRequestProvider`) and shows "Verified"/
  "Under review"/"Rejected — resubmit"/"Not verified" instead of a static
  label; `_VerificationFlow` rewritten to a real 3-step flow (doc type →
  upload document → upload selfie → submit), persists across sessions, and
  a rejected request can be resubmitted (a `pending` or `approved` request
  cannot — the picker flow is only shown when there's no request or the
  last one was rejected).
- `lib/shared/data/repositories.dart` — `verificationRepositoryProvider`,
  `myVerificationRequestProvider`.

**Until the table/bucket exist**, the flow fails gracefully at the upload
step with "Verification isn't available yet — please try again soon." —
no crash, no silent data loss, and nothing was ever sent to the wrong
(public) bucket in the meantime since the old `avatars`-upload code path
has been fully replaced, not left as a fallback.

---

## 4. Summary for planning

Two pieces, both small: the table (§1) and the bucket (§2). Recommend
shipping both together since the client's `submitRequest()` call assumes
both exist simultaneously — there's no useful partial state (a document
uploaded to the bucket with nowhere to record the submission isn't useful
on its own). No Edge Function needed unless you want server-side automated
document/selfie-match verification (out of scope for this doc — manual
admin review via direct table/bucket access, or your own tooling, is
suffient to make the client-side flow fully functional).
