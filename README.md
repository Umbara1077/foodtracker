# Project Plate

**Working title** for a native **iPhone** (iPad + Apple Watch) AI photo calorie & macro tracker.

> Do **not** ship under the name “Project Plate” without App Store, trademark, domain, and social-handle clearance.

| | |
|--|--|
| **Canonical branch** | `main` only — do **not** open stacked phase PRs |
| **Marketing version** | **1.5.10** |
| **Build** | **45** |
| **Platform** | iOS 18+ / watchOS 11+ · Swift 5.10 · SwiftUI · SwiftData |
| **Bundle ID** | `com.projectplate.app` (+ `.widget` / `.watchkitapp`) |
| **Product thesis** | Photograph a meal → honest nutrition estimate → one-tap corrections → log in seconds |
| **CI** | GitHub Actions: `iOS` (macOS) + `Backend` (Node/Worker tests) |

> **Never used Xcode before?** Go straight to **[`docs/RUN_ON_MAC.md`](docs/RUN_ON_MAC.md)** — install Xcode, run
> `./scripts/mac-setup.sh`, press ▶. Note there is **no `.xcodeproj` in this repo**;
> it is generated from [`project.yml`](project.yml), so run the script before looking for one.

### Source-of-truth docs

| Doc | Purpose |
|-----|---------|
| [`docs/RUN_ON_MAC.md`](docs/RUN_ON_MAC.md) | **Start here if you are new to Xcode** — step-by-step build & run on a Mac |
| [`docs/PRODUCT_SPEC.md`](docs/PRODUCT_SPEC.md) | Full product, design, and engineering specification |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Layered client architecture notes |
| [`docs/TESTFLIGHT.md`](docs/TESTFLIGHT.md) | TestFlight / Archive handoff |
| [`docs/APP_STORE_SUBMISSION.md`](docs/APP_STORE_SUBMISSION.md) | Human App Store Connect / legal checklist |
| [`backend/README.md`](backend/README.md) | Managed Cloudflare Worker AI gateway |

---

## Table of contents

1. [What this app is](#1-what-this-app-is)
2. [What works today vs what you still must do](#2-what-works-today-vs-what-you-still-must-do)
3. [Repository layout](#3-repository-layout)
4. [Architecture](#4-architecture)
5. [Requirements](#5-requirements)
6. [Generate, build, and run (macOS)](#6-generate-build-and-run-macos)
7. [Configuration (Info.plist keys)](#7-configuration-infoplist-keys)
8. [Features (by area)](#8-features-by-area)
9. [Subscriptions & quotas](#9-subscriptions--quotas)
10. [Privacy & compliance (in the binary)](#10-privacy--compliance-in-the-binary)
11. [Cloud AI backend](#11-cloud-ai-backend)
12. [Targets, capabilities, and signing](#12-targets-capabilities-and-signing)
13. [Tests & CI](#13-tests--ci)
14. [Engineering history (Phases 0–45)](#14-engineering-history-phases-045)
15. [Pull requests (all 47)](#15-pull-requests-all-47)
16. [How to contribute going forward](#16-how-to-contribute-going-forward)
17. [App Store / TestFlight next steps](#17-app-store--testflight-next-steps)
18. [Known limitations](#18-known-limitations)

---

## 1. What this app is

Project Plate is a **camera-first nutrition diary**:

1. Open the scanner (FAB or Today **Scan meal** CTA).
2. Photograph a plate (or pick from Photos / barcode / label / voice / search / quick add).
3. AI returns a **structured draft** (foods + portions + confidence) — **not** medical truth.
4. Authoritative calories/macros resolve from a **local nutrition catalog** (USDA-shaped fixtures + restaurant catalog + optional Open Food Facts for barcodes) whenever possible.
5. User reviews/edits → saves to a **local-first** SwiftData diary.
6. Today / History / Progress / Widget / Watch / Live Activity reflect the day.

**Non-goals (explicit):** social feed, messaging, grocery shopping, trainer portal, web dashboard, Android, medical diagnosis, disease-specific recommendations, GLP-1 guidance, “health scores” that claim medical significance.

---

## 2. What works today vs what you still must do

### In the repo / binary (engineering complete through Phase 45)

- Full SwiftUI shell: onboarding, Today, History, Progress, Settings, Scanner, Paywall
- Local diary (SwiftData), targets, weight logging, favorites/frequent meals
- Photo scan pipeline (preprocess → vision draft → nutrition resolve → result editor)
- Barcode, nutrition-label OCR, voice quick-add, recipe URL + recipe builder
- StoreKit Pro paywall + free AI scan quota
- Privacy consent, export JSON/CSV, delete-all (+ iCloud tombstones when sync on)
- Widget, Live Activity, Apple Watch glance, iPad layout
- Optional iCloud sync, custom HTTPS AI gateway, meal reminders
- Retention UX: copy yesterday, share day, date picker, undo delete, History search, haptics
- Privacy Manifest, encryption declaration, App Review 3.1.2 paywall copy patterns
- Unit tests + macOS CI green on `main`

### You (human) must still finish before a real user can install a production build

These are **not** optional for TestFlight / App Store — see [`docs/APP_STORE_SUBMISSION.md`](docs/APP_STORE_SUBMISSION.md):

1. Live **Privacy Policy**, **Terms**, **Support** URLs → set `PLATE_*` Info keys  
2. Apple Developer **signing team** + HealthKit / App Groups / CloudKit container  
3. App Store Connect **IAP** products `com.projectplate.pro.monthly` / `.annual`  
4. Deploy the **Cloudflare Worker** (or leave scans on mock/on-device only)  
5. Screenshots, App Privacy labels, age rating, brand clearance  
6. Archive from **`main`** → Internal TestFlight → External → Review  

Until then: the codebase is real; a signed, store-ready product is not.

---

## 3. Repository layout

```text
foodtracker/
├── ProjectPlate/                 # Main iOS app sources
│   ├── App/                      # @main, AppEnvironment, AppRouter, RootTabView, ScanLaunchGate
│   ├── DesignSystem/             # Tokens, buttons, metrics, skeletons, haptics, layout
│   ├── Domain/                   # Models + use cases + protocols (no UIKit)
│   ├── Data/                     # SwiftData, AI, Health, StoreKit, Sync, Widget helpers
│   ├── Features/                 # Feature screens (Today, Scanner, Settings, …)
│   ├── PrivacyInfo.xcprivacy     # Privacy Manifest
│   └── Resources/                # Assets, entitlements, localizable strings
├── ProjectPlateTests/            # Swift Testing suites (macOS CI)
├── ProjectPlateWidget/           # Home Screen widget + Live Activity UI
├── ProjectPlateWatch/            # watchOS glance app
├── Shared/                       # Code shared by App / Widget / Watch
├── backend/                      # Cloudflare Worker meal-analyze API (OpenAI keys server-side)
├── docs/                         # Spec + architecture + shipping checklists
├── scripts/
│   ├── bootstrap-ios.sh          # xcodegen generate
│   ├── ci-ios.sh                 # generate + xcodebuild test (macOS)
│   └── release-checklist.sh      # Pre-archive sanity checks
├── project.yml                   # XcodeGen project definition (source of truth for Xcode)
├── .github/workflows/
│   ├── ios.yml                   # Build & Test (iOS) on macOS runners
│   └── backend.yml               # Backend unit tests
└── README.md                     # This file
```

There is also legacy Vite/Worker template scaffolding under `src/` / root `package.json` from early repo bootstrap; **the product client is the Swift targets**, and the **supported AI gateway is `backend/`**. Prefer `backend/` for new API work.

---

## 4. Architecture

Layered, **local-first** client. Dependencies flow inward:

```text
Features (SwiftUI)
    ↓ uses
Domain (models, use cases, protocols)
    ↑ implemented by
Data (SwiftData, networking, HealthKit, StoreKit, CloudKit, vision providers)
```

| Layer | Responsibility |
|-------|----------------|
| **App** | Composition root: `AppEnvironment`, router, tab shell, scan gate |
| **DesignSystem** | Semantic colors/spacing/type/radii; reusable controls; `PlateHaptics` |
| **Domain** | Pure models + engines (targets, streaks, coach, adaptive goals, challenges, day copy/share/search) |
| **Data** | Persistence, `MealVisionRouter`, nutrition repos, purchases, sync |
| **Features** | Screens only — no `URLSession`, no OpenAI, no Atwater math inline |

### AI routing (high level)

1. User must accept/decline cloud AI consent (persisted). Decline → on-device / non-cloud paths only.  
2. Optional **custom HTTPS gateway** (Keychain token) if configured.  
3. Else **managed Worker** when `PLATE_API_BASE_URL` is set.  
4. Else **mock / local** analysis (Simulator / CI default).  
5. Vision returns a **draft**; nutrition numbers prefer catalog resolution. Estimates stay labeled as estimates.

### Day boundaries

Meals are grouped by the **user’s local calendar**, not UTC midnight. Timestamps stay `Date`; day queries use `DayBoundary` / calendar start-of-day.

---

## 5. Requirements

### macOS (iOS app)

- macOS with **Xcode 16+** (iOS 18 / watchOS 11 SDK)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- Apple Development Team (for device / TestFlight / Archive — leave empty for Simulator CI)

### Optional backend

- Node 20+ / npm
- Cloudflare account + Wrangler (to deploy `backend/`)

### Linux Cloud Agents

**Cannot compile SwiftUI.** Treat macOS GitHub Actions `iOS` workflow as the compile/test source of truth. Backend tests can run on Linux.

---

## 6. Generate, build, and run (macOS)

### First-time / everyday

Guided path (checks Xcode, Homebrew, XcodeGen, simulators and SDKs, then
generates and opens the project). Safe to re-run:

```bash
./scripts/mac-setup.sh
```

Manual equivalent:

```bash
brew install xcodegen
./scripts/bootstrap-ios.sh          # runs xcodegen generate
open ProjectPlate.xcodeproj
```

No watchOS SDK installed? Generate an iPhone + widget only project:

```bash
./scripts/bootstrap-ios.sh --no-watch
```

Select the **ProjectPlate** scheme → iPhone Simulator → Run.

The full app includes **SwiftData**, **Home Screen widget**, **Live Activity** (Lock Screen / Dynamic Island), **Apple Watch** glance, **iCloud sync**, and all Phase 0–45 features.

### Cloud Mac (MacStadium, MacinCloud, etc.)

```bash
git clone https://github.com/Umbara1077/foodtracker.git && cd foodtracker
brew install xcodegen
./scripts/bootstrap-ios.sh
open ProjectPlate.xcodeproj
```

1. Scheme: **ProjectPlate** (not a legacy target — there isn’t one)
2. Simulator: **iPhone 16** (or any iOS 18 sim)
3. Run — onboarding → Today → scan / quick add
4. Enable **Lock Screen Live Activity** and **iCloud sync** under Settings after onboarding

For Archive / TestFlight, set your **Development Team** in Signing & Capabilities on the `ProjectPlate`, `ProjectPlateWidget`, and `ProjectPlateWatch` targets.

### CI-equivalent local verification

```bash
./scripts/ci-ios.sh
./scripts/release-checklist.sh
```

### Backend (optional)

```bash
cd backend
npm install
npm test
npx wrangler dev
```

Point the iOS target at the Worker via `PLATE_API_BASE_URL` (see below).

---

## 7. Configuration (Info.plist keys)

Defined in [`project.yml`](project.yml) under `ProjectPlate` → `INFOPLIST_KEY_*`. Empty strings are intentional defaults for Simulator/CI.

| Key | Purpose | Empty behavior |
|-----|---------|----------------|
| `PLATE_API_BASE_URL` | Managed meal-analyze Worker base URL | On-device / mock analysis |
| `PLATE_API_TOKEN` | Optional bearer token for Worker | No `Authorization` header |
| `PLATE_PRIVACY_POLICY_URL` | Canonical privacy policy | In-app privacy screen + placeholder warning |
| `PLATE_TERMS_URL` | Canonical terms | In-app terms + placeholder warning |
| `PLATE_SUPPORT_URL` | Support page or `mailto:` | About → Support uses fallback |

Also declared (do not strip):

- Camera / Mic / Speech / HealthKit usage strings  
- `ITSAppUsesNonExemptEncryption = false` (HTTPS-only standard encryption)  
- Live Activities support  

**Never** put OpenAI or other private API keys in the iOS bundle. Keys belong in Worker secrets / custom gateway Keychain only.

---

## 8. Features (by area)

### Tabs & navigation

| Surface | Role |
|---------|------|
| **Today** | Calories remaining, macros, streak, quick actions, meal list, greeting, copy-previous-day, date picker, share |
| **History** | 7-day strip, day totals, meal edit/delete/log-to-today, searchable meals, share, undo |
| **Progress** | Weight + consistency charts, weekly digest, coach insights, challenges, adaptive goal suggestions |
| **Settings** | Targets, Health, subscription, privacy, reminders, cloud AI / custom gateway, About, acknowledgments |
| **Scan FAB** | Full-screen camera flow (same consent/quota gate as Today Scan CTA) |

### Logging inputs

- Photo meal scan (+ retake / library)
- Barcode → catalog / Open Food Facts
- Nutrition label OCR
- Manual food search + editor
- Quick add (calories/macros, Atwater helper)
- Voice-assisted quick add
- Recipe URL import + manual recipe builder
- Duplicate / “log again” / copy previous day
- Meal plan entries (optional preference)

### Diary & editing

- Meal detail editor (Today + History; same-id upsert)
- Undo-delete banner (~6s)
- Target editor (history-preserving snapshots)
- CSV + JSON export; delete all local data

### Extensions

- Home Screen widget (shared App Group snapshot)
- Live Activity (today calories)
- Apple Watch glance (remaining calories / protein)

---

## 9. Subscriptions & quotas

| Product ID | Intent |
|------------|--------|
| `com.projectplate.pro.monthly` | Pro monthly |
| `com.projectplate.pro.annual` | Pro annual |

- Free tier: diary + manual/barcode/quick-add + **limited** AI scans  
- Pro: unlocks unlimited AI scans (StoreKit entitlement)  
- Paywall includes App Review **3.1.2** patterns: auto-renew copy, price/period, Privacy/Terms, Restore, Manage subscription  
- Create the products in App Store Connect before expecting real purchases  

---

## 10. Privacy & compliance (in the binary)

Already implemented in code (still need live legal hosts + ASC labels):

- Cloud AI consent Accept/Decline; Decline disables managed cloud vision  
- Meal photos re-encoded (EXIF/GPS stripped); photos not kept in diary  
- Privacy Manifest (`PrivacyInfo.xcprivacy`)  
- Export / delete; iCloud tombstones on delete when sync enabled  
- Medical disclaimer in onboarding / About / Terms  
- No account system → no Sign in with Apple / account-deletion obligation  
- No ATT / IDFA SDKs (analytics is local / no-op style)  
- Beta / TestFlight tools hidden on App Store builds  

---

## 11. Cloud AI backend

See [`backend/README.md`](backend/README.md).

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/v1/health` | Liveness |
| `GET` | `/v1/config` | Remote model / quota settings |
| `POST` | `/v1/meal/analyze` | Vision draft (**not** authoritative nutrition) |

- OpenAI keys: **server-side only** (`OPENAI_API_KEY` Wrangler secret)  
- Optional app token: `APP_API_TOKEN`  
- Quota keyed by `X-Install-ID` in KV  
- `PROVIDER_MODE`: `auto` | `mock` | `openai`  
- Photos processed in memory; not stored by the Worker design  

Users can also point Settings → Cloud AI → **Custom gateway** at their own HTTPS endpoint (token in Keychain).

---

## 12. Targets, capabilities, and signing

| Target | Bundle ID |
|--------|-----------|
| App | `com.projectplate.app` |
| Widget | `com.projectplate.app.widget` |
| Watch | `com.projectplate.app.watchkitapp` |
| Tests | `com.projectplate.app.tests` |

Enable on the App ID / provisioning:

- HealthKit  
- App Groups: `group.com.projectplate.app`  
- iCloud / CloudKit: `iCloud.com.projectplate.app` (create container in Developer portal)  
- Push / Live Activities as configured  
- Associated Watch app  

Set `DEVELOPMENT_TEAM` in Xcode (or `project.yml`) before device/Archive.

---

## 13. Tests & CI

### iOS (`ProjectPlateTests`)

Swift Testing suites covering diary math, targets, scan/barcode/OCR/voice parsers, sync codecs, paywall/legal copy, layout, widgets, Watch presenter, and phase-specific helpers (copy day, share, date nav, undo, scan gate, meal search, haptics, …).

Run via:

```bash
./scripts/ci-ios.sh
# or Xcode → Product → Test
```

### Backend

```bash
cd backend && npm test
```

### GitHub Actions

| Workflow | Runner | What |
|----------|--------|------|
| `iOS` | macOS | XcodeGen + `xcodebuild test` |
| `Backend` | Linux | Vitest / Worker tests |

**`main` must stay green.** Linux agents edit Swift; only macOS CI proves it compiles.

---

## 14. Engineering history (Phases 0–45)

All of this is on **`main`**.

| Band | Phases | Highlights |
|------|--------|------------|
| Foundation | 0–6 | Shell, onboarding, diary, camera mock, catalog, managed AI gateway client, barcode |
| V1 core | 7–11 | Progress, HealthKit, StoreKit Pro, privacy, TestFlight tools |
| V1.1 | 12–20 | Favorites, scan retry, digest, widget, streak, voice, label OCR, Live Activity, iCloud sync |
| V1.2+ | 21–31 | Restaurant matching, adaptive goals, recipes, coach, micros, challenges, iPad, meal plan, Watch, family scaffold |
| Ops | 32–34 | Legal URL overrides, 3.1.2 paywall, Privacy Manifest, consent gate, App Store checklist |
| Power / retention | 35–45 | Custom gateway, reminders, CSV, analytics, target/meal editors, copy/share day, date picker, undo, Scan CTA, History search, haptics |

Version line (tip): **1.5.10 (45)**.

---

## 15. Pull requests (all 47)

GitHub shows **47** PRs against this repo. Status:

| State | Count | Meaning |
|-------|------:|---------|
| **MERGED** | 43 | Merged into `main` via GitHub |
| **CLOSED** (not merged as PRs) | 4 | `#22` `#23` `#24` `#28` — **closed after content was already on `main`** via the Phase 45 tip merge (same fixes, different commit SHAs). No missing features. |
| **OPEN** | 0 | Nothing left to merge |

### Full list

| # | State | Title |
|--:|-------|-------|
| 1 | MERGED | Foodtracker: Cloudflare meal logger from Vite React template |
| 2 | MERGED | Phase 0: Project Plate iOS SwiftUI foundation |
| 3 | MERGED | Phase 1: Onboarding + calorie/macro targets |
| 4 | MERGED | Phase 2: Local meal diary, quick add, and history |
| 5 | MERGED | Phase 3: Camera scan + mocked meal analysis |
| 6 | MERGED | Phase 4: nutrition catalog search + food editor |
| 7 | MERGED | Phase 5: managed cloud AI gateway + iOS client |
| 8 | MERGED | Phase 6: barcode scan + product lookup |
| 9 | MERGED | Phase 7: progress weight logging + consistency charts |
| 10 | MERGED | Phase 8: Apple Health meal and weight sync |
| 11 | MERGED | Phase 9: StoreKit Pro paywall + free scan quota |
| 12 | MERGED | Phase 10: privacy consent, export/delete, hardening |
| 13 | MERGED | Phase 11: TestFlight support (corrections, AI benchmark, 1.0.0) |
| 14 | MERGED | Phase 12 / V1.1: frequent meals on Today |
| 15 | MERGED | Phase 13: scan retry and failed-scan recovery |
| 16 | MERGED | Phase 14: weekly digest on Progress |
| 17 | MERGED | Phase 15: Home Screen Today calories widget |
| 18 | MERGED | Phase 16: tracking streak on Today and Progress |
| 19 | MERGED | Phase 17: voice-assisted Quick Add |
| 20 | MERGED | Phase 18: nutrition label OCR logging |
| 21 | MERGED | Phase 19: Live Activity for today’s calories |
| 22 | CLOSED* | Phase 20: iCloud diary sync via SyncService |
| 23 | CLOSED* | Phase 21: better restaurant matching (curated catalog) |
| 24 | CLOSED* | Phase 22: adaptive calorie goal suggestions |
| 25 | MERGED | Phase 23: URL recipe import |
| 26 | MERGED | Phase 24: manual recipe builder |
| 27 | MERGED | Phase 25: local coach insights on Progress |
| 28 | CLOSED* | Phase 26: advanced micronutrients (fiber, sugar, sodium) |
| 29 | MERGED | Phase 27: soft weekly challenges on Progress |
| 30 | MERGED | Phase 28: iPad-specific layout |
| 31 | MERGED | Phase 29: local meal planning on Today |
| 32 | MERGED | Phase 30: Apple Watch Today calorie glance |
| 33 | MERGED | Phase 31: local shared/family plan scaffolding |
| 34 | MERGED | Phase 32: TestFlight readiness handoff (1.4.0) |
| 35 | MERGED | Phase 33: App Review billing disclosures + Apple-style polish |
| 36 | MERGED | Phase 34: App Store compliance (privacy, consent, Privacy Manifest) |
| 37 | MERGED | Phase 35: Custom AI gateway, meal reminders, CSV export |
| 38 | MERGED | Phase 36: Analytics funnel, Today skeletons, acknowledgments |
| 39 | MERGED | Phase 37: Settings target editor (history-preserving) |
| 40 | MERGED | Phase 38: Meal detail editor (Today + History) |
| 41 | MERGED | Phase 39: Copy yesterday’s meals + Today greeting |
| 42 | MERGED | Phase 40: Share day nutrition summary |
| 43 | MERGED | Phase 41: Today calendar day picker |
| 44 | MERGED | Phase 42: Undo meal delete |
| 45 | MERGED | Phase 43: Scan meal as Today primary CTA |
| 46 | MERGED | Phase 44: History meal search |
| 47 | MERGED | Phase 45: PlateHaptics (PRODUCT_SPEC §8.7) |

\*CLOSED* = GitHub PR not merge-committed, but **feature code + CI fixes are present on `main`** (verified by file inventory). Safe to ignore those PR pages.

**Do not reopen stacked phase branches.** New work → commit on `main`.

---

## 16. How to contribute going forward

1. `git checkout main && git pull origin main`  
2. Make changes (prefer small, reviewable commits).  
3. Run `./scripts/ci-ios.sh` on a Mac when possible; always wait for GitHub `iOS` + `Backend` on push.  
4. Push `main` (or open **one** short-lived PR into `main` if you need review — never a 40-PR stack).  
5. Update this README + `docs/TESTFLIGHT.md` / `docs/APP_STORE_SUBMISSION.md` when version or shipping status changes.  
6. Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.yml` when cutting a meaningful build.  

---

## 17. App Store / TestFlight next steps

Priority order:

1. Publish Privacy / Terms / Support → fill `PLATE_*` keys  
2. Signing team + HealthKit / App Groups / CloudKit  
3. Create IAP products in App Store Connect  
4. Deploy `backend/` Worker; set `PLATE_API_BASE_URL`  
5. Archive **`main`** → Internal TestFlight  
6. Screenshots, privacy nutrition labels, review notes, brand clearance  
7. External TestFlight → Submit for Review  

Checklists: [`docs/TESTFLIGHT.md`](docs/TESTFLIGHT.md) · [`docs/APP_STORE_SUBMISSION.md`](docs/APP_STORE_SUBMISSION.md)

---

## 18. Known limitations

- **Working title** — not cleared for store branding.  
- **Legal URLs** default empty → placeholders; ASC still needs real public Privacy Policy URL.  
- **IAP / signing / CloudKit** require Apple Developer / ASC setup outside this repo.  
- **Managed AI** needs a deployed Worker (or custom gateway); otherwise scans use mock/on-device paths.  
- **Linux cannot compile** the iOS app — trust macOS CI.  
- Estimates are **not medical advice**; UI/copy must keep that clear in listing and screenshots.  
- Spec mentions future Apple on-device multimodal APIs — gated; not required for current builds.  

---

## License / ownership

Private product repository. All rights reserved by the repository owner unless otherwise stated.
