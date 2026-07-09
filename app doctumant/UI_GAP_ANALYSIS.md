# LoveMe — UI Gap Analysis: Old App (screenshots) vs Our Flutter Rebuild

> **Generated 2026-07-10.** Reviewed **all 52 files** in `app doctumant/old app ss/`
> (40 unique screens after de-duplicating identical files), then cross-read the
> full `lib/` source of our rebuild.
>
> **This document is a STRUCTURE / INVENTORY only.** No code has been changed.
> Its purpose is to let you decide what to build.
>
> **Legend**
> - 🔴 **MISSING** — exists in old app, not in ours at all
> - 🟠 **DIFFERENT** — exists in both, but ours looks/behaves differently
> - 🟡 **EXTRA** — exists in ours, NOT in the old app (candidate for removal)
> - ✅ **MATCHES** — close enough

---

## ⚠️ 0. Read this first — three findings that change project decisions

### 0.1 🎉 The plan-name question is ANSWERED
This has been an open blocker since day one. The old app's Subscription screen
(`WA0066`, `WA0032`, `WA0038`) shows the **definitive** plan list:

| Plan | Price | Profiles/month | Badge |
|---|---|---|---|
| **Basic+** | **$5**/mo | 500 | Silver |
| **Gold** | **$10**/mo | 1000 | Gold |
| **Platinum** | **$15**/mo | 1500 | Diamond |
| **Premium Elite** | **$20**/mo | 2000 | Crown 👑 |
| **VIP Elite** | **$25**/mo | Unlimited | VIP 💎 |

Plus a **Free** tier implied. This matches the **product roadmap**, NOT the backend
doc (Premium/VIP/Elite) and NOT our placeholder (Monthly/Quarterly/Yearly).
➡️ **Our `SubscriptionPlan` mock data is wrong and should be replaced with the above.**

### 0.2 ✍️ Two screenshots carry hand-drawn annotations
Someone marked these in blue pen — I'm reading them as instructions, but **please confirm**:
- `WA0038` — **"Upload Order Receipt Screenshot"** button is **crossed out with an X**.
  → I read this as: *remove the Wise-receipt-upload button.*
- `WA0050` / `WA0055` / `WA0060` — the header pills (**36d**, **22d**) and the **bell**
  are **circled**. → I read this as: *these are important / must be implemented.*

### 0.3 ❗ I removed things in Group A that the old app actually HAS
While wiring real notification preferences, I deleted **Sound** and **Vibration**
toggles because no DB column existed. But `WA0044`/`WA0049` show the old app **does**
have **"Vibrate on incoming call"** and a **Call Ringtone with preview**. Those are
**device-local settings**, not server settings — that's why there's no column.
➡️ **They should be restored as local (SharedPreferences) settings.** My call was wrong.

---

## 1. GLOBAL SHELL — Header & Bottom Navigation

### 1.1 App Header — 🔴 **COMPLETELY DIFFERENT**

**Old app** (`3`, `4`, `5`, `6`, `7`, `WA0027`, `WA0034`, `WA0045`…):
A rich, personalized, pink-gradient header present on **all 5 tabs**:

| Element | Detail |
|---|---|
| Avatar (left) | Circular, user's own photo, ~48px |
| Greeting | **"Hi, Flotiz"** — bold, large |
| Location line | 📍 **"Kabianga ward, Kenya"** — the user's actual GPS ward |
| Pill 1 | 📅 **"36d"** — days until *account expiry* (tap → modal, `WA0046`) |
| Pill 2 | 🕐 **"22d"** — days until *subscription renewal* (tap → modal, `WA0054`); tinted **orange** |
| Bell (right) | Circular translucent button → Notifications |

**Ours** (`app_header.dart`): a static gradient bar with the text **"Love Me"**,
optional actions. No avatar, no greeting, no location, no expiry pills, no personalization.
The bell only appears on the Discover tab.

**Gap:** 🔴 Avatar · 🔴 Greeting · 🔴 GPS location line · 🔴 Both countdown pills
· 🔴 Their tap-modals · 🟠 Bell should be on every tab.

### 1.2 Bottom Navigation — ✅ / 🟠

| | Old | Ours |
|---|---|---|
| Order | Discover · Likes · Messages · Explore · Profile | ✅ same |
| Icons | sparkles(+) · heart · speech-bubble · globe · person | 🟠 we use `compass` for Discover |
| Active state | Pink icon + pink label + **pink dot underneath** | 🟠 we have no dot |
| Badges | Red/pink count badge on Messages (**"2"**) | ✅ supported |
| Filled icons | Active tab's icon becomes **filled** (e.g. Likes heart) | 🔴 ours stays outline |

---

## 2. AUTH SCREEN — 🟠 Substantially different

**Old** (`WA0042` Login, `WA0047` Sign Up):

| Element | Old app | Ours |
|---|---|---|
| Container | **No card** — plain pink background, centered | 🟠 white `Card` with elevation |
| Logo | Pink gradient circle + white heart | ✅ same |
| Wordmark | **"LoveMe"** (one word) | 🟠 "Love Me" |
| Tagline | **"Find your perfect match"** | 🟠 "Find your someone" |
| Tabs | **"Login" / "Sign Up"**, square-ish, full-bleed segmented | 🟠 "Sign In"/"Sign Up", fully-rounded pills |
| Field labels | Separate **bold label above** each field | 🟠 we use Material floating labels |
| Password rule | **"Min 6 characters"** | ❗🟠 **we enforce 8** |
| Remember me | ✅ round pink checkbox (Login only) | ✅ has it (but non-functional) |
| **Confirm password** | 🔴 **NOT PRESENT** | 🟡 **we have it** |
| **DOB / Gender / Country at signup** | 🔴 **NOT PRESENT** | 🟡 **we collect all 3** |
| 18+ consent | Single checkbox w/ inline **Terms & Conditions** + **Privacy Policy** links | 🟠 ours is plain text, no links |
| **"Refresh" button** | ✅ present under the CTA (both tabs) | 🔴 missing |
| **Google sign-in** | 🔴 **NOT PRESENT** | 🟡 we have "Continue with Google" |
| Legal footer | 🔴 not present | 🟡 we have 4 links |
| Forgot password | Pink bold link (Login only) | ✅ has it |

➡️ **Their sign-up is far simpler**: email + password + 18-checkbox. Everything else
moves to onboarding. **We are over-collecting at signup.**

---

## 3. DISCOVER TAB — 🔴 The single biggest gap in the app

**Old** (`WA0034`, `WA0050`, `WA0055`, `WA0060`, `3`, `4`):

Above the card:
- 🔴 **Worldwide/radius selector chip** — yellow pill `🌍 (Worldwide) ⌄`
- 🔴 **Quota line** — "1000+ profiles/month" (left) + **"👑 Gold Plan"** (right, pink)
- 🔴 **Stale-location banner** — *"Your location is over a day old. Showing matches within a safer 25 km until you refresh."* + **Refresh** button

The profile card itself (dark, full-bleed photo, rounded ~20px):
| Element | Detail | Ours |
|---|---|---|
| **Photo carousel** | Segmented progress bars at top; ▶ arrow to advance | 🔴 single photo |
| **Side photo rail** | Right-edge circular thumbnails numbered **1 / 2 / 3**, active one ringed pink | 🔴 none |
| **Marital status chip** | Top-left dark pill `Marital Status: Single 💫` | 🔴 none |
| **Report button** | Top-left dark pill with red shield icon | 🔴 none |
| **Last-active pill** | Top-right `🔴 10h ago` | 🔴 none |
| Name, age | `Gayle, 18` — very large, white | ✅ similar |
| Location | 📍 `Nairobi, Kenya` | ✅ (we show city, country) |
| **Distance chip** | Pink pill `215 km (134 mi) away` — **both units** | 🟠 ours: `21 km`, top-left, km only |
| **"Approx" badge** | Yellow pill 📡 `Approx` (imprecise GPS) | 🔴 none |
| Relationship goal | `Need a serious relationship 💍` | 🔴 not on card |
| **Tag chips** | Multi-colour: `✨Straight` (yellow) · `👁 Likes men` (pink) · `Travel Enthusiast ✈️` (grey) · `Music 🎵` · `Cooking 🍳` | 🔴 none |
| **"Show more ⌄"** | Yellow pill expanding more details | 🔴 none |
| Bio | not shown on card | 🟡 we show bio |
| Online dot | — | 🟡 we show one |
| Verified badge | — | 🟡 we show one |

**Action buttons — 🟠 different set, colours, and shape:**

| Old (4 large solid circles) | Ours |
|---|---|
| ⚪ **X** (white bg, grey X) — Pass | grey outline X |
| 🟡 **★** (yellow) — Super Like | gold outline star |
| 🟢 **💬** (green) — Message | purple outline chat |
| 🩷 **♥** (pink) — Like | pink outline heart |

Old = **filled solid colour circles**. Ours = white circles with a coloured *border*
and coloured icon, plus a **text label beneath each** (old has no labels).
Also: old Like/Pass order is **X, ★, 💬, ♥** — ours is **X, ★, ♥, 💬** (heart & chat swapped).

**Other Discover gaps:**
- 🔴 **No swipe gestures** in ours (buttons only). Old app implies swipe.
- 🔴 **Search-radius bottom sheet** (`4`, `WA0030`): Worldwide toggle, big `50 km`
  readout, slider (5–5000 km), **9 preset chips** (5/10/25/50/100/250/500/1000/2500/5000),
  **"Apply worldwide"** CTA. Ours: a generic filters sheet (age/distance/gender/toggles).
- 🔴 **"Find people nearby" location-permission modal** (`3`) — pink pin icon,
  explanatory copy, **"Enable Now"** gradient CTA.
- 🔴 **"Get Verified" promo modal** (`WA0041`) — shield, *"Verified profiles get
  discovered more easily…"*, **Verify Now 🛡** / **Maybe Later**.

---

## 4. LIKES TAB — 🔴 Completely different concept

**Old** (`5`, `8`):
- Title **"People Who Like You"** + subtitle **"Viewing all 3 likes"**
- A **plan banner**: `👑 Gold` (pink rounded bar)
- A **vertical LIST** of likers: circular avatar · **Name** · location (grey) · **age** · `›` chevron
- Tap → **profile preview modal** (`8`): `Flotz Jnr, 38` · large circular photo ·
  📍 location · ♥ `Need a serious relationship 💍` · interest chips · **[Close]** **[Message 💬]**

**Ours**: two Material tabs ("Liked You" / "Matches"), a 2-column **blurred grid**
with a premium "Unlock" CTA.

| Gap | |
|---|---|
| 🔴 | List layout (we use a grid) |
| 🔴 | "People Who Like You" heading + "Viewing all N likes" |
| 🔴 | Plan banner |
| 🔴 | Profile-preview modal (**reused in Explore too**) |
| 🔴 | Age shown as a plain number at the right |
| 🟡 | **We have a "Matches" tab — old app has NO matches tab here** |
| 🟡 | We blur non-premium likes; old app shows them plainly (gating is by plan quota instead) |

---

## 5. MESSAGES TAB — 🟠 Different chrome, same idea

**Old** (`6`, `7`, `WA0028`):
- Big black title **"Messages and Calls"**
- 🔴 **Segmented pill switcher** (rounded container, active pill = white/raised):
  `Chats (1)` with a **pink count badge** · `Calls`
- 🔴 **Search field** — rounded, white, magnifier icon, *"Search conversations…"*
- Conversation rows are **elevated white cards** with margin between them, 3 lines:
  1. **Name** (bold)
  2. `Last seen 11d ago` (grey)
  3. Last message preview (with emoji)
  - Right: relative time (`3d`)
  - Avatar has a **red offline dot** (bottom-right)
- 🔴 **Inline action row** (`WA0028`): tapping/long-pressing expands the row into
  **Mute 🔕 · Archive 🗄 · Delete 🗑** circular buttons + an `✕` to dismiss

**Calls tab** (`6`): 3D phone emoji, **"No calls yet"**, *"Start a voice or video call from any chat"*

| Gap | |
|---|---|
| 🟠 | We use a Material `TabBar`, not segmented pills; no count badge on the tab |
| 🟠 | Our rows are flat `ListTile`s, not elevated cards |
| 🔴 | **"Last seen Xd ago"** line |
| 🔴 | Offline/online **dot on the avatar** |
| 🟠 | We use swipe-to-delete (`flutter_slidable`); old uses an **inline expanding action row** |
| 🔴 | **Mute** and **Archive** actions |
| 🔴 | Unread count badge on the "Chats" pill |
| 🟠 | Our empty-call state says "No calls yet." but lacks the subtitle + 3D emoji |
| ✅ | Search exists in both |

---

## 6. CHAT SCREEN — 🟠 Many missing affordances

**Old** (`9`, `10`, `11`):

**Header** (pink gradient): `←` circular back · avatar w/ **red offline dot** ·
**Name** + **"Offline"** status · 3 circular translucent buttons: **📞 phone**,
**🎥 video**, **🛡 shield (report/block)**

| Element | Old | Ours |
|---|---|---|
| **Date separator** | Grey pill: `Friday, Jul 3, 2026` | 🔴 none |
| Own bubble | Solid pink, white text, rounded ~16 | ✅ close |
| Timestamp | `05:21 AM` + ✓ inside bubble, right-aligned | ✅ close |
| **Reaction affordance** | A small circular **`+`** button attached to the bubble's edge | 🔴 we long-press |
| **Reaction picker** | Inline **white card, 20 emojis**, 3 rows, anchored to the bubble | 🟠 ours: **bottom sheet, 6 emojis** |
| **Composer** | Left: 🖼 **image** button + 📎 **attach** button (2 separate circles) | 🟠 ours: 1 paperclip |
| | Middle: rounded field with **😊 emoji icon inside**, `Type a message...` | 🟠 ours: emoji is a separate icon (and is a **no-op**) |
| | Right: **pink gradient circular 🎤 mic FAB** | 🟠 ours: plain icon button |
| **Safety menu** | 🛡 opens modal (`11`): title w/ shield + name, **"Block X"** (won't see or contact you) and **"Report & Block"** (report inappropriate behaviour and block), each a bordered card | 🟠 ours: plain bottom sheet w/ Block/Report **no-op** `ListTile`s |
| Media bubbles | (not shown in screenshots) | ✅ we now render image/video/audio |

---

## 7. EXPLORE TAB — 🔴 Very different

**Old** (`WA0027`, `WA0043`, `WA0035`):
- Title **"Explore"**, subtitle *"Discover people worldwide"*
- 🌐 **"Browse by Country"** section header
- 🔴 **Search field** — *"Search countries…"*
- 🔴 **3-column grid of ALL countries** (alphabetical: Afghanistan, Albania, Algeria,
  Andorra, Angola, Antigua and Barbuda, Argentina, Armenia, Australia…), each a
  white rounded card: **flag image** · **country name** · **user count** (`0`, `2`, `1`)
- Tap a country → 🔴 **modal** (`WA0043`): flag + `Algeria` + `(2 users)` + a **list**
  of users (avatar · name · location · age · `›`) + `✕`
- Tap a user → the same **profile-preview modal** as Likes (`WA0035`)

**Ours**: a horizontal strip of **8 hardcoded** country chips (emoji flag + name + fake
count) and a 2-column profile **grid** below; tapping a profile opens **chat**.

| Gap | |
|---|---|
| 🔴 | Search countries |
| 🔴 | Full country list (all ~195), alphabetical |
| 🟠 | 3-col grid of cards vs our horizontal chips |
| 🟠 | Real flag **images** vs our emoji |
| 🔴 | Country → user-list **modal** (we push a full screen) |
| 🔴 | Profile-preview modal (we go straight to chat) |
| 🟠 | Title + subtitle + "Browse by Country" header |

---

## 8. PROFILE TAB — 🔴 Very different

**Old** (`WA0045`, `WA0053`):
- 🔴 A single **white rounded card** containing:
  - Circular avatar (pink ring) with a **pink camera FAB** bottom-right
  - `Flotiz, 31` (large bold, **black text**)
  - 📍 `Kabianga ward, Kenya`
  - Pink outline pill: 🧭 **"Location is on"**
  - Pink outline pill: 👑 **"Gold Active · 22d left"**
  - ♥ `In need of a sponsor 💰` (relationship goal)
  - Tag chips: `✨Straight` (yellow) · `👁 Interested in both` · `Cooking 🍳` · `Coffee Lover ☕` · `Dancing 💃`
  - **✏️ pencil edit FAB** top-right of the card
- 🔴 **"Manage Plan"** — big **pink→orange gradient** card: 👑 icon · "Manage Plan" ·
  "Current Plan: Gold" · right: "Expires 28 Jul 2026" `›`
- Then only **3 rows**: ⚙️ **Settings** · 🚩 **My Safety Reports** · 🚪 **Log Out** (red)

**Ours**: a pink **gradient banner** (white text) + **stats row (Views/Likes/Matches)**
+ Edit Profile button + upgrade card + bio + photo gallery grid + **Premium demo toggle**
+ 5 nav rows (Settings, Notifications, Devices, Safety, Subscription) + Log out + Delete.

| Gap | |
|---|---|
| 🔴 | White card treatment (ours is a gradient banner) |
| 🔴 | "Location is on" pill |
| 🔴 | "Gold Active · 22d left" pill |
| 🔴 | Relationship-goal line + **tag chips** on profile |
| 🔴 | Gradient **"Manage Plan"** card with expiry date |
| 🔴 | Edit **pencil FAB** on the card (ours is a full-width button) |
| 🟡 | **Stats row (Views/Likes/Matches) — old app has NONE** |
| 🟡 | **Photo gallery grid — not on old app's profile** |
| 🟡 | **Premium demo toggle** (must be deleted before production) |
| 🟡 | Bio text block |
| 🟡 | Notifications / Devices / Subscription nav rows (old app nests these in Settings) |
| 🟠 | "Log Out" is red text w/ icon; ours is an outlined button |
| 🟠 | Delete account lives in **Settings** in old app, not on Profile |

---

## 9. SUBSCRIPTION / PLANS — 🔴 Wrong data, different layout

**Old** (`WA0066`, `WA0032`, `WA0038`):
- Second-level pink header: `←` **"Choose Your Plan"**
- 👑 **"Unlock Premium"** centered title
- Plan rows (full-width rounded cards, **not** our bordered selection cards):
  - Left: **Plan name** (bold) · `N profiles` (grey) · a coloured **tier badge**
    (Silver / Gold / Diamond / Crown 👑 / VIP 💎)
  - Right: ⓘ info button + **`$10`**`/mo`
  - The **current** plan is highlighted: peach fill, **green border**, and a floating
    green **"✓ CURRENT"** ribbon on top
- Below: a green-bordered banner: 🟢 **"You're Currently on this Gold Plan"** 🟢 ·
  *"Renews Jul 28, 2026 · 22 days left"*
- **"Checkout Section/Billing ⌄"** expander
- 🟢 **"Pay with M-PESA / Airtel Money"** (green bordered button, real M-PESA logo)
- 🚫 **"Upload Order Receipt Screenshot"** — dashed yellow button, **CROSSED OUT in pen**
- Footer: *"Made with ♥ By Randy"*

**Ours**: "Go Premium" · perks hero · **Monthly/Quarterly/Yearly** cards ·
4 pay buttons (Paystack/PayPal/Wise/Google Play) · usage progress bars.

| Gap | |
|---|---|
| 🔴🔴 | **Plan names & prices are wrong** (see §0.1) |
| 🔴 | Profile-count limits per plan |
| 🔴 | Tier badges (Silver/Gold/Diamond/Crown/VIP) |
| 🔴 | "✓ CURRENT" ribbon + green highlight on active plan |
| 🔴 | ⓘ info button per plan |
| 🔴 | "You're currently on…" renewal banner |
| 🔴 | "Checkout Section/Billing" expander |
| 🔴 | **M-PESA / Airtel Money** button (with logo) |
| 🔴 | "Made with ♥ By Randy" footer |
| 🟡 | Our perks hero, usage bars, PayPal/Wise/Play buttons — not in old app |
| ❓ | Wise receipt upload — **crossed out**, confirm removal |

---

## 10. NOTIFICATIONS — 🟠 Simpler in old app

**Old** (`WA0037`): second-level pink header `←` **"Notifications"**. A flat list:
circular pastel-pink icon (chat bubble / heart) · **bold title with emoji**
(`💬 New Message`, `🎉 It's a Match!`, `❤️ New Like!`, `Flotz Jnr sent you a message 💬`)
· grey body · **absolute date `6/19/2026`**.

| Gap | |
|---|---|
| 🟠 | Old shows **absolute date**; ours shows relative ("3h") |
| 🟡 | We have **unread dots** — old app has none |
| 🟡 | We have **"Mark all read"** — old app has none |
| 🟡 | We have **swipe-to-delete** — old app has none |
| 🟠 | Icon backgrounds are pale pink circles; ours are tinted by type |

---

## 11. SETTINGS — 🔴 Completely different structure

**Old** (`WA0031`, `WA0049`, `WA0044`, `WA0029`, `WA0036`, `WA0039`, `WA0064`):
A **stack of white rounded cards**, each a section. Header: `←` **"Settings"**.

| Card | Contents | Ours |
|---|---|---|
| 👑 **Subscription** | `Gold — $10.00 USD / 30 days`, `Active until 7/28/2026`, **"⬇ Download Receipt (PDF)"** gradient button | 🔴 **missing entirely** |
| ☀️ **Appearance** | **Dark Mode** toggle · **"Remember email after inactivity logout"** toggle | 🟠 we have Dark Mode only |
| 🧭 **Location Settings** | 🟢 "Location enabled" · **Discovery Distance: 🌍 Worldwide** · **Worldwide** toggle | 🟠 ours: age/distance sliders + "Show me" |
| 🔔 **Push Notifications** | **ONE** toggle: **"Background Alerts"** — *"Get notified about likes & messages even when the app is closed"* | ❗🟠 **ours has 8 toggles** |
| 🎵 **Call Ringtone** | Dropdown (Classic / Modern / Marimba, **each with a description**) + **▶ preview play button** | 🟠 ours: plain 3-item dropdown, no descriptions, no preview |
| 📳 **Vibration** | **"Vibrate on incoming call"** toggle | ❗🔴 **I deleted this in Group A** |
| 🛡 **Verification** | Expandable. `Not verified ⌄`. Choose doc type: **National ID · Passport · Birth Certificate · Driving License** → **Step 1 of 2: Upload National ID** (dashed upload zone) → selfie step | 🔴 **missing entirely** |
| ❓ **Help & Support** | Expandable. **FAQ** (5 Q&As) · **Contact Us** (email + **"Chat on Google Chat"**) · **Safety Tips** (5 bullets) | 🔴 **missing entirely** |
| 🗑 **Delete Account** | Row → separate screen | 🟠 we have it on Profile too |

**Ours**: a flat `ListView` with plain text section headers, sliders, and switches.
Missing: Subscription card, Receipt PDF, Remember-email, Worldwide toggle, Verification,
Help & Support, ringtone previews, vibration.

---

## 12. DEVICES / ACTIVE SESSIONS — 🟠 Close

**Old** (`WA0056`): header **"Active devices"** (solid pink). Copy: *"Only one device
can be signed in at a time. If you suspect someone else has access, sign out of other
devices below."* One white card: 📱 icon · **Android** + pink **"✓ This device"** badge ·
truncated **user-agent string** · *"Last active just now · Signed in 7 days ago"*.
Then a **solid red "Sign out of other devices"** button.

| Gap | |
|---|---|
| 🟠 | Title "Active devices" vs our "Devices" |
| 🔴 | Raw **user-agent** shown as the subtitle |
| 🔴 | "Signed in N days ago" (we show only last-active) |
| 🟠 | Their button is **solid red**; ours is outlined |
| 🟡 | We have a per-device "Sign out" link (old app has none — only "sign out of others") |

---

## 13. DELETE ACCOUNT — 🟠 Much simpler in old app

**Old** (`WA0062`): plain **white** header (not pink!) `←` "Delete Account".
One pink card: 🗑 **"Danger Zone"** (red) · *"Permanently delete your account and all
associated data. This action **cannot be undone**."* · **"This will permanently remove:"**
5 bullets (profile/photos/info · matches & conversations · likes & interactions ·
subscription & payment history · notifications & preferences) · solid red
**"Delete My Account"** button.

| Gap | |
|---|---|
| 🔴 | "Danger Zone" card + the 5-bullet list |
| 🟠 | Header is white, not pink |
| 🟡 | We require **password** — old app does not |
| 🟡 | We require typing **"DELETE"** — old app does not |
| 🟡 | We have a **reason dropdown** — old app does not |

---

## 14. LEGAL SCREENS — 🔴 We have lorem; they have real text

**Old**:
- `WA0061` **"Privacy & Terms"** hub: shield title, *"Last updated: 19th March 2026"*,
  two link cards (**Terms & Conditions**, **Refund Policy**), then real prose sections:
  **Age Requirement** (18+, red highlight), **Voluntary Use**, **🚫 Explicit Content &
  Nudity Policy**…
- `WA0063` **"Terms & Conditions"**: numbered sections (1. Acceptance · 2. Eligibility &
  Age · 3. Account Registration & Security · 4. User Conduct…) with real legal copy.
- `WA0051` **"Child Safety Standards"**: 🚩 solid-red **"Report CSAM / Child Safety
  Concern"** button at top; the full **Google Play CSAE compliance statement** naming
  the developer (**The Orbit Devs**) and the Play listing URL
  (`com.loveme.intldating`); two footer buttons: **Child Safety Statement** · **Privacy Policy**.

| Gap | |
|---|---|
| 🔴🔴 | **All our legal copy is `_lorem` placeholder** — this is a **Play Store launch blocker** |
| 🔴 | "Privacy & Terms" combined hub screen |
| 🔴 | **"Report CSAM / Child Safety Concern"** button |
| 🔴 | Google Play CSAE compliance statement (developer name + listing URL) |
| 🟠 | Ours are 4 separate flat routes; theirs is a hub + sub-pages |

---

## 15. SCREENS / MODALS THE OLD APP HAS THAT WE DON'T (at all)

| # | Screen / Modal | Screenshot | Notes |
|---|---|---|---|
| 1 | **Profile preview modal** | `8`, `WA0035` | Reused from **Likes** and **Explore**. Name+age, photo, location, goal, chips, Close/Message |
| 2 | **Country user-list modal** | `WA0043` | flag + name + "(N users)" + user list |
| 3 | **Search-radius sheet** | `4`, `WA0030` | Worldwide toggle, slider, 9 preset chips, "Apply worldwide" |
| 4 | **"Find people nearby" permission modal** | `3` | Pin icon, instructions, "Enable Now" |
| 5 | **"Get Verified" promo modal** | `WA0041` | Shield, Verify Now / Maybe Later |
| 6 | **Account-expiry modal (36d)** | `WA0046` | Calendar icon, 90-day resignup explanation, "Got it" |
| 7 | **Subscription-expiry modal (22d)** | `WA0054` | Clock icon, exact renewal datetime, "Got it" / "Close" |
| 8 | **Chat safety modal** | `11` | Block X · Report & Block |
| 9 | **Inline reaction picker** | `10` | 20 emojis, white card, anchored to bubble |
| 10 | **Chat row action strip** | `WA0028` | Mute / Archive / Delete |
| 11 | **ID Verification flow** | `WA0029`, `WA0044` | 4 doc types → upload → selfie |
| 12 | **Help & Support (FAQ)** | `WA0036`, `WA0064` | FAQ, Contact, Google Chat, Safety Tips |
| 13 | **Stale-location banner** | `3` | "Your location is over a day old… Refresh" |
| 14 | **Child Safety Standards page** | `WA0051` | With CSAM report button |
| 15 | **Privacy & Terms hub** | `WA0061` | |

---

## 16. THINGS **WE** HAVE THAT THE OLD APP DOES **NOT** (removal candidates)

| # | Ours | Recommendation |
|---|---|---|
| 1 | **Matches tab** in Likes | Old app has no matches list — confirm intent |
| 2 | **Blurred premium grid** on Liked-You | Old shows a plain list |
| 3 | **Stats row** (Views/Likes/Matches) on Profile | Not in old app |
| 4 | **Photo gallery grid** on Profile | Not in old app |
| 5 | **Premium demo toggle** | ❗ Must be removed before production |
| 6 | **Admin Diagnostics screen** | Not in any screenshot |
| 7 | **Confirm-password** field at signup | Not in old app |
| 8 | **DOB / Gender / Country** at signup | Old app collects in onboarding |
| 9 | **Google sign-in** button | Not in old app |
| 10 | **Legal footer links** on auth | Not in old app |
| 11 | **Password ≥ 8 chars** | Old app: **6** |
| 12 | **Delete-account password + type-"DELETE" + reason** | Old app has none |
| 13 | **Unread dots / Mark-all-read / swipe-delete** on Notifications | Not in old app |
| 14 | **Notifications / Devices / Subscription** rows on Profile | Old nests these in Settings |
| 15 | **8 notification-preference toggles** | Old app: **1** ("Background Alerts") |
| 16 | **Bio** on Discover card | Not on old card |
| 17 | **Compass icon** for Discover tab | Old uses sparkles-plus |

---

## 17. DESIGN-SYSTEM DELTAS (global)

| Token / pattern | Old app | Ours |
|---|---|---|
| **Page background** | Very light pink **`#FDEEF4`**-ish everywhere | White / theme surface |
| **Primary pink** | Hot pink `#FF1F8E`-ish (more saturated) | `#E6287A` |
| **Gradients** | Pink→lighter-pink header; pink→**orange** on Manage Plan | header only |
| **Cards** | White, **large radius (~20px)**, soft shadow, generous margins | radius 16, flatter |
| **Buttons** | **Gradient fills** + soft glow shadow, fully rounded | flat Material `FilledButton` |
| **Chips/pills** | Heavy use; **multi-colour** (yellow/pink/grey), emoji suffixes | few, monochrome |
| **Emoji** | Used liberally in labels & copy (💍 ✨ 🍳 ☕ 💃 🌍) | almost none |
| **Toggles** | Large, pink-filled iOS-style | Material default |
| **Tabs** | Segmented pill container | Material `TabBar` w/ underline |
| **Second-level headers** | Pink gradient + circular translucent back button | Material `AppBar` |
| **Dark mode** | Supported (a toggle exists) | ✅ supported |

---

## 18. SUGGESTED PRIORITY (my recommendation)

**P0 — decisions / blockers**
1. Confirm the **pen annotations** (§0.2).
2. Adopt the **real plan names & prices** (§0.1) — unblocks all payment work.
3. Get the **real legal copy** (Terms, Privacy, Refund, Child Safety) — Play blocker.
4. Restore **Vibration + Ringtone preview** as local settings (§0.3).

**P1 — highest visual impact, seen on every screen**
5. **App header** (avatar, greeting, location, 36d/22d pills, bell).
6. **Discover card** rebuild (carousel, thumbnails, chips, Report, Approx, last-active, Show more, 4 solid FABs).
7. **Bottom nav** polish (filled active icon, active dot, sparkles icon).
8. **Global background colour** + card radius/shadow + gradient buttons.

**P2 — screen restructures**
9. **Profile** → white card + Manage Plan gradient card + 3 rows.
10. **Likes** → list + profile-preview modal.
11. **Explore** → search + full country grid + country modal + preview modal.
12. **Settings** → card sections + Subscription card + Verification + Help & Support.
13. **Messages** → pill tabs, card rows, "last seen", inline Mute/Archive/Delete.
14. **Subscription** → tier badges, CURRENT ribbon, M-PESA, renewal banner.

**P3 — chat & extras**
15. Chat: date separators, inline 20-emoji picker, `+` reaction button, split image/attach, mic FAB, safety modal.
16. Search-radius sheet, location-permission modal, expiry modals, Get-Verified modal.
17. ID verification flow, Help & Support/FAQ.
18. Delete Account simplification, Devices polish, Notifications simplification.

---

## 19. Coverage note

Reviewed **every** file in the folder. 52 files → **40 unique** screens
(12 were byte-identical duplicates, e.g. `4.jpeg` ≡ `WA0030.jpg`).
No screenshot was skipped.

**Screens the old app has that were NOT in the screenshots** (so I cannot compare):
onboarding/profile-setup wizard, matches list, forgot-password flow, email verification,
reset password, 404, admin, and the in-call / incoming-call UI. If those exist, please
share screenshots and I'll extend this document.
