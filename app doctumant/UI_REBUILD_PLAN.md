# LoveMe — UI Rebuild Plan (5 Phases)

> **Goal:** make the Flutter rebuild look **the same as the old app** in the
> screenshots (`app doctumant/old app ss/`).
>
> **Source of truth:** `app doctumant/UI_GAP_ANALYSIS.md` (the full screen-by-screen
> diff). This document turns that diff into an ordered, executable plan.
>
> **Created:** 2026-07-10

---

## 📌 HOW TO RESUME THIS WORK IN A NEW CHAT

If you're picking this up in a fresh session, paste this:

> "Read `app doctumant/UI_REBUILD_PLAN.md` and `app doctumant/UI_GAP_ANALYSIS.md`.
> Check the Progress Tracker, then continue with the next unchecked phase."

**Rules for whoever executes this (human or AI):**
1. Do **one phase at a time**. Do not start the next phase without the user's "go".
2. After finishing a phase: run `flutter analyze` + `flutter test`, tick the boxes in
   the **Progress Tracker** below, append an entry to `developer.log`, and stop.
3. This is a **UI-only** effort. Do **not** change backend calls, repositories, or
   data models unless a task explicitly says so.
4. If a screenshot and this doc disagree, **the screenshot wins** — but tell the user.

---

## 🚦 PROGRESS TRACKER

*(Update these checkboxes as work completes. This is the resume point.)*

| Phase | Title | Status |
|---|---|---|
| **0** | Decisions & Blockers (user input needed) | ✅ **Done 2026-07-10** |
| **1** | Design System + Global Shell | ✅ **Done 2026-07-10** |
| **2** | Discover (the hero screen) | ✅ **Done 2026-07-10** |
| **3** | Profile · Likes · Explore | ✅ **Done 2026-07-10** |
| **4** | Settings · Subscription · Messages/Chat | ✅ **Done 2026-07-10** |
| **5** | Legal · Modals · Cleanup · Polish | 🟨 **Done 2026-07-10 except §5.1 (blocked — no legal copy supplied)** |

**Legend:** ⬜ Not started · 🟨 In progress · ✅ Done

---

## ✅ PHASE 0 — DECISIONS (ANSWERED 2026-07-10)

**All decisions below are LOCKED. Later phases must follow them.**

### 0.1 Pen annotations — ✅ ANSWERED
- `WA0050/55/60`: the **36d + 22d header pills** and the **bell** are circled →
  ✅ **BUILD THEM.** Required.
- `WA0038`: **"Upload Order Receipt Screenshot"** crossed out →
  ✅ **KEEP THE BUTTON.** The X was *not* a delete instruction.
  *(Note: Wise receipt upload has no backend — the button stays but will be
  non-functional / flagged until `verify-receipt-upload` exists. [BE-4])*

### 0.2 Subscription plans — ✅ ADOPTED EXACTLY

| Plan | Price | Profiles/mo | Badge |
|---|---|---|---|
| Free | $0 | *(TBD — ask backend)* | — |
| **Basic+** | $5/mo | 500 | Silver |
| **Gold** | $10/mo | 1000 | Gold |
| **Platinum** | $15/mo | 1500 | Diamond |
| **Premium Elite** | $20/mo | 2000 | Crown 👑 |
| **VIP Elite** | $25/mo | Unlimited | VIP 💎 |

➡️ Replace `MockData.plans` + extend `SubscriptionPlan` with `profileLimit` + `badge`.
❗ The **Free tier's profile limit is still unknown** — confirm before Phase 4.

### 0.3 Legal copy — ⏸️ DEFERRED
User will supply the real Terms / Privacy / Refund / Child-Safety text **later**.
➡️ Phase 5.1 stays in the plan but is **blocked** until the copy arrives.
⚠️ **Still a Play Store launch blocker.** Do not ship with lorem ipsum.

### 0.4 Keep/delete list — ✅ RULE: **MATCH THE OLD APP EXACTLY**
> *"If the old app doesn't have it, remove it."*

| # | Ours | Action | Phase |
|---|---|---|---|
| 1 | "Matches" tab inside Likes | 🗑 **DELETE** | 3 |
| 2 | Blurred premium grid on Liked-You | 🗑 **DELETE** (use a plain list) | 3 |
| 3 | Stats row (Views/Likes/Matches) on Profile | 🗑 **DELETE** | 3 |
| 4 | Photo gallery grid on Profile | 🗑 **DELETE** | 3 |
| 5 | Premium demo toggle | 🗑 **DELETE** | 3 |
| 6 | Admin Diagnostics screen | 🗑 **DELETE** | 5 |
| 7 | Confirm-password at signup | 🗑 **DELETE** | 1 |
| 8 | DOB / Gender / Country at signup | 🗑 **DELETE** (moves to onboarding) | 1 |
| 9 | Google sign-in button | 🗑 **DELETE** | 1 |
| 10 | Password ≥ 8 chars | ✏️ **CHANGE → min 6** | 1 |
| 11 | Delete-account: password + type-"DELETE" + reason | 🗑 **DELETE all 3** | 5 |
| 12 | Notifications unread dots / mark-all / swipe-delete | 🗑 **DELETE** | 5 |
| 13 | 8 notification toggles | ✏️ **COLLAPSE → 1** ("Background Alerts") | 4 |
| 14 | Bio on the Discover card | 🗑 **DELETE** | 2 |
| + | Legal footer links on auth | 🗑 **DELETE** | 1 |

> ⚠️ **#13 caveat:** our 8 toggles *are* backed by the real `notification_preferences`
> table. Collapsing to 1 means the other 7 columns go unused. That's the old app's
> behaviour, so we follow it — but keep `NotificationRepository.updatePreferences()`
> intact so they can be re-exposed later.

### 0.5 Known correction — ✅ FIX IT
I wrongly deleted **Vibration + Sound** from Settings in the Group-A pass. The old app
has **"Vibrate on incoming call"** and a **ringtone preview** — these are **device-local**
settings (hence no DB column).
➡️ **Restore as local settings via `shared_preferences`** (already installed).
Doing this **immediately, before Phase 1**.

### 0.6 Missing screenshots — ⏸️ N/A
No screenshots for: onboarding wizard, matches list, forgot-password, email-verified,
reset-password, 404, admin, in-call UI. **Those screens stay as-is** unless screenshots
arrive later.

---

## 🎨 PHASE 1 — DESIGN SYSTEM + GLOBAL SHELL
*The foundation. Touches every screen. Highest visual payoff per hour.*

**Why first:** the header and bottom nav appear on all 5 tabs; the tokens (colours,
radii, shadows, gradient buttons, chips) are reused by every later phase. Doing this
first means Phases 2–5 are built on the right primitives instead of being retro-fitted.

### 1.1 Design tokens (`lib/core/theme/`)
- [x] **Background**: set the app's page background to the old app's light pink
      everywhere (`AppColors.bgLight` is already `#FFF0F5` — verify it's actually
      applied to `Scaffold`/`ThemeData.scaffoldBackgroundColor`, not just defined).
- [x] **Primary pink**: compare our `#E6287A` against the old app's more saturated
      hot pink (~`#FF1F8E`). Decide + update `AppColors.pink`.
- [x] **Card style**: radius **~20px**, white/near-white fill, soft shadow, generous
      outer margin. Add to `AppTheme.cardTheme`.
- [x] **Buttons**: create a reusable **gradient-filled, fully-rounded, soft-glow**
      button (old app's primary CTA style). New widget: `shared/widgets/gradient_button.dart`.
- [x] **Toggles**: large, pink-filled, iOS-style switches (`SwitchTheme`).
- [x] **Gradients**: add the pink→orange gradient (used by "Manage Plan") to
      `AppGradients`.

### 1.2 New shared widgets
- [x] `shared/widgets/app_chip.dart` — the multi-colour pill/chip with optional emoji
      suffix (yellow / pink / grey variants). Used heavily by Discover + Profile.
- [x] `shared/widgets/segmented_tabs.dart` — the pill-style tab switcher (used by
      Messages "Chats / Calls"), with an optional count badge.
- [x] `shared/widgets/gradient_button.dart` — see 1.1.
- [x] `shared/widgets/sub_page_header.dart` — pink-gradient second-level header with a
      circular translucent back button (used by Settings, Notifications, Devices, Legal).

### 1.3 App header rebuild (`shared/widgets/app_header.dart`) 🔴 **big one**
Replace the static "Love Me" wordmark with the old app's personalized header:
- [x] Left: circular **user avatar** (~48px) — reads `currentUserProvider`.
- [x] **"Hi, {name}"** — bold, large.
- [x] 📍 **location line** — the user's ward/city + country.
      *(Note: we have no real GPS yet — render `profiles.city, country`, and leave a
      TODO for the real ward once geolocator lands.)*
- [x] Pill 1: 📅 **"{N}d"** — days to **account expiry**.
- [x] Pill 2: 🕐 **"{N}d"** — days to **subscription renewal**, orange-tinted.
- [x] Right: circular translucent **bell** → Notifications, **on all 5 tabs**
      (currently Discover-only).
- [x] Both pills are **tappable** → the expiry modals (built in Phase 5; wire the
      taps now to a `TODO`/no-op or build the modals here if time allows).

> ⚠️ **Data gap:** neither countdown has a backing value yet. `profiles` has
> `premium_until`; there is **no account-expiry field**. For now: derive the
> subscription pill from `premium_until` when present, and **hide** a pill whose
> value is unknown rather than faking a number. Flag to backend.

### 1.4 Bottom nav (`shared/widgets/bottom_nav.dart`)
- [x] Swap Discover's icon from `compass` → **sparkles-plus**.
- [x] Active tab: icon becomes **filled** (not outline).
- [x] Add the small **pink dot** beneath the active tab's label.
- [x] Keep the existing count badge behaviour.

### 1.5 Auth screen (`features/auth/auth_screen.dart`)
*(Depends on Phase-0 answers 0.4 #7/#8/#9/#10.)*
- [x] Remove the white `Card` — plain pink background, centered content.
- [x] Wordmark **"LoveMe"**, tagline **"Find your perfect match"**.
- [x] Tabs → **"Login" / "Sign Up"** in a full-bleed segmented control.
- [x] Bold **labels above** each field (not floating labels).
- [x] Password hint **"Min 6 characters"** (+ change `Validators.password` to 6).
- [x] Add the **"↻ Refresh"** action under the CTA.
- [x] 18+ checkbox with inline **Terms & Conditions** / **Privacy Policy** links.
- [x] Per Phase-0: remove confirm-password / DOB / gender / country / Google / legal footer.

**Phase 1 exit criteria:** `flutter analyze` + `flutter test` green; every tab shows
the new header + nav; a screenshot of Discover/Profile visibly matches the old app's
*chrome* (even if the card bodies aren't done yet).

---

## 💖 PHASE 2 — DISCOVER (the hero screen)
*The single biggest gap. Deserves a phase of its own.*

### 2.1 Above the card
- [x] **Worldwide/radius selector chip** — yellow pill `🌍 (Worldwide) ⌄`.
- [x] **Quota line** — `"1000+ profiles/month"` (left) + `👑 Gold Plan` (right, pink).
      *(Wire to the real plan once Phase 0.2 is locked; until then read `isPremiumProvider`.)*
- [x] **Stale-location banner** — *"Your location is over a day old. Showing matches
      within a safer 25 km until you refresh."* + **Refresh** button.
      *(Static for now; needs geolocator to be real.)*

### 2.2 The profile card (`features/discover/discover_screen.dart`)
Rebuild `_card()` to match `WA0034` / `WA0050`:
- [x] **Photo carousel** — segmented progress bars along the top; ▶ arrow to advance;
      swipe between photos. *(Reads `profile_photos`; today `Profile` only carries one
      `photoUrl` — needs a `photosFor(userId)` fetch. See Data note below.)*
- [x] **Side photo rail** — right-edge circular thumbnails numbered 1/2/3; active is ringed pink.
- [x] **Marital-status chip** — top-left dark pill `Marital Status: Single 💫`.
- [x] **Report button** — top-left dark pill, red shield icon. *(Opens the report flow —
      backend `reports` table doesn't exist; wire the UI + a "coming soon" toast, and
      flag it.)*
- [x] **Last-active pill** — top-right `🔴 10h ago`. *(Needs `user_presence.last_seen`,
      which the app doesn't read yet.)*
- [x] **Distance chip** — `215 km (134 mi) away` (**both units**), pink pill.
- [x] **"Approx" badge** — yellow pill 📡 `Approx` when GPS accuracy is low.
- [x] **Relationship-goal line** — `Need a serious relationship 💍`.
- [x] **Tag chips** — `✨ Straight` (yellow) · `👁 Likes men` (pink) · interests (grey),
      each with its emoji. Uses `AppChip` from Phase 1.
- [x] **"Show more ⌄"** — yellow pill that expands additional details.
- [x] Remove the bio from the card (per 0.4 #14).

### 2.3 Action buttons
- [x] Four **solid colour circles**, no text labels, in the old app's order:
      ⚪ **X** (white) · 🟡 **★** (yellow) · 🟢 **💬** (green) · 🩷 **♥** (pink).
      *(Note the order change: heart and chat are swapped vs ours.)*

### 2.4 Gestures
- [x] **Swipe left/right** to pass/like, with spring-back animation.

### 2.5 Filters
- [x] Replace the generic filters sheet with the **Search-radius sheet** (`4`/`WA0030`):
      Worldwide toggle · big `50 km` readout · slider (5–5000) · **9 preset chips**
      (5/10/25/50/100/250/500/1000/2500/5000) · **"Apply worldwide"** CTA.

> **Data note:** several card elements have no data source yet — multiple photos per
> profile in the feed, `last_seen`, GPS accuracy, real distance. Build the UI to accept
> them, render gracefully when absent (hide the chip rather than fake it), and list the
> gaps in `developer.log` + `BACKEND_REMAINING.md`.

**Phase 2 exit criteria:** analyze/test green; Discover is visually side-by-side
comparable to `WA0034`; missing-data elements are hidden, not faked.

---

## 👤 PHASE 3 — PROFILE · LIKES · EXPLORE
*Three screen restructures that share the new "profile preview modal".*

### 3.1 Shared: Profile-preview modal 🔁 (used by 3.2 **and** 3.3)
- [x] New `shared/widgets/profile_preview_modal.dart` (`8`, `WA0035`):
      `Name, Age` · large circular photo · 📍 location · ♥ relationship goal ·
      interest chips · **[Close]** **[Message 💬]**.

### 3.2 Profile tab (`features/profile/profile_screen.dart`)
- [x] Replace the gradient banner with a **white rounded card**:
      avatar + pink camera FAB · `Name, Age` (black text) · 📍 location ·
      pill `🧭 Location is on` · pill `👑 Gold Active · 22d left` ·
      ♥ relationship goal · tag chips · **✏️ pencil edit FAB** top-right.
- [x] Add the **"Manage Plan"** card — pink→orange gradient, 👑, "Current Plan: Gold",
      "Expires 28 Jul 2026", `›`.
- [x] Reduce to **3 rows**: ⚙️ Settings · 🚩 My Safety Reports · 🚪 Log Out (red).
- [x] Remove (per Phase 0): stats row, gallery grid, premium demo toggle, bio block,
      and the Notifications/Devices/Subscription rows (they move into Settings).

### 3.3 Likes tab (`features/likes/likes_screen.dart`)
- [x] Heading **"People Who Like You"** + subtitle **"Viewing all N likes"**.
- [x] Plan banner (`👑 Gold`, pink rounded bar).
- [x] Convert the grid → a **vertical list**: avatar · **Name** · location · **age** · `›`.
- [x] Tap → the **profile-preview modal** from 3.1.
- [x] Per Phase 0: remove the Matches tab + the blur/Unlock gate (or keep — user decides).

### 3.4 Explore tab (`features/explore/explore_screen.dart`)
- [x] Title **"Explore"** + subtitle *"Discover people worldwide"* + 🌐 **"Browse by Country"**.
- [x] **Search countries…** field.
- [x] **3-column grid of ALL countries**, alphabetical, each a white card:
      **flag image** · name · **user count**.
      *(Needs a real country list + flag assets, and a `get_country_counts` RPC that
      doesn't exist — see backend gap [BE-9]. Ship the UI with a bundled country list
      and counts of `0`/`—` until the RPC lands.)*
- [x] Tap a country → **country user-list modal** (`WA0043`): flag · name · `(N users)` ·
      user rows · `✕`.
- [x] Tap a user → the **profile-preview modal** (not chat, as we do today).

**Phase 3 exit criteria:** analyze/test green; the preview modal is reused in both
Likes and Explore; Profile matches `WA0045`.

---

## ⚙️ PHASE 4 — SETTINGS · SUBSCRIPTION · MESSAGES/CHAT
*The most content-heavy phase. Depends on Phase 0.2 (plans) and 0.5 (vibration).*

### 4.1 Settings (`features/settings/settings_screen.dart`) — restructure to **cards**
Convert the flat list into a stack of white rounded section cards:
- [x] 👑 **Subscription** card — `Gold — $10.00 USD / 30 days`, `Active until 7/28/2026`,
      **"⬇ Download Receipt (PDF)"** gradient button. *(PDF generation is new work; if
      out of scope, render the button disabled + flag it.)*
- [x] ☀️ **Appearance** — Dark Mode + **"Remember email after inactivity logout"**.
- [x] 🧭 **Location Settings** — 🟢 "Location enabled" · Discovery Distance `🌍 Worldwide` ·
      **Worldwide** toggle.
- [x] 🔔 **Push Notifications** — collapse our **8 toggles → 1**: **"Background Alerts"**
      (*"Get notified about likes & messages even when the app is closed"*).
      *(Per Phase 0.4 #13. If you'd rather keep the 8, say so — they ARE backed by
      `notification_preferences`.)*
- [x] 🎵 **Call Ringtone** — dropdown with **descriptions** (Classic / Modern / Marimba)
      + **▶ preview** button. *(Needs ringtone audio assets + `audioplayers`.)*
- [x] 📳 **Vibration** — restore **"Vibrate on incoming call"** as a local setting.
- [x] 🛡 **Verification** (expandable) — `Not verified ⌄` → doc-type picker
      (**National ID · Passport · Birth Certificate · Driving License**) →
      **Step 1 of 2: Upload document** (dashed upload zone) → **Step 2: selfie**.
      *(Reuses the existing `PhotoPickerService`. Backend `verify-identity` doesn't
      exist — upload + show "under review".)*
- [x] ❓ **Help & Support** (expandable) — FAQ (5 Q&As) · Contact Us (email +
      "Chat on Google Chat") · **Safety Tips** (5 bullets).
- [x] 🗑 **Delete Account** row → the (simplified) delete screen.

### 4.2 Subscription (`features/subscription/subscription_screen.dart`)
- [x] Replace the mock plans with the **real 5 tiers** (Phase 0.2) — update
      `SubscriptionPlan` model to carry `profileLimit` + `badge` and rewrite
      `MockData.plans`.
- [x] Header `←` **"Choose Your Plan"** + 👑 **"Unlock Premium"**.
- [x] Plan rows: name · `N profiles` · **tier badge** (Silver/Gold/Diamond/Crown/VIP) ·
      ⓘ info button · `$10`/mo.
- [x] The **current** plan: peach fill, green border, floating green **"✓ CURRENT"** ribbon.
- [x] Renewal banner: 🟢 *"You're Currently on this Gold Plan"* · *"Renews … · 22 days left"*.
- [x] **"Checkout Section/Billing ⌄"** expander.
- [x] 🟢 **"Pay with M-PESA / Airtel Money"** button (with logo asset).
- [x] Remove the Wise **"Upload Order Receipt Screenshot"** button (pending Phase 0.1).
- [x] Footer *"Made with ♥ By Randy"*.
- [x] Remove our perks hero + usage bars + PayPal/Wise/Play buttons (unless you want them).

### 4.3 Messages list (`features/messages/messages_screen.dart`)
- [x] Big title **"Messages and Calls"**.
- [x] Replace `TabBar` with the **segmented pill switcher** (`SegmentedTabs` from Phase 1),
      with a **count badge** on "Chats".
- [x] Conversation rows → **elevated white cards**, 3 lines: **Name** / `Last seen 11d ago`
      / last-message preview; right = relative time; avatar has an **online/offline dot**.
- [x] Replace swipe-to-delete with the **inline expanding action row**:
      **Mute 🔕 · Archive 🗄 · Delete 🗑** + `✕`.
      *(Mute/Archive have no backing tables — [BE-11]. Wire UI, disable or toast.)*
- [x] Calls empty state: 3D phone emoji, **"No calls yet"**, *"Start a voice or video
      call from any chat"*.

### 4.4 Chat (`features/chat/chat_screen.dart`)
- [x] Header: circular back · avatar w/ status dot · Name + **"Offline"** ·
      **📞 / 🎥 / 🛡** circular buttons.
- [x] **Date separators** — grey pill `Friday, Jul 3, 2026`.
- [x] **`+` reaction button** attached to each bubble's edge (replacing long-press).
- [x] **Inline reaction picker** — white card, **20 emojis**, 3 rows, anchored to the
      bubble (replacing our 6-emoji bottom sheet).
- [x] Composer: **separate 🖼 image and 📎 attach** circles · rounded field with an
      **😊 emoji icon inside** · **pink gradient circular 🎤 mic FAB**.
- [x] **Safety modal** on 🛡: title w/ shield + name; **"Block X"** and
      **"Report & Block"** as bordered cards.

**Phase 4 exit criteria:** analyze/test green; plans show the real 5 tiers; Settings is
card-sectioned; chat composer matches `9`.

---

## 🧹 PHASE 5 — LEGAL · MODALS · CLEANUP · POLISH
*Everything remaining, plus the launch blockers.*

### 5.1 Legal (launch blocker) 🔴
- [ ] **"Privacy & Terms" hub** (`WA0061`) — shield title, "Last updated", link cards
      for **Terms & Conditions** + **Refund Policy**, then real prose sections.
- [ ] **Terms & Conditions** page (`WA0063`) — numbered sections, real copy.
- [ ] **Child Safety Standards** page (`WA0051`) — solid-red **"🚩 Report CSAM / Child
      Safety Concern"** button at top; the **Google Play CSAE compliance statement**
      (developer **The Orbit Devs**, listing `com.loveme.intldating`); footer buttons.
- [ ] Replace **all** `_lorem` placeholder copy with the real text (Phase 0.3).

### 5.2 The remaining modals
- [x] **"Find people nearby"** location-permission modal (`3`) — pin, copy, **Enable Now**.
- [x] **"Get Verified"** promo modal (`WA0041`) — shield, **Verify Now 🛡** / **Maybe Later**.
- [x] **Account-expiry modal (36d)** (`WA0046`) — calendar icon, 90-day resignup copy, **Got it**.
- [x] **Subscription-expiry modal (22d)** (`WA0054`) — clock icon, exact datetime,
      **Got it** / **Close**. *(Wire the Phase-1 header pills to these.)*

### 5.3 Screen simplifications (per Phase 0.4)
- [x] **Delete Account** (`WA0062`) — white header; a **"Danger Zone"** card with the
      5-bullet list + solid red **"Delete My Account"**. Remove password / type-DELETE /
      reason dropdown.
- [x] **Devices** (`WA0056`) — title **"Active devices"**; show the raw **user-agent**;
      *"Last active … · Signed in N days ago"*; solid red **"Sign out of other devices"**;
      drop the per-device sign-out link.
- [x] **Notifications** (`WA0037`) — **absolute date** (`6/19/2026`) instead of relative;
      pale-pink circular icons; remove unread dots / mark-all-read / swipe-delete.

### 5.4 Cleanup
- [x] Delete `shared/widgets/placeholder_screen.dart` (unused).
- [x] Delete the unused `MockProfileRepository` (or keep as a documented test seam).
- [x] Reconcile `AppConstants.maxGalleryPhotos = 6` vs the real DB cap of **4**.
- [x] Remove the **Premium demo toggle** and the **Admin** screen (if Phase 0 says so).
- [x] Remove any now-dead `MockData` entries.

### 5.5 Final polish
- [x] Emoji in labels/copy throughout (💍 ✨ 🍳 ☕ 💃 🌍) to match the old app's tone.
- [x] Verify **dark mode** still looks right after all the token changes.
- [x] Side-by-side pass against **every** screenshot; log any remaining deltas.

**Phase 5 exit criteria:** analyze/test green; no lorem text anywhere; all 15 modals/screens
from `UI_GAP_ANALYSIS.md §15` either built or explicitly deferred with a reason.

---

## 🚧 KNOWN CONSTRAINTS (things UI work alone cannot fix)

These will make some screens *look* right but not *work* fully. Each is a backend gap
already tracked in `BACKEND_REMAINING.md`:

| Element | Blocked by |
|---|---|
| Account-expiry "36d" pill | **No account-expiry field exists** in `profiles` |
| Subscription "22d" pill | needs `premium_until` / `subscriptions` table **[BE-4]** |
| Real plan + "Gold Plan" label | `subscriptions` table **[BE-4]** |
| Discover multi-photo carousel | feed doesn't return other users' `profile_photos` |
| "10h ago" last-active | app never reads `user_presence` **[BE-1]** |
| Real distance / "Approx" badge | no GPS (`geolocator`), no server geo **[BE-9]** |
| Country counts in Explore | `get_country_counts` RPC missing **[BE-9]** |
| Report button / Safety Reports | **`reports` table does not exist** **[BE-5]** |
| Mute / Archive conversation | tables don't exist **[BE-11]** |
| ID Verification result | `verify-identity` edge fn missing **[BE-5]** |
| M-PESA checkout | `paystack-checkout` edge fn missing **[BE-4]** |
| Receipt PDF download | no such endpoint |
| Ringtone preview | needs audio assets + `audioplayers` |
| Real GPS location in header | needs `geolocator` |

**Rule:** when data is missing, **hide the element** — never fake a number.

---

## 📦 NEW PACKAGES LIKELY NEEDED

| Package | For | Phase |
|---|---|---|
| `audioplayers` | ringtone preview | 4 |
| `geolocator` + `permission_handler` | real location, distance, "Approx" | 2 (or defer) |
| `vibration` (or `HapticFeedback`) | vibrate-on-call setting | 4 |
| flag assets or `country_icons` | Explore country grid | 3 |
| `pdf` / `printing` | Download Receipt (PDF) | 4 (or defer) |

`shared_preferences` is **already installed** — use it for all device-local settings.

---

## 📁 FILES THIS PLAN WILL TOUCH (quick map)

**Phase 1:** `core/theme/*`, `shared/widgets/app_header.dart`, `bottom_nav.dart`,
`app_shell.dart`, `features/auth/auth_screen.dart`, `core/utils/validators.dart`
+ new: `gradient_button.dart`, `app_chip.dart`, `segmented_tabs.dart`, `sub_page_header.dart`

**Phase 2:** `features/discover/*` (screen, filters sheet, providers)

**Phase 3:** `features/profile/profile_screen.dart`, `features/likes/likes_screen.dart`,
`features/explore/explore_screen.dart` + new `shared/widgets/profile_preview_modal.dart`

**Phase 4:** `features/settings/settings_screen.dart`,
`features/subscription/subscription_screen.dart`, `features/messages/messages_screen.dart`,
`features/chat/chat_screen.dart`, `shared/models/subscription_plan.dart`,
`shared/data/mock_data.dart` + new verification + help/FAQ widgets

**Phase 5:** `features/legal/legal_screen.dart`, `features/delete_account/*`,
`features/devices/*`, `features/notifications/*`, various modals, dead-code removal

---

## ✅ DEFINITION OF DONE (whole project)

- Every screenshot in `old app ss/` has a visually-matching screen in the Flutter app.
- `flutter analyze` → no issues; `flutter test` → green; `flutter build apk` → success.
- No `_lorem` / placeholder copy anywhere.
- No faked data on screen (missing data = hidden element, logged as a backend gap).
- `developer.log`, `CLAUDE.md`, `UI_GAP_ANALYSIS.md` all updated.
