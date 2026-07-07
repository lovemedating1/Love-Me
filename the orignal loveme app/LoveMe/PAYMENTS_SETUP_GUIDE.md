# LoveMe – Google Play Billing: Payments & Payout Setup Guide

**Prepared for:** Client / App Owner
**App:** LoveMe International Dating (`com.loveme.intldating`)
**Purpose:** Steps the app owner must complete in Google Play Console so the app can sell premium subscriptions and receive the earnings into a bank account.

---

## 1. What has already been done (by the development team)

The technical integration is **complete**. The app now supports **Google Play Billing**, which lets users buy premium plans by paying with the **cards saved on their Google account** (Visa / Mastercard / supported local methods). Google processes the card payment — no Stripe or third‑party processor is required.

Already in place:

- ✅ The Android app (version 20) supports in‑app subscriptions and is uploaded to Google Play.
- ✅ The 5 premium plans are created and **Active** in Play Console:

  | Plan | Product ID | Price |
  |------|-----------|-------|
  | Basic+ | `basic_plus_monthly` | $5 / month |
  | Gold | `gold_monthly` | $10 / month |
  | Platinum | `platinum_monthly` | $15 / month |
  | Premium Elite | `premium_elite_monthly` | $20 / month |
  | VIP Elite | `vip_elite_monthly` | $25 / month |

- ✅ Purchases are securely verified on the server before premium is granted.

**What remains is on the account/business side — only the app owner can complete it**, because it requires the owner's identity, bank details, and tax information.

---

## 2. What the app owner must do

There are **three** things to enable so the app can take real payments and pay out earnings:

1. Set up the **Payments profile** (bank account + tax + identity).
2. Make the app **available for purchase** (move to Production once testing is approved).
3. Understand **how and when payouts arrive**.

---

### STEP 1 — Set up the Payments Profile (REQUIRED before any payout)

Google can only send money once a payments profile with bank details exists.

1. Go to **play.google.com/console** and sign in.
2. Open **Settings → Payments profile**.
3. Create / complete the payments profile by adding:
   - **Legal name** (person or business) exactly as on the bank account.
   - **Address** and contact details.
   - **Bank account details** for payout:
     - Bank name
     - Account number
     - SWIFT / BIC code
     - Branch details (as requested)
   - **Tax information** (Google will prompt for the required forms based on country).
4. Save and submit. Google may take a short time to verify the details.

> ⚠️ **Important:** Until this is completed, earnings will accumulate but **cannot be paid out**. Set this up before the app goes live with real users.

---

### STEP 2 — Make the app available for purchase (Production)

The app is currently on a **testing track**. Test purchases are **free** and do **not** generate real income (this is intentional and used only for verification).

To start earning from real users:

1. Go to **Play Console → Test and release → Production**.
2. Create a release with the latest app build (version 20 or newer).
3. Complete any pending store‑listing / policy items Google requests (content rating, data safety, target audience, etc.).
4. Submit for review and roll out to Production.

Once live on Production, real users can subscribe with their real cards, and those purchases generate real earnings.

---

### STEP 3 — How earnings work and how payouts reach the bank

**Where to see earnings:**

| What you want to see | Where in Play Console |
|----------------------|------------------------|
| Quick revenue overview | Dashboard → **Monetize with Play** card |
| Detailed earnings reports | **Download reports → Financial reports** |
| Payout history (money sent to bank) | **Settings → Payments profile → Payments / Transactions** |

**How payouts work (automatic — no manual withdrawal):**

1. Google collects the subscription payments from users and handles card processing, refunds, and taxes.
2. Google deducts its **service fee** (currently **15%** on auto‑renewing subscriptions).
3. Your share (~85%) accumulates through the month.
4. **Around the 15th of each month**, Google automatically deposits the previous month's earnings into the bank account on file — **provided the balance is above the minimum payout threshold** for your currency/country.

There is **no "withdraw" button** — once the bank account is set up, payouts happen automatically every month.

**Currency:** Users pay in their local currency; Google converts and pays out in the currency set in the payments profile.

---

## 3. Quick checklist for the app owner

- [ ] **Payments profile** created in **Settings → Payments profile**
- [ ] **Bank account** added (name, account number, SWIFT/BIC)
- [ ] **Tax information** completed
- [ ] App released to **Production** (after testing approval)
- [ ] Store‑listing / policy requirements completed (content rating, data safety, etc.)
- [ ] Confirm earnings appear under **Monetize with Play** once real sales begin

---

## 4. Notes

- **Test vs. real money:** Purchases made by test accounts are free and will not appear as earnings. Real earnings begin only after the app is live on Production and real users subscribe.
- **First payout may be delayed:** Google verifies new payment/tax details, and a first payout can be held until verification completes and the payout threshold is reached.
- **Refunds & cancellations:** Google handles user refunds and subscription cancellations automatically; these are reflected in the financial reports.
- **Service fee:** Google's standard fee on subscriptions is 15%; the remaining amount is paid to the owner.

---

*For any questions about the technical side (the app, purchase flow, or premium activation), contact the development team. For payments, bank, and tax questions, the **Payments profile** section in Play Console and Google Play support are the authoritative sources.*
