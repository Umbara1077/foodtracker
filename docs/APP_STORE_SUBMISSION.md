# App Store submission checklist

Engineering compliance through **Phase 34** is in the app binary. This page is what **you** must finish in App Store Connect, Developer, and legal before approval.

Current tip: **1.5.4** (build 39) on `cursor/project-plate-phase-39-copy-day-fc9b`.

## Already handled in the app

| Requirement | Where |
|-------------|--------|
| Auto-renew disclosures, price/period, Restore, Manage subscription | Paywall + Settings |
| Privacy Policy + Terms in-app (and web Links when URLs are set) | Settings, Paywall, consent sheet |
| Camera / Mic / Speech / HealthKit purpose strings | `project.yml` Info keys |
| Cloud AI consent Accept/Decline persisted; Decline → on-device analysis only | `CloudAIConsentStore` + vision router |
| Meal photos re-encoded (EXIF/GPS stripped); not saved in the diary | Encoder + privacy copy |
| Export / Delete local data; Delete also uploads iCloud tombstones when sync is on | Settings → Privacy |
| Medical disclaimer | Onboarding, About, Terms |
| No account system → no account-deletion / Sign in with Apple obligation | N/A |
| No ATT / IDFA SDKs | Analytics is local/no-op |
| Privacy Manifest (`PrivacyInfo.xcprivacy`) | UserDefaults CA92.1 + declared data types |
| `ITSAppUsesNonExemptEncryption = false` | HTTPS-only standard encryption |
| Support entry point | Settings → About (uses `PLATE_SUPPORT_URL`) |
| Beta tools hidden on App Store builds | Shown only Debug / TestFlight |
| Custom AI gateway (HTTPS + Keychain token) | Settings → Cloud AI → Custom gateway |
| Optional meal reminders (permission after enable) | Settings → Reminders |
| Diary export JSON + CSV | Settings → Privacy |

## You must do (blocks approval)

### 1. Legal hosts (hard blocker)

1. Publish live **Privacy Policy** and **Terms of Use** on https hosts you control.
2. Set Archive / Release Info keys (Xcode target or `project.yml`):
   - `PLATE_PRIVACY_POLICY_URL`
   - `PLATE_TERMS_URL`
   - `PLATE_SUPPORT_URL` (https support page **or** `mailto:you@domain`)
3. Paste the same Privacy Policy URL into App Store Connect → App Privacy / App Information.
4. Have counsel review the in-app + web copy (AI gateway, OpenAI/vendor retention, HealthKit, iCloud).

Until those keys are set, paywall uses **in-app** Privacy/Terms screens (not `example.com`). App Store Connect still requires a real public Privacy Policy URL.

### 2. App Store Connect — In-App Purchases

- Subscription group with:
  - `com.projectplate.pro.monthly`
  - `com.projectplate.pro.annual`
- Localized display names/descriptions, pricing, review screenshot of the paywall
- Paid Apps Agreement + banking/tax active

### 3. Signing & capabilities

- Development Team on App, Widget, Watch
- App ID capabilities: HealthKit, App Groups (`group.com.projectplate.app`), iCloud/CloudKit (`iCloud.com.projectplate.app`), Push/Live Activities as configured
- Create the CloudKit container in the Developer portal

### 4. Listing & review package

- [ ] Age rating questionnaire (health/diet; no social UGC)
- [ ] App Privacy nutrition labels (match `PrivacyInfo.xcprivacy` + real practices)
- [ ] Screenshots + description **without medical claims**; include estimate disclaimer
- [ ] Support URL matching in-app Support
- [ ] Export compliance: standard encryption only (Info.plist already declares non-exempt = NO)
- [ ] Review notes (suggested text below)
- [ ] Brand / trademark / display-name clearance (“Project Plate” is still a working title in docs)

### 5. Merge & ship

1. Merge phase PRs oldest → newest (`docs/TESTFLIGHT.md`).
2. Archive from `main`.
3. Internal TestFlight → External → Submit for Review.

## Suggested App Review notes

```
Project Plate is local-first nutrition tracking. No user accounts.

Free: manual search, barcode, quick add, diary/history, limited AI meal scans.
Pro (StoreKit): com.projectplate.pro.monthly / .annual — unlocks unlimited AI scans.
Restore: Settings → Subscription → Restore purchases, or on the paywall.
Manage: Settings → Manage subscription (or paywall).

Cloud AI: optional. First scan shows consent. Decline keeps on-device analysis;
photos are not uploaded. Accept sends a compressed JPEG (re-encoded, no EXIF/GPS)
to our managed gateway for recognition; we do not permanently store standard scan photos.

Demo: Search “chicken” or Quick Add works offline. Photo scan works with the
on-device mock when PLATE_API_BASE_URL is empty. HealthKit and iCloud sync are
optional toggles in Settings.
```

## Sanity commands

```bash
./scripts/release-checklist.sh
./scripts/ci-ios.sh   # on macOS
```
