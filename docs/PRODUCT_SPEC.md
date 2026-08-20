# Project Plate — iPhone Product, Design & Engineering Specification
## AI Photo Calorie & Macro Tracker
**Document status:** Build-ready product specification  
**Platform 1:** iPhone / iOS  
**Android:** intentionally deferred until the iPhone product is stable  
**Working title:** Project Plate (placeholder — do not ship under this name without App Store, trademark, domain, and social-handle clearance)  
**Product thesis:** *Photograph a meal, review an honest nutrition estimate, make one-tap corrections, and log it in seconds.*

---

# 0. READ THIS FIRST — INSTRUCTIONS FOR CURSOR

This document is the source of truth for the first production version of the iPhone app.

Cursor should treat the following as hard constraints:

1. Build the iPhone app first. Do **not** introduce Android, Flutter, React Native, or Kotlin into the iOS repository.
2. Use **native Swift + SwiftUI** for the iPhone client.
3. Minimum deployment target: **iOS 18.0** for the first production release.
4. Use a layered architecture so AI providers, storage, and nutrition data sources can be swapped without changing UI screens.
5. The app must be useful without creating an account.
6. Do not hard-code any private API key in the app bundle.
7. Do not make raw OpenAI API key entry part of the consumer onboarding experience.
8. Meal images sent to cloud AI must be clearly disclosed to the user before the first cloud scan.
9. AI must identify foods and estimate portions; authoritative nutrition values should come from a food database whenever possible.
10. Never represent a single-photo calorie estimate as exact. Show confidence and/or an estimate range.
11. Build screens from reusable design-system components. Do not scatter arbitrary colors, spacings, fonts, or corner radii throughout views.
12. The visual direction is inspired by premium camera-first nutrition apps such as Cal AI, but this product must not copy their name, icons, illustrations, proprietary assets, exact screen layouts, text, animations, or trade dress.
13. The first public MVP must feel complete and polished. Do not ship a giant unfinished feature list.
14. App logic must be testable without a live AI provider.
15. Every API response must decode into a typed model; no UI should parse arbitrary model prose.
16. Use feature flags for unfinished features rather than exposing dead controls.
17. Privacy, data deletion, subscription restore, and error states are part of the MVP — not afterthoughts.

---

# 1. EXECUTIVE SUMMARY

Project Plate is a premium, camera-first calorie and macronutrient tracker for iPhone.

The central experience is intentionally simple:

**Open scanner → photograph food → AI identifies the food and portions → nutrition database resolves calories/macros → user reviews/edit → save.**

The problem with traditional calorie trackers is not that calorie data does not exist. The problem is logging friction. Users abandon tracking when every meal requires database searches, manual quantities, serving conversions, and repeated taps.

The app therefore competes on:

- Speed.
- Visual polish.
- Honest uncertainty.
- Easy correction.
- Strong daily feedback.
- A camera-first interaction.
- Local-first privacy.
- A cost-efficient AI architecture.
- Native iPhone behavior.
- A design that feels like a premium Apple app rather than an AI chatbot wrapped in a mobile shell.

The product is **not** an AI medical adviser. It is a food logging and estimation tool.

---

# 2. MARKET REFERENCE AND WHAT WE ARE COPYING VS. NOT COPYING

## 2.1 Reference products

The primary category reference is Cal AI because it validates the exact core behavior: short onboarding, food photo, nutrition result, simple progress. Current App Store positioning demonstrates that this interaction is commercially proven.

Other useful references:
- MyFitnessPal — database depth, barcode, diary, mature nutrition logic.
- MacroFactor — serious macro tracking and trend credibility.
- SnapCalorie / similar photo trackers — photo-first logging expectation.
- Apple Fitness / Health — progress rings, restraint, native motion, accessibility.

## 2.2 What to borrow from category conventions

It is fine to use common product conventions:
- Full-screen meal camera.
- Large shutter control.
- Rounded cards and sheets.
- Macro summary visualization.
- One-question-per-page onboarding.
- Daily calorie target.
- Meal history.
- Barcode scanning.
- Photo library import.
- A bottom tab bar.
- Premium annual/monthly plans.
- Quick edit after AI recognition.
- Progress and weight charts.

These are functional conventions, not proprietary assets.

## 2.3 What must be distinct

Do **not** reproduce:
- Cal AI branding, logo, wordmark, icon.
- Exact copy such as their onboarding language or marketing slogans.
- Exact camera control geometry.
- Exact result-card arrangement.
- Their category icons.
- Their exact colors.
- Their screenshots or illustrations.
- Their paywall art.
- Their animations frame-for-frame.
- Their proprietary nutrition scoring formula.

Our product should feel like it belongs in the same premium category while being recognizable as its own product.

---

# 3. PRODUCT POSITIONING

## 3.1 Primary promise

> **Log a meal in seconds — without pretending a photo is perfectly precise.**

## 3.2 Secondary promises

- See calories, protein, carbs, and fat immediately.
- Correct anything the scanner gets wrong without rescanning.
- Use verified database nutrition when possible.
- Know when a number is estimated.
- Keep a clean history of what you actually ate.
- Track progress without living inside the app.

## 3.3 Emotional positioning

The app should feel:
- Calm, not judgmental.
- Fast, not obsessive.
- Smart, not magical.
- Premium, not clinical.
- Encouraging, not childish.
- Clear, not data-dense.
- Honest about uncertainty.

Avoid red “failure” language for exceeding a goal. The product should say “234 over target” rather than “You failed today.”

---

# 4. TARGET USERS

## Persona A — “I hate logging food”
Wants calorie awareness but quits existing apps because logging takes too long.

Needs:
- Photo scan.
- Minimal correction.
- Simple daily view.

## Persona B — “Protein matters”
Tracks protein and calories more than detailed micronutrients.

Needs:
- Macro targets.
- Meal-level protein.
- Fast recurring meals.
- Weight progress.

## Persona C — “I eat out a lot”
Needs best-effort estimates for restaurant and mixed meals.

Needs:
- Photo capture.
- Brand/restaurant correction.
- Portion adjustment.
- Confidence warnings.

## Persona D — “Power user”
Cares about exact quantities and sources.

Needs:
- Ingredient-level editing.
- Grams/ounces.
- Database source.
- Manual override.
- Export later.

---

# 5. JOBS TO BE DONE

1. “When I am about to eat, I want to log the meal with almost no effort.”
2. “When the AI is wrong, I want to fix it faster than manually creating the meal.”
3. “When I look at today, I want to know what I have left.”
4. “When I am trying to hit protein, I want to see exactly how close I am.”
5. “When a photo estimate is uncertain, I want the app to be transparent.”
6. “When I eat the same thing again, I want to log it instantly.”
7. “When I change weight or goals, I want my targets to stay understandable.”
8. “When I use Apple Health, I want my nutrition data to sync with permission.”

---

# 6. V1 SCOPE

## 6.1 Must ship in V1

### Core
- First-run onboarding.
- Optional calculated calorie/macronutrient goal.
- Manual calorie goal override.
- Home / Today dashboard.
- Meal photo scanner.
- Photo-library meal import.
- AI food identification.
- Portion estimation.
- Nutrition database resolution.
- Results review screen.
- Ingredient/food correction.
- Portion correction.
- Add/remove detected items.
- Save meal.
- Meal history for previous days.
- Manual food search.
- Manual quick-add calories/macros.
- Barcode scanning.
- Weight logging.
- Basic progress charts.
- Apple Health optional integration for nutrition + weight.
- Settings.
- Dark mode.
- Subscription/paywall.
- Restore purchases.
- Privacy disclosure for cloud analysis.
- Local data export as JSON/CSV can be V1.0 or V1.1; architecture must support it.
- Delete all local data.

### Reliability
- Offline home/history access.
- AI retry.
- Failed scan recovery.
- Nutrition data source indicator.
- Typed errors.
- Loading skeletons.
- Empty states.
- Accessibility labels.
- Dynamic Type.
- Reduced Motion support.

## 6.2 V1.1
- Voice logging.
- Nutrition-label OCR.
- Saved meals / favorites.
- Home Screen widget.
- Live Activity only if genuinely useful.
- Weekly digest.
- Better restaurant matching.
- iCloud/CloudKit sync if not included at 1.0.

## 6.3 V1.2+
- AI nutrition coach.
- Recipe builder.
- URL recipe import.
- Shared/family plan.
- Challenges/streaks.
- Adaptive goals.
- Advanced micronutrients.
- Meal planning.
- Apple Watch.
- iPad-specific layout.

## 6.4 Explicit non-goals for first build

Do not build yet:
- Social feed.
- Messaging.
- Meal plans.
- Grocery shopping.
- Trainer portal.
- Web dashboard.
- Android.
- Custom workout programming.
- Medical diagnosis.
- Disease-specific nutrition recommendations.
- GLP-1 treatment guidance.
- Eating-disorder treatment.
- “Health score” that claims medical significance.

---

# 7. PLATFORM AND TECHNICAL DECISIONS

## 7.1 Client

**Native SwiftUI.**

Reasons:
- Camera integration.
- HealthKit.
- StoreKit.
- Keychain.
- SwiftData.
- WidgetKit later.
- Native accessibility.
- Native motion.
- Better iPhone polish.
- We are intentionally doing Android later, so cross-platform reuse is not worth compromising the first product.

## 7.2 Language
- Swift.
- Use current stable Swift version supported by the production Xcode toolchain.
- Swift Concurrency (`async/await`) for asynchronous work.
- Prefer `actor` for shared mutable service state.
- Avoid callback pyramids.

## 7.3 Persistence

V1 should be **local-first**.

Recommended:
- SwiftData for user profile, meals, meal items, targets, weight entries, favorites, scan records.
- AppStorage only for simple preferences.
- Keychain for secrets/tokens.
- Image files stored in Application Support / Documents with controlled lifecycle — not giant blobs in SwiftData.

Benefits:
- No account required.
- No backend required for basic diary functionality.
- Home/history remain instant.
- Lower infrastructure cost.
- Better privacy story.

## 7.4 Cloud sync

Treat sync as a separate service conforming to a protocol.

```swift
protocol SyncService {
    func sync() async throws
    func upload(localChanges: [SyncRecord]) async throws
    func fetchRemoteChanges(since token: String?) async throws -> SyncBatch
}
```

For iPhone-only V1, CloudKit is reasonable. If Android becomes a priority, a later migration to Firebase/Supabase can happen behind this abstraction.

Do not tightly couple domain models to CloudKit-specific types.

---

# 8. DESIGN DIRECTION

## 8.1 Visual concept

**“Editorial food photography + Apple-level utility.”**

The visual language should mix:
- Large food imagery.
- High-contrast typography.
- Soft off-white surfaces.
- Dark camera chrome.
- Frosted/glass controls where appropriate.
- One bright brand accent.
- Rounded, tactile cards.
- Minimal decorative clutter.

The home screen should not look like a spreadsheet.
The scanner should not look like a social camera.
The results screen should not look like an AI chat transcript.

## 8.2 Brand working palette

Use semantic tokens rather than hard-coding.

### Light
- `backgroundPrimary`: `#F5F4EF` — warm off-white.
- `surfacePrimary`: `#FFFFFF`.
- `surfaceSecondary`: `#ECEBE6`.
- `textPrimary`: `#111214`.
- `textSecondary`: `#686A70`.
- `separator`: `#D9D8D2`.
- `brandPrimary`: `#63E6BE` — clean mint.
- `brandPrimaryPressed`: `#45CFA8`.
- `brandInk`: `#082D24`.
- `warning`: system orange.
- `error`: system red, used sparingly.

### Dark
- `backgroundPrimary`: `#0B0C0D`.
- `surfacePrimary`: `#17191B`.
- `surfaceSecondary`: `#222528`.
- `textPrimary`: `#F7F7F5`.
- `textSecondary`: `#A9ADB3`.
- `separator`: `#32363A`.
- brand mint remains saturated enough for contrast.

### Macro colors
These are secondary semantic colors, not the brand itself:
- Protein: `#FF6B6B`.
- Carbs: `#7C6CF2`.
- Fat: `#F4B942`.
- Fiber: `#30B77B`.

The interface must remain understandable without color. Always pair color with labels/icons/value.

## 8.3 Typography

Use Apple system fonts only.

Recommended:
- Hero numeric: `.system(size: 44, weight: .bold, design: .rounded)`
- Large title: 34 / bold.
- Screen title: 28 / bold.
- Section heading: 20 / semibold.
- Body: 17 / regular.
- Supporting: 15 / regular.
- Caption: 13 / medium.
- Numeric macro values: rounded design, semibold/bold.

Do not use a custom font in V1. It adds App Store weight, licensing issues, accessibility issues, and inconsistency.

## 8.4 Spacing

Use a 4-point grid.

Core tokens:
- `space2 = 2`
- `space4 = 4`
- `space8 = 8`
- `space12 = 12`
- `space16 = 16`
- `space20 = 20`
- `space24 = 24`
- `space32 = 32`
- `space40 = 40`

Default screen horizontal margin: **20 pt**.
Compact card padding: **16 pt**.
Large card padding: **20 pt**.

## 8.5 Corner radii
- Small chips: 10 pt.
- Controls: 14 pt.
- Standard cards: 20 pt.
- Hero cards: 26 pt.
- Bottom sheet top corners: 30 pt.
- Pill: full capsule.

## 8.6 Shadows
Use extremely restrained shadows:
- black 8–10% opacity.
- radius 12.
- y 4.
Avoid layered Material-Design style shadows.

## 8.7 Haptics
- Shutter: medium impact.
- Successful scan: success notification.
- Meal saved: soft success.
- Invalid selection: warning.
- Changing portion chips: light selection haptic.
- Subscription success: success notification.

Respect Reduce Motion, but haptics may remain unless disabled by system/user.

---

# 9. NAVIGATION ARCHITECTURE

Primary tabs:

1. **Today**
2. **History**
3. **Progress**
4. **Settings**

The primary **Scan** action is a floating central action visually attached to the tab bar, but should not behave as a fifth information tab.

### Tab bar behavior
- Native `TabView`.
- System icons.
- Labels visible.
- Scan button is a 58–62 pt floating circle using brandPrimary with black/brandInk camera icon.
- When tapped, scanner is presented full-screen.
- Scanner returns to the previously selected tab after save/cancel.

This differs from a pure camera-tab layout and gives the product a distinct navigation identity.

---

# 10. ONBOARDING — SCREEN-BY-SCREEN

The onboarding should feel fast even if it contains several steps.

General style:
- Background: warm off-white.
- Top: close/back when appropriate.
- Thin progress bar under safe-area top.
- Question centered in upper 35%.
- One primary interaction.
- Sticky bottom Continue button.
- Avoid giant illustrations on every page.
- Use tasteful food/lifestyle illustrations only on welcome and result/goal pages.

## 10.1 Welcome

Headline:
**Track food without the homework.**

Supporting:
“Snap a meal, review the estimate, and keep moving.”

Buttons:
- Continue
- “I already know my targets” secondary text button

No account creation.

## 10.2 Goal

Question:
**What are you working toward?**

Cards:
- Lose weight.
- Maintain weight.
- Gain weight.
- Track nutrition only.

Each card:
- icon.
- title.
- one-line explanation.
- selectable state.

## 10.3 Units

Options:
- US: lb, ft/in.
- Metric: kg, cm.

Use segmented control.

## 10.4 Age

Wheel/input.
If under 18:
- Do not generate weight-loss or weight-gain calorie prescriptions.
- Offer tracking-only/manual-target mode.
- Present neutral copy.

## 10.5 Height
Use native picker or numeric fields.

## 10.6 Current weight
Use numeric input.

## 10.7 Optional target weight
Only if goal requires it.
Provide skip.

## 10.8 Formula input

If using Mifflin-St Jeor, the equation needs a sex constant.

Copy:
**For the calorie estimate, which formula should we use?**
- Male equation.
- Female equation.
- Skip and set calories manually.

Avoid making broader identity claims from this choice.

## 10.9 Activity

Cards:
- Mostly seated.
- Lightly active.
- Active.
- Very active.

Do not overcomplicate with seven multiplier levels.

Initial multipliers:
- Mostly seated: 1.20
- Lightly active: 1.375
- Active: 1.55
- Very active: 1.725

Make these remote-configurable constants, not UI constants.

## 10.10 Desired pace

For loss/gain:
- Slow.
- Moderate.
- Faster.

Translate into bounded calorie adjustments.
Do not expose extreme plans.

Recommended algorithm:
1. Calculate estimated TDEE.
2. Loss:
   - Slow: -10%.
   - Moderate: -15%.
   - Faster: -20%.
3. Gain:
   - Slow: +5%.
   - Moderate: +10%.
   - Faster: +15%.
4. Never present the result as medical advice.
5. Let the user manually edit the final target.

This percentage approach is simpler and less likely to encourage extreme fixed deficits.

## 10.11 Macro preference

Options:
- Balanced.
- Higher protein.
- Lower carb.
- Custom.

Suggested starting ratios:
- Balanced: 25% protein / 45% carbs / 30% fat.
- Higher protein: 30% / 40% / 30%.
- Lower carb: 30% / 30% / 40%.

These are tracking defaults, not medical prescriptions.

User can edit grams later.

## 10.12 Result

Hero:
**Your starting target**

Large:
`2,180 cal`

Macro tiles:
- 164g protein.
- 245g carbs.
- 73g fat.

Copy:
“Use this as a starting point. You can change it anytime.”

Buttons:
- Use this target.
- Edit target.

## 10.13 Health integration
Optional:
“Connect Apple Health”
Benefits:
- Keep weight in sync.
- Save nutrition entries to Health.
- Read weight if permission granted.

Buttons:
- Connect.
- Not now.

Do not request HealthKit permission before explaining why.

## 10.14 Cloud AI disclosure

Before the first cloud scan, not necessarily during onboarding:

“Meal photos can be sent to our AI provider to identify food. We send only what is needed for the scan. You can review the privacy details before continuing.”

Buttons:
- Continue.
- Privacy details.

Store consent version/date locally.

---

# 11. TODAY / HOME SCREEN

## 11.1 Goal
At a glance, the user should answer:
- How many calories have I consumed?
- How many remain?
- How are my macros doing?
- What have I eaten today?
- How do I log something?

## 11.2 Layout

### Top bar
Left:
“Good morning” / “Today” based on preference. Avoid overly personalized copy initially.

Right:
- Date calendar button.
- optional streak pill later.

### Hero calorie card

Large rounded card.

Top label:
**Calories remaining**

Center:
Large numeric:
`1,042`

Under:
`1,138 eaten · 2,180 goal`

Visualization:
A single thick progress arc/ring, 12–14 pt stroke.
Do not turn ring red when >100%; continue with a neutral over-target state.

### Macro row

Three equal columns:
- Protein `82 / 164g`
- Carbs `109 / 245g`
- Fat `41 / 73g`

Each:
- label.
- current/goal.
- 4–6 pt progress bar.
- semantic color.

Tapping a macro opens a detail sheet later; V1 can be noninteractive if needed.

### Quick log row

Three compact buttons:
- Scan meal.
- Barcode.
- Quick add.

Scan meal uses brand-filled style.
Others use white/secondary surface.

### Meal timeline

Sections:
- Breakfast.
- Lunch.
- Dinner.
- Snacks.

Only show meal sections that have content plus one “Add meal” row.
Alternative: show chronological cards with a meal-type chip.

Preferred V1:
chronological cards because it handles irregular eating better.

Meal card:
- 54x54 food thumbnail.
- Meal name.
- Time.
- `620 cal`.
- Protein right/bottom.
- Chevron.
- Swipe actions: duplicate / delete.
- Tap opens meal detail.

### Empty state

If no meals:
Hero remains.
Below:
Food-photo illustration or camera glyph.
“Your first meal takes one photo.”
Primary button: Scan a meal.
Secondary: Add manually.

---

# 12. CAMERA / SCANNER EXPERIENCE

This is the product’s most important screen.

## 12.1 Presentation
Full-screen cover.
Status bar can be hidden if safe and appropriate.
Camera preview edge to edge.

## 12.2 Top controls
Use translucent dark glass circles/pills.

Left:
- X close.

Center:
- small label `Meal scan`.

Right:
- Flash toggle.
- Gallery thumbnail/button.

Controls must remain visible against light and dark food scenes.

## 12.3 Framing guide

Do not show rigid document corners.

Show a subtle rounded rectangle / bracket guide occupying roughly 72% width and 46% height.

Prompt above shutter:
**Fit the whole plate in frame**

Dynamic helper messages:
- “Move a little closer.”
- “More light will help.”
- “Try to keep the plate visible.”
- “Looks good.”

These helper messages can initially be simple heuristics:
- exposure.
- blur.
- camera focus.
No AI needed.

## 12.4 Mode selector

Above shutter:
A glass capsule with:
- Meal.
- Barcode.
- Label (V1.1 if not ready).

Do not overload with five modes.

## 12.5 Shutter

72–78 pt diameter.
White outer ring.
Inner center filled white.
Press animation:
- scale to 0.92 for 80ms.
- medium haptic.
- freeze captured frame.

## 12.6 Photo library
Photo picker should use the system picker. Do not request broad photo-library access when PHPicker can provide selected content.

## 12.7 Retake screen

After capture, freeze photo.
Bottom:
- Retake.
- Analyze meal.

For maximum speed, support a setting:
“Analyze immediately after capture.”
Default can be immediate once confidence in UX is high.
Initial beta should show confirmation so camera bugs are easier to test.

---

# 13. ANALYZING STATE

Target perceived wait: under 3 seconds if provider latency permits.

Never show a static spinner alone.

Use:
- Captured image full-screen.
- Very subtle animated scan highlight.
- Bottom sheet with changing factual stages:

1. “Looking at the meal…”
2. “Estimating portions…”
3. “Matching nutrition…”
4. “Building your log…”

Do not lie about stages if the architecture is not actually doing them. The service should expose coarse status updates.

```swift
enum MealAnalysisStage: Equatable {
    case preparingImage
    case identifyingFood
    case resolvingNutrition
    case validating
    case complete
}
```

If >8 seconds:
“Still working — mixed meals can take a little longer.”

If >20 seconds:
Offer cancel + retry.

---

# 14. MEAL RESULT SCREEN

This needs to feel gratifying.

## 14.1 Presentation
Captured food remains as hero image occupying upper ~32–38% of screen.

A large surface sheet overlaps from below with 30 pt top corners.

## 14.2 Header

Small meal-type chip:
`Lunch`

Editable title:
**Chicken rice bowl**

Right:
ellipsis menu.

## 14.3 Total

Large:
`642`
small unit:
`cal`

Below:
**Estimated 590–700 cal**

Only show a range when scan-based.
For barcode/manual exact database entries, range can be omitted.

Confidence pill:
- High confidence.
- Good estimate.
- Needs a quick check.

Avoid “93% accurate.” That implies a level of validation we probably cannot support.

## 14.4 Macro cards
Three horizontally aligned mini-cards:
- Protein 48g
- Carbs 71g
- Fat 18g

Use icons + labels.

## 14.5 Detected items

Section:
**What I found**

Each row:
- icon/mini crop optional.
- `Grilled chicken`.
- `135 g`.
- `223 cal`.
- confidence dot/pill.
- chevron.

Example:
- Grilled chicken — 135g — 223 cal
- White rice — 180g — 234 cal
- Avocado — 55g — 88 cal
- Sauce — 28g — 97 cal

The user can:
- tap row to edit.
- swipe delete.
- Add item.

## 14.6 Correction CTA

Prominent outlined action:
**Something off? Fix the meal**

Opens correction sheet:
- “What should change?”
- quick chips:
  - Portion too big.
  - Portion too small.
  - Missing food.
  - Wrong food.
  - Sauce/dressing.
- text field:
  “e.g. That was turkey, not chicken.”

If cloud AI is used, send the original structured result plus correction text, **not a fresh unconstrained prompt**.

## 14.7 Save

Sticky bottom:
**Add to today — 642 cal**

Secondary:
Change time/meal type.

Success:
- Sheet collapses.
- success haptic.
- Today screen calorie ring animates to new value.
- Toast: “Lunch added.”

---

# 15. FOOD ITEM EDITOR

Presented as sheet.

Fields:
- Food name/search.
- Portion value.
- Unit:
  - grams.
  - ounces.
  - serving.
  - cup/tbsp where data supports it.
- Calories.
- Protein.
- Carbs.
- Fat.
- Nutrition source.

If source is verified database:
Show:
“USDA FoodData Central” or named supported data source.

If calculated from AI:
Show:
“AI estimate — review recommended.”

Buttons:
- Save changes.
- Delete item.

Changing grams should immediately recalculate nutrients from per-100g basis.

Never re-query AI for a simple quantity change.

---

# 16. BARCODE FLOW

Barcode should be fast and cheap because no multimodal model is required.

## 16.1 Scanner
Use AVFoundation metadata scanning or VisionKit DataScanner when supported.

Supported:
- UPC-A.
- UPC-E.
- EAN-8.
- EAN-13.

## 16.2 Lookup order
1. Local cache.
2. Open Food Facts or licensed branded-food source.
3. USDA branded foods when applicable.
4. If unresolved:
   - ask user to scan nutrition label (V1.1), or
   - manual entry.

Do not hallucinate product nutrition from barcode digits.

## 16.3 Product screen
Show:
- Product name.
- Brand.
- Serving size.
- Calories/macros per serving.
- Serving quantity stepper.
- Add.

---

# 17. MANUAL FOOD SEARCH

Search is mandatory even in a camera-first app.

## UI
Search bar at top.
Recent foods.
Frequent foods.
Results.

Result row:
- food name.
- source/brand.
- default serving.
- calorie summary.

Search should debounce around 250–350ms.

Rank:
1. exact/prefix.
2. frequent foods.
3. branded name.
4. generic database result.

---

# 18. QUICK ADD

A compact sheet for users who already know macros.

Inputs:
- Calories required.
- Protein optional.
- Carbs optional.
- Fat optional.
- Note optional.
- Meal type/time.

If macros are entered but calories are blank, calculate:
`protein*4 + carbs*4 + fat*9`

If both are entered and differ materially, preserve the user-entered calorie value but show a subtle warning.

---

# 19. HISTORY

## Header
Month/year.
Calendar button.

## Day strip
Horizontal 7-day selector.
Each date may show a tiny completion/progress dot.

## Content
Daily totals then meal cards.

User can:
- change day.
- duplicate meal to today.
- edit meal.
- delete meal.

Do not hide history behind subscription at V1. Users must retain access to their own logged data.

---

# 20. PROGRESS

V1 should be simple.

## 20.1 Weight card
Current.
Change over selected period.
Line chart.

Ranges:
- 7D.
- 30D.
- 3M.
- 6M.
- 1Y.

## 20.2 Calorie consistency
Average consumed vs target.

## 20.3 Protein consistency
Average protein vs target.

Do not make causal claims such as “this food caused weight loss.”

## 20.4 Weight logging
Floating/inline button.
Date.
Weight.
Optional note.

If Apple Health enabled:
read/write based on permission.
Deduplicate imported entries.

---

# 21. CALORIE / MACRO TARGET LOGIC

## 21.1 BMR
When user chooses formula assistance, use Mifflin-St Jeor:

Male equation:
`BMR = 10*weightKg + 6.25*heightCm - 5*age + 5`

Female equation:
`BMR = 10*weightKg + 6.25*heightCm - 5*age - 161`

## 21.2 TDEE
`TDEE = BMR * activityMultiplier`

Multipliers:
- seated: 1.20.
- light: 1.375.
- active: 1.55.
- very active: 1.725.

Store multiplier with profile so changing labels later does not silently recalculate past targets.

## 21.3 Goal adjustment
Recommended starting adjustments:
- Lose slow: TDEE * 0.90.
- Lose moderate: TDEE * 0.85.
- Lose faster: TDEE * 0.80.
- Maintain: TDEE.
- Gain slow: TDEE * 1.05.
- Gain moderate: TDEE * 1.10.
- Gain faster: TDEE * 1.15.

Always:
- round calorie target to nearest 10.
- show estimate wording.
- allow manual edit.
- preserve a target-history record when changed.

## 21.4 Macro grams
For each macro:
`grams = calorieTarget * macroPercentage / kcalPerGram`

- protein 4 kcal/g.
- carbs 4 kcal/g.
- fat 9 kcal/g.

Round grams to nearest whole gram.

## 21.5 Target history
Do not overwrite old targets.

Model:
```swift
struct NutritionTargetSnapshot {
    let effectiveDate: Date
    let calories: Int
    let proteinGrams: Int
    let carbGrams: Int
    let fatGrams: Int
    let source: TargetSource
}
```

This ensures historical charts use the target that existed on that day.

---

# 22. CORE AI PRINCIPLE

**The model should not be the nutrition database.**

Single images are inherently weak at exact portion volume and invisible ingredients. The architecture should therefore separate:

1. Image understanding.
2. Food normalization.
3. Food database resolution.
4. Nutrition math.
5. Validation.
6. User correction.

AI is primarily a parser/estimator.

---

# 23. AI PROVIDER STRATEGY

Build an internal protocol from day one.

```swift
protocol MealVisionProvider {
    var id: String { get }
    func analyze(
        image: MealImage,
        context: MealAnalysisContext
    ) async throws -> VisionMealDraft

    func revise(
        image: MealImage?,
        prior: VisionMealDraft,
        correction: MealCorrection
    ) async throws -> VisionMealDraft
}
```

Provider implementations can include:
- `ManagedOpenAIProvider`
- `AppleFoundationModelProvider`
- `CustomGatewayProvider`
- `MockMealVisionProvider`

The UI never imports OpenAI-specific SDK types.

---

# 24. MODEL RECOMMENDATION — AUGUST 2026

## 24.1 Production managed-cloud path

**Default photo parser:** `gpt-5.6-luna`

Why:
- Supports image input.
- Supports Structured Outputs.
- Optimized for cost-sensitive high-volume workloads.
- More than enough for constrained food detection when given a strict schema.

Recommended reasoning:
- `none` or `low` for normal scans.
- Start with `low` during evaluation and test `none` for latency/cost.

## 24.2 Escalation model

Use `gpt-5.6-terra` only when:
- First result confidence is poor.
- Dish is highly mixed/ambiguous.
- Revision request is complex.
- Evaluations prove Luna underperforms on a defined class.

Do **not** automatically run both models for every scan.

## 24.3 Avoid for normal scans

Do not use `gpt-5.6-sol` for ordinary meal recognition. It is unnecessary cost.

## 24.4 Stable fallback option

`gpt-5.4-mini` is another sensible supported multimodal model if production testing shows it is more predictable for your schema at acceptable cost.

Model choice should be behind remote configuration.

```swift
struct AIModelConfiguration {
    let primaryModel: String
    let escalationModel: String
    let primaryReasoning: ReasoningLevel
    let maxImageDimension: Int
    let confidenceEscalationThreshold: Double
}
```

Never scatter model IDs in view code.

---

# 25. APPLE ON-DEVICE / LOW-COST AI STRATEGY

This is strategically important for reducing ongoing inference cost.

Apple's Foundation Models framework now supports multimodal image understanding in the iOS 27 generation, including image prompting and structured/guided output on compatible Apple Intelligence devices.

Build the provider abstraction now so the app can later route scans like:

```text
if iOS supports required multimodal Foundation Models
and Apple Intelligence model is available
and local evaluation score is acceptable:
    use AppleFoundationModelProvider
else:
    use ManagedOpenAIProvider
```

Advantages:
- Zero per-request token bill for on-device inference.
- Better privacy.
- Lower latency in some cases.
- Offline possibilities.
- Strong App Store story.

Important:
- Do not make the V1 launch depend on beta OS APIs.
- Gate iOS 27-only code with availability checks.
- Keep managed-cloud fallback.
- Run a real benchmark set before routing paid users to the local model.
- “Available” is not the same as “accurate enough.”

Apple has also announced Private Cloud Compute access for qualifying small developers under specified conditions. Treat that as an optimization after the API/eligibility is production-ready, not as a launch dependency.

---

# 26. USER-PROVIDED API KEYS — RECOMMENDATION

The desire is understandable: let customers pay their own inference bill so the app owner does not.

For OpenAI specifically, **do not ship a mainstream feature that stores a raw OpenAI API key in the iPhone app and calls OpenAI directly.** OpenAI's current security guidance says API keys should not be deployed in client-side environments such as mobile apps.

Even if the key belongs to the user, a mobile device is still a client-side environment and keys can be extracted from a compromised device/app process.

## 26.1 Safer alternative: Custom AI Gateway

Offer an advanced option:

**Settings → AI Provider → Custom Gateway**

Fields:
- Gateway URL.
- Bearer token / gateway token.
- Test connection.
- Model label optional.

The customer's gateway stores the actual upstream provider key server-side.

The app sends:
- compressed meal image.
- required JSON schema/version.
- request ID.
- correction context.

Gateway responds with your standard `VisionMealDraft`.

This gives technically advanced users a BYO-inference path without embedding the upstream API key in the client.

## 26.2 Gateway contract

`POST /v1/meal/analyze`

Headers:
```http
Authorization: Bearer <gateway-token>
Content-Type: application/json
X-Plate-Schema-Version: 1
X-Request-ID: <uuid>
```

Body:
```json
{
  "image_base64": "...",
  "mime_type": "image/jpeg",
  "meal_hint": "lunch",
  "locale": "en-US",
  "units": "metric"
}
```

Response:
```json
{
  "schema_version": 1,
  "items": [
    {
      "display_name": "Grilled chicken breast",
      "canonical_query": "chicken breast grilled",
      "estimated_grams": 140,
      "gram_range_low": 110,
      "gram_range_high": 170,
      "preparation": "grilled",
      "confidence": 0.88,
      "brand_or_restaurant": null,
      "visible_additions": [],
      "notes": null
    }
  ],
  "overall_confidence": 0.84,
  "clarifying_question": null
}
```

## 26.3 Consumer business recommendation

Do not require custom gateway setup to use the app.

Best approach:
- small free allowance.
- subscription covers managed AI.
- barcode/manual remains cheap/free.
- Apple on-device AI gradually reduces your cost.
- custom gateway is optional for power users.

A consumer who downloaded a calorie tracker should not need to understand API billing before logging lunch.

---

# 27. MANAGED BACKEND

The app can be local-first while still using a very small backend for cloud AI.

Recommended implementation based on simplicity:
- Firebase Cloud Functions / Cloud Run or another serverless gateway.
- Firebase App Check for abuse reduction.
- No permanent user photo storage by default.
- Request rate limiting.
- Anonymous install identifier.
- Store scan usage counters server-side for abuse/subscription enforcement if needed.

Endpoints:
- `/meal/analyze`
- `/meal/revise`
- `/nutrition/search` only if food source requires secret API credentials.
- `/config` for remote model settings.
- `/health` internal.

## 27.1 Managed AI request flow

```text
iPhone captures image
→ resize/compress locally
→ strip unnecessary metadata
→ request cloud-scan consent if needed
→ backend authenticates app request
→ backend calls configured model
→ backend validates structured JSON
→ backend returns food/portion draft
→ iPhone resolves nutrition or backend resolves nutrition
→ deterministic math
→ user reviews
→ save locally
```

Preferred: nutrition resolution can be backend-side if external APIs require keys. Cache results heavily.

---

# 28. IMAGE PREPROCESSING

Do not upload full 48MP images.

Pipeline:
1. Correct EXIF orientation.
2. Resize longest edge to ~1280–1600 px initially.
3. JPEG quality ~0.72–0.80.
4. Remove GPS/location EXIF.
5. Keep enough detail for sauces/ingredients.
6. Generate local 512px thumbnail for diary.
7. Hash normalized image for retry/idempotency.
8. Upload only once per analysis request when possible.

Benchmark different dimensions because image token/cost and latency depend on input detail.

---

# 29. AI STRUCTURED OUTPUT SCHEMA

The AI output should contain **recognition/portion facts**, not authoritative nutrition.

Suggested Swift domain:

```swift
struct VisionMealDraft: Codable, Sendable {
    let schemaVersion: Int
    let mealName: String
    let items: [VisionFoodItem]
    let overallConfidence: Double
    let clarifyingQuestion: String?
    let uncertaintyNotes: [String]
}

struct VisionFoodItem: Codable, Identifiable, Sendable {
    let id: UUID
    let displayName: String
    let canonicalQuery: String
    let estimatedGrams: Double
    let gramRangeLow: Double
    let gramRangeHigh: Double
    let preparation: String?
    let brandOrRestaurant: String?
    let visibleAdditions: [String]
    let confidence: Double
    let ambiguity: [String]
}
```

Validation:
- items count 1...20.
- confidence clamped 0...1.
- grams > 0 and bounded.
- low <= estimate <= high.
- no NaN/Infinity.
- string lengths bounded.
- reject impossible schema and retry once.

---

# 30. MODEL PROMPT — PHOTO PARSER

Use Structured Outputs / generated schema rather than “JSON-ish” text.

System/developer instruction concept:

```text
You are the visual food parsing component of a calorie logging application.

Your job is to identify visible foods and estimate edible portion mass.
Do not provide medical advice.
Do not invent exact nutrition facts.
Do not claim certainty that the image cannot support.
Do not invent a restaurant or brand unless visually supported.
Separate visually distinct foods when practical.
Include sauces, oils, dressings, toppings, and beverages when visible or strongly implied.
For mixed dishes, use the most useful logging-level decomposition. Do not decompose a normal recipe into dozens of microscopic ingredients.

Estimate grams and a plausible low/high gram range.
Confidence measures recognition + portion confidence.
If an ambiguity would materially change calories and cannot be resolved from the image, ask at most one concise clarifying question.
Return only the required structured object.
```

Request context may include:
- user locale.
- preferred units.
- meal type.
- optional user hint (“homemade chicken alfredo”).
- previous draft on revisions.

Do not include unnecessary profile/health data in the image-analysis prompt.

---

# 31. REVISION PROMPT LOGIC

Correction input:
“Actually that is turkey and there was ranch.”

Send:
- original image if necessary.
- prior structured food draft.
- correction text.

Instruction:
- preserve unaffected items.
- only update items influenced by correction.
- do not silently remove items.
- return same schema.

Then rerun nutrition resolution only for changed items.

This saves cost and avoids unpredictable whole-meal rewrites.

---

# 32. CONFIDENCE LOGIC

Never directly expose raw model confidence as an “accuracy percentage.”

Map internally:

- `>= 0.85`: high.
- `0.65...0.849`: medium.
- `< 0.65`: low.

But overall confidence should also depend on:
- nutrition candidate match confidence.
- portion-range width.
- number of unresolved items.
- whether preparation method was identified.

Example combined score:

```text
recognition = model confidence
portion = 1 - min((high-low)/max(estimate,1), 1)
database = food resolver candidate score

combined =
  recognition*0.45 +
  portion*0.25 +
  database*0.30
```

This is a UX confidence score, not a scientific probability.

User labels:
- High → “Strong match.”
- Medium → “Good estimate.”
- Low → “Check this one.”

---

# 33. CALORIE RANGE LOGIC

For each item, calculate nutrition at:
- low grams.
- estimated grams.
- high grams.

Meal range is sum of item low/high calories.

Example:
```text
rice 150–210g
chicken 110–170g
sauce 20–45g
→ estimated meal 590–700 kcal
```

This is more honest than displaying `643 kcal` as if measured.

Still show a central estimate for tracking.

---

# 34. NUTRITION DATA PIPELINE

## 34.1 Data source strategy

Primary generic source:
- USDA FoodData Central.

Branded:
- USDA branded foods plus Open Food Facts where terms/availability fit.
- Consider a paid source later if barcode hit-rate needs improvement.

Restaurant:
- Start with user correction + known databases.
- Do not scrape restaurant sites in V1.
- Add licensed/official sources selectively later.

## 34.2 Resolver interface

```swift
protocol NutritionRepository {
    func search(
        query: String,
        brand: String?,
        preparation: String?,
        locale: Locale
    ) async throws -> [NutritionCandidate]

    func details(id: NutritionFoodID) async throws -> NutritionFood
}
```

## 34.3 NutritionFood

```swift
struct NutritionFood: Codable, Sendable {
    let id: String
    let source: NutritionSource
    let name: String
    let brand: String?
    let serving: ServingDescriptor?
    let per100g: NutrientSet
}

struct NutrientSet: Codable, Sendable {
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double?
    let sugar: Double?
    let sodiumMg: Double?
}
```

## 34.4 Deterministic scaling

```text
factor = grams / 100
nutrient = per100g * factor
```

Do not ask an LLM to do this arithmetic.

## 34.5 Candidate ranking

Inputs:
- canonical query.
- preparation.
- brand.
- source quality.
- user history.

Score concept:
- lexical similarity 0.35.
- prep match 0.20.
- brand match 0.20.
- source confidence 0.15.
- user-history preference 0.10.

Do not overengineer semantic embeddings before there is evidence they are needed.

---

# 35. NUTRITION VALIDATION

For non-alcohol foods, sanity-check approximate Atwater energy:

`macroCalories = protein*4 + carbs*4 + fat*9`

Compare with source calories.

Do not override official label calories automatically because fiber/sugar alcohols/rounding can create legitimate differences.

Use this only to flag bizarre parsing/database records.

Validation examples:
- negative macros → invalid.
- >100g macro per 100g food unexpectedly → suspicious.
- calories <0 → invalid.
- portion 4,000g for a sandwich → suspicious.
- zero calories + nonzero macros → suspicious.

---

# 36. FOOD MATCH CORRECTION LEARNING

Store user correction mappings locally.

Example:
AI tends to identify user’s recurring breakfast as “Greek yogurt bowl.”

User corrects:
- yogurt brand.
- 170g.
- granola 30g.

Next time:
- visual draft still comes from provider.
- local resolver boosts this saved meal/candidate.
- offer:
  “Looks like your usual yogurt bowl?”

This builds personalization without training a custom vision model.

---

# 37. DATA MODEL

Use SwiftData `@Model` classes at persistence layer, mapped to domain structs where appropriate.

## UserProfile
Fields:
- id.
- createdAt.
- unitSystem.
- age or birthYear if needed.
- heightCm.
- currentWeightKg cached.
- goal type.
- activity multiplier.
- formula choice.
- preferredMacroMode.
- cloudAIConsentVersion.
- cloudAIConsentDate.
- healthKitEnabled.
- onboardingComplete.

## NutritionTarget
- id.
- effectiveFrom.
- calories.
- proteinGrams.
- carbsGrams.
- fatGrams.
- source.
- createdAt.

## Meal
- id UUID.
- eatenAt.
- mealType.
- title.
- notes.
- photoPath optional.
- thumbnailPath optional.
- createdAt.
- updatedAt.
- inputMethod enum.
- overallConfidence optional.
- calorieRangeLow optional.
- calorieRangeHigh optional.
- AIProvider metadata non-secret.
- model version.
- schema version.

## MealItem
- id.
- mealID relation.
- displayName.
- grams.
- servingText.
- nutrients.
- source food ID.
- nutrition source.
- recognition confidence.
- source confidence.
- userEdited boolean.
- preparation.
- original AI name optional.

## WeightEntry
- id.
- date.
- kilograms.
- source local/HealthKit.
- healthKitUUID optional.

## FoodFavorite
- id.
- food source ID.
- custom portions.
- use count.
- lastUsed.

## ScanUsage
Local UI cache only; server is authority for managed scan quota.
- date.
- successful scans.
- failed scans.

---

# 38. IMAGE RETENTION

Default:
- Save a compressed diary thumbnail/meal image locally only if user enables “Save meal photos.”
- Cloud backend should not permanently persist meal photos for standard scan processing.
- Temporary backend objects should have automatic deletion/TTL if storage is necessary.
- State the behavior in privacy policy.

Settings:
**Save meal photos**
- On device only (default recommendation).
- Off.

If future cloud sync uploads photos, ask/update privacy disclosure first.

---

# 39. HEALTHKIT

Request only required types.

Potential write:
- dietaryEnergyConsumed.
- dietaryProtein.
- dietaryCarbohydrates.
- dietaryFatTotal.
- optional fiber/sugar/sodium later.
- bodyMass for user-entered weight.

Potential read:
- bodyMass.
- activeEnergyBurned only if exercise adjustment is introduced.
- Do not request broad health categories “just in case.”

Each saved meal may write correlated nutrition samples.

Store HealthKit identifiers to prevent duplicate writes and support deletion/update.

If a meal changes:
- delete/update previously written samples owned by the app where appropriate.
- write replacement.

App must continue working if HealthKit permission is denied.

---

# 40. EXERCISE CALORIES

Do not include exercise-calorie “eat back” logic in V1 unless specifically validated.

For V1:
- calorie target is static daily target.
- Progress can show activity separately later.

This prevents confusing goal changes and keeps product focused.

---

# 41. SUBSCRIPTION DESIGN

Use StoreKit 2.

Recommended initial plans:
- Free.
- Pro Monthly.
- Pro Annual.

Optional lifetime should be tested later, not assumed.

## 41.1 Free
- Full diary/history.
- Manual food search.
- Quick add.
- Weight tracking.
- Limited AI scans such as 3 per day or a monthly allowance.
- Limited barcode can remain free because cost is low.

The exact free quota should be remote-configurable.

## 41.2 Pro
- Generous/unlimited managed AI scans subject to fair-use abuse controls.
- Advanced scan corrections.
- Advanced progress.
- Saved meal intelligence.
- Future coach.
- Cloud sync when added.
- Premium widgets later.

Do not paywall access to already logged historical data.

## 41.3 Suggested price tests
Start with experiments, not assumptions:
- $7.99 monthly.
- $39.99 annual.
Alternative annual:
- $49.99 if retention/value supports it.

Use App Store price localization.

## 41.4 Paywall visual
Large headline:
**Log food in seconds.**

Background:
premium food photo with dark gradient, but original/licensed artwork only.

Three benefits:
- Unlimited meal scans.
- Faster corrections.
- Deeper progress insights.

Annual plan visually preferred but not deceptive.
Show:
- billing period.
- full price.
- trial terms if any.
- cancel anytime.
- restore purchases.
- privacy.
- terms.

Do not use fake countdown timers.

---

# 42. STOREKIT IMPLEMENTATION

Create `PurchaseManager` as an observable service.

Responsibilities:
- fetch products.
- purchase.
- current entitlements.
- restore/sync purchases.
- transaction listener.
- entitlement state.

```swift
enum ProEntitlement {
    case free
    case pro(expiration: Date?)
}
```

Do not decide entitlement based only on a locally cached boolean.

Always listen for transaction updates.

Support StoreKit Configuration files for local testing.

---

# 43. AI USAGE / QUOTA ENFORCEMENT

For managed cloud AI:
- Backend is authoritative.
- Store app installation ID.
- If account later exists, associate usage with account.
- Verify subscription server-side if needed.
- Rate limit by install/user/IP heuristics.
- Allow failed provider calls not to consume quota.
- A scan consumes quota only after a valid structured result is returned.

Free quota response:
```json
{
  "limit": 3,
  "used": 2,
  "remaining": 1,
  "resets_at": "..."
}
```

When exhausted:
- Never block manual logging.
- Show paywall or custom gateway option.

---

# 44. SECURITY

## Never
- Put your OpenAI key in Info.plist.
- Put it in source.
- Put it in Remote Config.
- Put it in a mobile .env included in build.
- Log it.
- Return it to client.

## Server
- Secret Manager.
- least-privilege service identity.
- rate limiting.
- App Check/attestation.
- request size caps.
- MIME validation.
- structured output validation.
- timeout.
- retry with jitter.
- idempotency/request IDs.

## Client
- Keychain for custom gateway bearer token.
- no sensitive values in UserDefaults.
- redact AI request bodies from production logging.
- strip image location metadata.

---

# 45. PRIVACY UX

Settings → Privacy:
- Cloud meal analysis explanation.
- AI provider disclosure.
- Save meal photos toggle.
- Apple Health permissions shortcut/explanation.
- Export my data.
- Delete my data.
- Privacy policy.
- AI scan consent version.

Before first cloud photo:
- explicit disclosure.
- link to privacy details.
- accept/decline.

If declined:
- manual/barcode continues working.
- cloud scan remains disabled until user changes setting.

---

# 46. ERROR STATES

Create typed domain errors.

```swift
enum MealScanError: LocalizedError {
    case noNetwork
    case permissionDenied
    case imageTooLarge
    case invalidImage
    case providerRateLimited
    case providerUnavailable
    case providerRejected
    case invalidStructuredResponse
    case nutritionLookupFailed
    case quotaExceeded
    case cancelled
}
```

UI behavior:
- No network: “You’re offline. Barcode/manual logging still works.”
- Provider unavailable: retry + manual fallback.
- No recognizable food: “I couldn’t confidently find food in this photo.” Retake / describe.
- Mixed meal uncertain: present draft rather than discarding everything.
- Quota: paywall / manual / custom gateway.
- Permission denied: open Settings.

Never show raw backend stack traces.

---

# 47. OFFLINE BEHAVIOR

Offline usable:
- Today dashboard.
- History.
- Existing meal photos.
- Manual quick add.
- Cached foods/favorites.
- Weight logging.
- Target editing.

Offline unavailable:
- managed cloud photo scan.
- uncached nutrition search.
- server subscription refresh may use cached entitlement grace state.

Queue HealthKit writes if necessary.

---

# 48. ACCESSIBILITY

Required:
- Dynamic Type.
- VoiceOver labels.
- 44x44 minimum tap targets.
- Sufficient contrast.
- Macro meaning not conveyed with color alone.
- Reduced Motion.
- Camera controls have spoken labels.
- Result item rows announce name, portion, calories, confidence.
- Charts expose accessible summaries.
- Do not hide essential text inside images.

---

# 49. DARK MODE

Must ship in V1.

Camera is already dark.
Home/history/settings use semantic colors.

Food photography should not be dimmed excessively.

Use `Color` assets with light/dark variants.

Do not implement dark mode through scattered `colorScheme ==` checks.

---

# 50. ANALYTICS

Use a privacy-conscious analytics layer.

Protocol:
```swift
protocol AnalyticsClient {
    func track(_ event: AnalyticsEvent)
    func setUserProperty(_ value: String?, for key: String)
}
```

Core funnel events:
- onboarding_started.
- onboarding_completed.
- scanner_opened.
- photo_captured.
- scan_started.
- scan_succeeded.
- scan_failed.
- scan_corrected.
- meal_saved.
- barcode_opened.
- paywall_viewed.
- trial_started.
- purchase_completed.
- purchase_restored.
- day_2_return.
- day_7_return.

Properties should not contain:
- meal photo.
- raw food notes.
- health data.
- exact weight.
- raw AI prompt.
- API/gateway token.

Useful scan metrics:
- provider.
- model.
- latency bucket.
- item count.
- confidence bucket.
- correction yes/no.
- error type.

---

# 51. PERFORMANCE TARGETS

- Cold launch to usable Today: target <1.5s on recent supported hardware.
- Today render from local store: perceptually instant.
- Camera open: <700ms target after permission.
- Shutter response: immediate.
- AI result p50: <4s aspirational.
- AI result p95: <10s.
- Barcode recognition: <1s once visible.
- Scroll 60fps/120fps where hardware supports.
- Thumbnail decode off main thread.
- No synchronous network or disk image decoding on main thread.

---

# 52. NETWORKING

Use a typed API client.

```swift
protocol APIClient {
    func send<Request: APIRequest>(_ request: Request) async throws -> Request.Response
}
```

Features:
- async/await.
- Codable.
- timeout.
- retry policy for idempotent transient failures.
- request ID.
- redacted logging.
- cancellation.
- backend error-code decoding.

Do not put URLSession code directly in ViewModels.

---

# 53. ARCHITECTURE

Recommended pragmatic layered structure:

```text
ProjectPlate/
  App/
    ProjectPlateApp.swift
    AppEnvironment.swift
    AppRouter.swift

  DesignSystem/
    Tokens/
    Components/
    Extensions/

  Domain/
    Models/
    UseCases/
    Protocols/

  Data/
    Persistence/
    Repositories/
    Networking/
    Nutrition/
    AI/
    Health/
    Purchases/

  Features/
    Onboarding/
    Today/
    Scanner/
    MealResult/
    FoodSearch/
    History/
    Progress/
    Settings/
    Paywall/

  Resources/
    Assets.xcassets
    Localizable.xcstrings

  Tests/
    Unit/
    Integration/
    Snapshot/
    AIEvals/
```

Do not create a giant “Managers” folder.

---

# 54. STATE MANAGEMENT

Use SwiftUI-native observation.

Examples:
- `@Observable` feature ViewModels.
- Environment dependencies.
- Keep navigation state centralized enough to test.
- No Redux-style framework unless proven necessary.

Each feature ViewModel:
- receives protocols, not concrete networking.
- exposes state.
- handles async tasks.
- transforms domain state into view state.

Views:
- rendering + user actions.
- no nutrition math.
- no network calls.
- no persistence queries scattered across reusable components.

---

# 55. DEPENDENCY INJECTION

`AppEnvironment`:

```swift
struct AppEnvironment {
    let mealRepository: MealRepository
    let nutritionRepository: NutritionRepository
    let mealAnalysisService: MealAnalysisService
    let healthService: HealthService
    let purchaseService: PurchaseService
    let analytics: AnalyticsClient
    let settings: SettingsStore
}
```

Preview environment uses mocks.
Test environment uses deterministic fakes.

---

# 56. MEAL ANALYSIS ORCHESTRATOR

This is the main business logic.

```swift
final class MealAnalysisService {
    let visionProvider: MealVisionProvider
    let nutritionResolver: NutritionResolver
    let validator: MealDraftValidator
}
```

Pseudo-flow:

```text
analyze(image):
    normalizedImage = preprocess(image)
    visionDraft = visionProvider.analyze(normalizedImage)

    validate schema

    for item in visionDraft.items concurrently with cap:
        candidates = nutritionRepository.search(item.canonicalQuery, ...)
        match = resolver.rank(candidates, item)
        nutrition = scale(match.per100g, item.estimatedGrams)
        low = scale(match.per100g, item.gramRangeLow)
        high = scale(match.per100g, item.gramRangeHigh)
        build ResolvedMealItem

    validate totals
    compute meal confidence
    return ReviewableMealDraft
```

Concurrency:
- resolve food candidates in parallel with a reasonable task-group limit.
- cancel children if parent task cancelled.

---

# 57. REVIEWABLE MEAL DRAFT

```swift
struct ReviewableMealDraft: Identifiable, Sendable {
    let id: UUID
    var title: String
    var mealType: MealType
    var eatenAt: Date
    var items: [ResolvedMealItem]
    var confidence: MealConfidence
    var source: MealInputMethod
    var originalImageLocalURL: URL?

    var nutrients: NutrientSet {
        items.reduce(.zero) { $0 + $1.nutrients }
    }
}
```

This exists before persistence.
User edits this draft.
Only save after user confirms.

---

# 58. MEAL SAVE TRANSACTION

Saving should be atomic from user perspective.

```text
User taps Add
→ persist meal + items
→ persist image/thumbnail if enabled
→ enqueue HealthKit write
→ analytics meal_saved
→ close result
```

If HealthKit write fails, the meal still saves locally.
Show a nonblocking status if needed.

---

# 59. PHOTO SCAN EVALUATION DATASET

Do not trust “it seems accurate.”

Before launch, assemble an internal benchmark of at least 300 meal photos.

Categories:
- single foods.
- plated meat + starch + veg.
- pasta.
- salads.
- sandwiches.
- pizza.
- breakfast.
- soups.
- curries/stews.
- desserts.
- beverages.
- restaurant takeout.
- dark lighting.
- top-down.
- angled.
- partial plate.
- sauces.
- mixed casseroles.
- culturally diverse foods.

For each photo, manually record:
- true food identity.
- approximate weighed grams where possible.
- reference calories/macros.

Evaluate:
1. Food detection precision/recall.
2. Portion absolute percentage error.
3. Meal calorie absolute percentage error.
4. Nutrition resolver accuracy.
5. “Top correction needed” rate.
6. Latency.
7. cost/scan.

Version this dataset. Do not upload private test data to public repos.

---

# 60. AI QUALITY TARGETS

Initial launch targets, to tune from real data:
- common single-item food recognition >90%.
- multi-item plate useful draft >85%.
- median meal calorie error <20–25% on controlled benchmark.
- user correction rate <30% after V1 tuning.
- catastrophic wrong-food rate <5%.
- schema failure <0.5%.
- cloud scan completion >98% excluding connectivity.
- p95 provider latency <10s.

These are product goals, not claims for marketing.

Do not advertise an “accuracy percentage” unless independently validated with a defensible methodology.

---

# 61. TESTING

## Unit
- BMR/TDEE.
- macro calculations.
- nutrient scaling.
- calorie range.
- target history.
- food candidate ranking.
- quota rules.
- provider routing.
- JSON decoding/validation.
- date/day boundaries.
- units.
- HealthKit mapping.

## Integration
- mock AI → nutrition resolution.
- persistence save/load.
- edit meal → recalc.
- subscription entitlement state.
- HealthKit with test abstraction.
- backend error decoding.

## UI
- onboarding.
- scan with injected test image/mock response.
- correction.
- meal save.
- history edit/delete.
- paywall.
- denied permissions.

## Snapshot
Use snapshots selectively:
- Today empty.
- Today populated.
- Result high confidence.
- Result low confidence.
- Paywall.
- Dark mode.
- largest Dynamic Type supported layout.

---

# 62. FEATURE FLAGS

```swift
enum FeatureFlag {
    case cloudKitSync
    case nutritionLabelScan
    case voiceLog
    case aiCoach
    case appleFoundationVision
    case customGateway
}
```

Remote flags must have safe local defaults.
App should not break if config endpoint fails.

---

# 63. SETTINGS INFORMATION ARCHITECTURE

## Profile
- Goal.
- Calories/macros.
- Units.

## Tracking
- Meal reminders optional.
- Save meal photos.
- Default meal scan behavior.

## Integrations
- Apple Health.
- AI Provider.
- Custom Gateway (advanced).

## Subscription
- Current plan.
- Upgrade.
- Restore purchases.
- Manage subscription link/system flow.

## Privacy
- Cloud AI.
- Export.
- Delete data.
- Privacy policy.

## About
- Version/build.
- Support.
- Terms.
- Acknowledgments.

Do not put every experimental toggle in production Settings.

---

# 64. CUSTOM GATEWAY SETTINGS

Mark as:
**Advanced**

Screen:
“Use your own AI gateway”

Explanation:
“Connect an HTTPS endpoint you control that implements Project Plate’s meal-analysis contract. Your upstream AI provider credentials stay on your server.”

Fields:
- Endpoint URL.
- Gateway token.
- Test.
- Use for meal scans toggle.

Validation:
- HTTPS only in production.
- sensible URL.
- 10-second test timeout.
- response schema validation.
- never display token after saved.
- Keychain storage.
- delete token on disconnect.

This is not a normal-consumer feature and should not appear in onboarding.

---

# 65. APP STORE / REVIEW REQUIREMENTS

Before submission:
- Complete privacy policy URL.
- Privacy policy accessible in app.
- Camera purpose string.
- Photo picker behavior.
- HealthKit purpose strings if used.
- Explain third-party AI data sharing and obtain explicit permission.
- In-app account deletion if an account system is later added.
- Use StoreKit for digital premium functionality.
- Restore purchases.
- Full review access / demo mode if account-only functions ever exist.
- No broken/hidden purchase flows.
- No medical claims.
- Support contact.
- Terms.

The app should say:
“Nutrition and calorie estimates are for informational tracking and may be inaccurate. This app does not provide medical advice.”

---

# 66. APP ICON DIRECTION

Do not imitate Cal AI.

Concept:
- Warm off-white or black background.
- Simple plate outline.
- Small mint “scan” corner or spark.
- No letters.
- No tiny calorie numbers.
- Strong at 60px.

Potential symbol:
A plate circle with two offset scanning brackets, making camera + nutrition obvious.

Create original vector artwork.

---

# 67. APP STORE SCREENSHOT STORY

1. **Snap it. Track it.**
   Camera over attractive meal.

2. **See calories and macros in seconds.**
   Result screen.

3. **Correct anything with one tap.**
   Portion editor.

4. **Know what’s left today.**
   Today dashboard.

5. **Build consistency, not spreadsheets.**
   Progress.

6. **Your data stays understandable.**
   Source/confidence/privacy screen.

Use actual app UI. Do not use competitor screenshots.

---

# 68. NOTIFICATION STRATEGY

V1 notifications should be optional.

Potential:
- Meal reminder at user-chosen times.
- Daily logging reminder.
- Weekly progress digest later.

Never default to guilt:
Bad: “You forgot to log breakfast!”
Good: “Want to add anything from this morning?”

Request notification permission after the user chooses a reminder feature, not at first launch.

---

# 69. LOCALIZATION

Architect strings with String Catalog from day one.

V1 ship language:
- English.

Do not concatenate UI strings that are difficult to localize.

Store:
- all user-facing strings.
- formatted units.
- dates via locale-aware formatting.

Future:
Spanish is logical early expansion after product-market fit.

---

# 70. UNIT CONVERSION

Store canonical mass/height internally:
- kilograms.
- centimeters.
- grams.

Display based on unit preference.

Never store 170 “weight” without unit semantics.

Helper:
```swift
struct MeasurementFormatterService { ... }
```

---

# 71. DATE / DAY LOGIC

Meal day is based on user calendar/time zone at time of viewing.

Avoid converting “11:30 PM meal” into wrong day due to UTC grouping.

Persist timestamps as Date.
Compute local day boundaries at query time.

When timezone changes, historical meals remain timestamped and are shown according to current product decision. Prefer local event time metadata if travel becomes important later.

---

# 72. DUPLICATION

A huge retention feature:
Meal detail → **Log again**

Flow:
- clone meal into today/current time.
- preserve quantities.
- mark source `duplicated`.
- no AI cost.

Also show frequent meals on Today after enough history.

---

# 73. FOOD FAVORITES

Automatic frequent ranking:
`score = useCountWeight + recencyWeight`

Do not require users to manually favorite everything.

Manual star/favorite still supported later.

---

# 74. CAMERA PERMISSION UX

Pre-permission screen:
“Use your camera to scan a meal.”

System permission then fires.

If denied:
Illustration + “Camera access is off.”
Buttons:
- Open Settings.
- Choose from Photos.
- Add manually.

Never dead-end.

---

# 75. PHOTO ANALYSIS PRIVACY DETAIL

Modal should answer:
- What is sent? Selected/captured meal image and minimal scan context.
- Why? To identify food and estimate portions.
- What is not needed? Name, exact weight goal, HealthKit history should not be included in scan request.
- How long backend keeps image? Prefer transient/no permanent storage; state exact implemented policy.
- Which AI provider? Name provider(s) used in current build/privacy policy.
- Can user opt out? Yes, use barcode/manual/custom local/provider alternatives.

---

# 76. CLOUD PROVIDER ROUTER

```swift
actor MealVisionRouter: MealVisionProvider {
    let localProvider: MealVisionProvider?
    let managedProvider: MealVisionProvider
    let customProvider: MealVisionProvider?
    let config: ProviderRoutingConfig

    func analyze(...) async throws -> VisionMealDraft {
        // honor explicit user selection first
        // then evaluated local provider
        // then managed provider
    }
}
```

Routing priorities:
1. User explicitly selected custom gateway and connection valid.
2. Apple on-device multimodal provider available + feature flag + quality-approved.
3. Managed cloud.

Escalation:
- If local/cheap provider result fails validation/threshold and subscription/quota permits → managed/strong model.
- Avoid repeated loops.

---

# 77. OPENAI BACKEND REQUEST

Use Responses API with image input and Structured Outputs.

Pseudo server-side TypeScript:

```ts
const response = await openai.responses.create({
  model: config.primaryModel,
  reasoning: { effort: "low" },
  input: [{
    role: "user",
    content: [
      { type: "input_text", text: requestPrompt },
      { type: "input_image", image_url: imageDataUrl, detail: "auto" }
    ]
  }],
  text: {
    format: {
      type: "json_schema",
      name: "meal_vision_draft",
      schema: mealVisionSchema,
      strict: true
    }
  }
});
```

Use exact API syntax from current official SDK docs when implementation begins; API SDK shapes can evolve.

Set:
- request timeout.
- request ID.
- `store: false` where supported/appropriate.
- bounded output.
- no web search.
- no unnecessary tools.

---

# 78. SERVER RESPONSE CONTRACT

Backend should return your app contract, not raw provider response.

```json
{
  "request_id": "uuid",
  "provider": "openai",
  "model": "gpt-5.6-luna",
  "latency_ms": 2384,
  "draft": { ... },
  "quota": {
    "remaining": 2
  }
}
```

Client should not depend on OpenAI response structure.

---

# 79. BACKEND CACHING

Safe useful caching:
- nutrition search/query results.
- barcode lookup.
- remote config.
- generic food per-100g data.

Do not globally cache user meal image responses by raw image in a way that creates privacy risk.

A per-device retry cache keyed by image hash/request ID can be short-lived.

---

# 80. COST CONTROL

Levers:
1. Resize images.
2. Use Luna primary.
3. No duplicate AI call for nutrition math.
4. Cache nutrition data.
5. Barcode path no vision model.
6. Duplicate/recent meal path no vision model.
7. Limit free scans.
8. Use Apple on-device vision when quality/OS availability is ready.
9. Escalate only low-confidence scans.
10. Strict output schema to keep responses short.
11. No conversational verbosity in scanner.
12. Rate-limit abuse.
13. Consider batch only for noninteractive analytics/evals, not meal scan UX.

Track:
- cost per successful scan.
- cost per paying subscriber per month.
- scans per active user.
- correction rate per model.

---

# 81. MONETIZATION UNIT ECONOMICS DASHBOARD

Internal metrics:
- new installs.
- onboarding completion.
- first scan rate.
- first meal save rate.
- D1/D7/D30 retention.
- free → paywall.
- paywall → trial.
- trial → paid.
- monthly churn.
- annual refund rate.
- scans/free user.
- scans/paid user.
- AI cost/user.
- nutrition API cost/user.
- revenue/user.
- gross margin.

Do not optimize only for subscription conversion while scan quality is bad.

---

# 82. MVP BUILD PHASES

## Phase 0 — Repository / foundation
Deliverables:
- Xcode project.
- iOS 18.
- SwiftUI app shell.
- design tokens.
- dependency environment.
- tab navigation.
- SwiftData container.
- lint/format decision.
- test targets.
- CI build.

Exit:
App launches with empty tabs in light/dark mode.

## Phase 1 — Onboarding + targets
- onboarding screens.
- target calculator.
- persistence.
- unit tests.
- user can finish onboarding and see target.

Exit:
No AI yet. User gets correct Today hero numbers.

## Phase 2 — Local diary
- meal models.
- quick add.
- meal save/edit/delete.
- history.
- totals.
- local thumbnails.

Exit:
App is a functioning manual tracker.

## Phase 3 — Camera
- permission.
- AVFoundation preview.
- capture.
- photo picker.
- preprocessing.
- mocked analysis response.
- result screen.

Exit:
Camera flow polished using deterministic fake meals.

## Phase 4 — Nutrition data
- repository.
- USDA search.
- per-100g normalization.
- candidate ranking.
- food editor.
- manual search.
- caching.

Exit:
Manual foods use real data.

## Phase 5 — Cloud AI
- backend.
- model provider.
- structured schema.
- result validation.
- nutrition resolution.
- scan quota.
- error states.

Exit:
Real photo → review → saved meal.

## Phase 6 — Barcode
- scan.
- product lookup.
- portion selection.
- add.

## Phase 7 — Progress + weight
- weight entry.
- charts.
- history stats.

## Phase 8 — Apple Health
- permission.
- read/write.
- dedupe.
- integration settings.

## Phase 9 — StoreKit
- products.
- paywall.
- entitlement.
- restore.
- quota behavior.

## Phase 10 — Privacy/release hardening
- consent.
- policy.
- analytics.
- accessibility.
- crash handling.
- dark mode pass.
- snapshot tests.
- performance.
- App Store assets.

## Phase 11 — TestFlight
- 25–50 users.
- collect corrections.
- AI benchmark.
- paywall A/B only after core retention is credible.

---

# 83. CURSOR TASK GRANULARITY

Do not ask Cursor “build the whole app” in one prompt.

Use tasks like:

1. “Create DesignSystem tokens and preview gallery.”
2. “Build onboarding container + first four steps with persisted draft state.”
3. “Implement target calculator with unit tests.”
4. “Implement SwiftData Meal/MealItem persistence and repository.”
5. “Build Today populated/empty states from repository.”
6. “Create CameraService using AVFoundation behind protocol.”
7. “Build MealResult using mock ReviewableMealDraft.”
8. “Implement NutritionRepository and fixture-backed tests.”
9. “Implement MealAnalysisService with mock provider.”
10. “Wire backend once mocks pass.”

Require Cursor after each task:
- summarize changed files.
- run tests.
- list unresolved warnings.
- do not opportunistically rewrite unrelated files.

---

# 84. CODING RULES FOR CURSOR

1. No force unwrap in production paths unless invariant is truly guaranteed and documented.
2. No `try!`.
3. No network calls from SwiftUI `body`.
4. No secrets in client.
5. No giant view >300–400 lines without decomposition.
6. No duplicate design constants.
7. No business logic in button closures beyond calling ViewModel intent.
8. Use previews for reusable components.
9. Add unit tests for nontrivial math.
10. Every new service needs a protocol if it is external/side-effectful.
11. Use typed errors.
12. Use cancellation correctly.
13. Mark cross-actor values Sendable where appropriate.
14. Do not dismiss compile warnings casually.
15. Avoid third-party dependencies unless they remove substantial complexity.
16. Prefer Apple frameworks for camera, keychain wrapper, HealthKit, StoreKit, charts.
17. Keep package count small.
18. Document public/internal APIs where non-obvious.
19. Use TODOs with issue identifiers or remove them.
20. Build before declaring a task complete.

---

# 85. RECOMMENDED DEPENDENCIES

Prefer first party.

Potential third party only if justified:
- Firebase SDK if managed backend/app check/analytics chosen.
- RevenueCat is optional, but StoreKit 2 is enough for V1 and avoids another vendor/cost/data surface.
- A Keychain wrapper can be written small or use a mature tiny library.
- SnapshotTesting library optional.

Avoid:
- giant networking frameworks.
- RxSwift.
- custom chart libraries unless Swift Charts cannot meet the requirement.
- third-party camera SDK.

---

# 86. MOCK DATA

Ship Debug-only fixtures.

Examples:
- chicken rice bowl.
- cheeseburger/fries.
- pancakes.
- pasta.
- salad.
- barcode product.

Use fixtures for SwiftUI previews and UI tests.

Never make developers burn AI tokens to render a preview.

---

# 87. DESIGN COMPONENTS TO BUILD FIRST

- `PrimaryButton`
- `SecondaryButton`
- `IconCircleButton`
- `MetricCard`
- `MacroProgressView`
- `CalorieRing`
- `MealRow`
- `FoodItemRow`
- `ConfidencePill`
- `RoundedSheetContainer`
- `EmptyState`
- `LoadingSkeleton`
- `ScanModePicker`
- `CameraShutterButton`
- `PaywallPlanCard`
- `SettingRow`
- `NumericInputField`

Create a `DesignSystemPreviewView` in Debug to inspect them in all states.

---

# 88. HOME SCREEN ACCEPTANCE CRITERIA

- Correct totals from meals for selected day.
- Correct remaining = target - eaten.
- Over-target represented clearly without failure language.
- Macro totals update when meal edited.
- All interactive controls >=44pt.
- Empty state works.
- Largest supported Dynamic Type does not clip critical values.
- Dark mode correct.
- VoiceOver identifies all metric values.
- Scan button accessible.
- List scrolls smoothly with 50 meals.

---

# 89. SCANNER ACCEPTANCE CRITERIA

- Camera permission not requested until user opens/uses scanner.
- Denied permission has recovery.
- Preview respects orientation.
- Photo captures once per tap.
- Rapid double tap cannot launch duplicate analyses.
- Cancel cancels in-flight client task.
- Uploaded image excludes GPS metadata.
- App handles background/foreground.
- Selected Photos image works.
- Memory does not spike from huge originals.
- Mock provider test can complete full flow offline.

---

# 90. RESULT SCREEN ACCEPTANCE CRITERIA

- Draft can include 1–20 items.
- Total is deterministic sum.
- Editing grams updates totals immediately.
- Deleting item updates totals.
- Adding item updates totals.
- Low confidence is visible but not alarming.
- Range shown for image estimates.
- Source shown.
- Save persists once.
- Repeated tap cannot duplicate meal.
- Back/cancel prompts only if meaningful edits would be lost.
- Accessibility works.

---

# 91. AI ACCEPTANCE CRITERIA

- Strict schema.
- Provider response never rendered directly.
- Invalid response retries max once with safe strategy.
- Provider timeout handled.
- Nutrition math deterministic.
- Every item has source state.
- AI uncertainty survives through UI.
- Provider can be replaced by mock.
- Model ID remotely configurable.
- No user health profile unnecessarily sent with photo.
- Raw image not logged.
- Backend secret never reaches app.

---

# 92. SUBSCRIPTION ACCEPTANCE CRITERIA

- Free app fully usable manually.
- Paywall shows correct localized StoreKit price.
- Purchase entitlement updates without app restart.
- Restore works.
- Cancellation/expiration eventually reflected.
- Transaction listener active.
- AI quota respects entitlement.
- Failed scan not charged.
- Logged data never disappears on downgrade.

---

# 93. FIRST LAUNCH ANALYTICS FUNNEL

Measure:
1. Install/open.
2. Onboarding start.
3. Target created.
4. Today viewed.
5. Scanner opened.
6. Photo captured.
7. Analysis success.
8. Meal saved.
9. Second meal saved.
10. Next-day return.
11. Paywall view.
12. Subscription.

The most important early metric is **successful first meal save**, not paywall conversion.

---

# 94. RETENTION MECHANICS

Good retention:
- fast logging.
- frequent foods.
- duplicate meal.
- progress.
- optional streak.
- weekly summary.

Avoid:
- manipulative streak loss.
- shame.
- constant push notifications.
- hard paywalls before user experiences scan value.

Potential streak:
“Days with at least 2 meals logged” or “Days tracked,” not “days under calories.”

---

# 95. DIFFERENTIATION FROM CAL AI

Our first meaningful differentiation should be **transparent estimates + source-backed nutrition**.

Example result:

> Chicken rice bowl  
> **642 cal**  
> *Estimated 590–700*  
> **Good estimate**

Each item can show:
- estimated quantity.
- nutrition source.
- edit.

This gives the user something valuable that “magic number from image” competitors often underemphasize.

Second differentiation:
**Fix the meal conversationally**
without making the app a chatbot.

Third:
**Local-first diary / Apple-first architecture**
and, when production-ready, on-device Apple Foundation Model routing.

Fourth:
**No API-key nonsense for normal customers.**
The advanced gateway exists only for users who want it.

---

# 96. PRODUCT COPY STYLE

Use:
- short.
- confident.
- factual.
- warm.
- not overly cute.

Good:
“Looks like chicken, rice, avocado, and sauce.”

Bad:
“OMG! Our magical AI found your yummy meal ✨”

Good:
“Portion estimates can vary. Tap an item to adjust it.”

Bad:
“Our revolutionary AI knows exactly what you ate.”

---

# 97. PRIVACY / MEDICAL COPY

Suggested disclaimer:
“Project Plate provides nutrition estimates for general tracking and informational purposes. Estimates may be inaccurate and are not medical advice. Consult a qualified professional for medical or dietary guidance specific to your needs.”

Do not show this on every screen.
Place:
- onboarding target result footer.
- Settings/About.
- Terms.
- App Store description as appropriate.

---

# 98. SUPPORT TOOLING

Debug-only screen:
- app version/build.
- feature flags.
- active model.
- provider.
- entitlement.
- scan quota.
- database count.
- consent version.
- HealthKit auth state.
- last API request ID.
- clear local cache.
- load fixture.
- simulate errors.

This dramatically speeds TestFlight debugging.

Never expose secret keys.

---

# 99. RELEASE CHECKLIST

## Product
- [ ] Onboarding complete.
- [ ] Manual tracking works.
- [ ] Photo scan works.
- [ ] Barcode works.
- [ ] Edit works.
- [ ] History works.
- [ ] Progress works.
- [ ] Settings works.
- [ ] Subscription works.

## UX
- [ ] Light/dark.
- [ ] Dynamic Type.
- [ ] VoiceOver.
- [ ] Reduced Motion.
- [ ] Camera denied.
- [ ] Health denied.
- [ ] Offline.
- [ ] Slow AI.
- [ ] AI failure.
- [ ] Empty diary.

## Privacy/security
- [ ] Privacy policy.
- [ ] AI disclosure.
- [ ] Consent.
- [ ] No secrets in bundle.
- [ ] EXIF stripped.
- [ ] Data deletion.
- [ ] Logs redacted.

## Store
- [ ] Icon.
- [ ] Screenshots.
- [ ] Subtitle.
- [ ] Description.
- [ ] Keywords.
- [ ] IAP approved/configured.
- [ ] Restore.
- [ ] Support URL.
- [ ] Terms.
- [ ] Review notes.
- [ ] Demo instructions if needed.

## Engineering
- [ ] CI passes.
- [ ] Unit tests pass.
- [ ] UI smoke tests pass.
- [ ] No critical warnings.
- [ ] Crash reporting.
- [ ] API timeouts.
- [ ] Backend rate limiting.
- [ ] Production remote config safe defaults.

---

# 100. ANDROID LATER — HOW TO AVOID PAIN NOW

Even though iOS is native, design shared **contracts** now:
- backend REST contracts.
- AI schema.
- nutrition schema.
- entitlement concepts.
- sync record schema.
- analytics event names.

Do not share Swift code with Android.
Share behavior/specification.

Android V2 can use:
- Kotlin + Jetpack Compose.
- Room.
- Health Connect.
- CameraX.
- Google Play Billing.

Backend stays unchanged.

Keep design tokens in a platform-neutral JSON source later:
```json
{
  "brandPrimary": "#63E6BE",
  "radiusCard": 20,
  "spacingScreen": 20
}
```

Do this only when Android work begins; no premature codegen required.

---

# 101. RESEARCH / IMPLEMENTATION NOTES CURRENT AS OF 2026-08-20

- Cal AI’s App Store listing currently positions the app around answering lifestyle questions, snapping a meal photo, and receiving a nutritional breakdown; its U.S. listing showed a 4.8 rating with a very large ratings count and iPhone-first positioning. Use that as market validation, not as a screen-copy source.
- MyFitnessPal currently offers Meal Scan, barcode scanning, macro tracking, voice logging, and other premium nutrition features, confirming that multimodal logging is now an expected category capability.
- Apple HealthKit exposes nutrition types including dietary energy, protein, carbohydrates, total fat, fiber, sugar, sodium, and others.
- Apple App Review requires clear privacy handling, appropriate disclosure of data shared with third-party AI, and StoreKit/IAP for unlocking digital app functionality.
- OpenAI’s current model family includes GPT-5.6 Luna, Terra, and Sol with image inputs and structured outputs. Luna is the cost-sensitive tier; Terra balances intelligence and cost.
- OpenAI explicitly advises developers not to deploy API keys in mobile/client-side apps. This is why the consumer BYOK plan in this spec is a gateway, not raw-key entry.
- Apple’s 2026 Foundation Models updates include multimodal image understanding and provider abstraction in the iOS 27 generation. This is an important future cost/privacy optimization but should be availability-gated and evaluated before production routing.
- USDA FoodData Central provides an API for current food/nutrition data.

Reference URLs for engineering validation:
- https://apps.apple.com/us/app/cal-ai-calorie-tracker/id6480417616
- https://support.myfitnesspal.com/hc/en-us/articles/360045761612-Meal-Scan-FAQ
- https://developer.apple.com/documentation/healthkit/nutrition-type-identifiers
- https://developer.apple.com/app-store/review/guidelines/
- https://developers.openai.com/api/docs/models
- https://developers.openai.com/api/docs/models/gpt-5.6-luna
- https://developers.openai.com/api/docs/models/gpt-5.6-terra
- https://help.openai.com/en/articles/5112595-best-practices-for-api-key
- https://developer.apple.com/documentation/foundationmodels/
- https://developer.apple.com/documentation/foundationmodels/analyzing-images-with-multimodal-prompting
- https://fdc.nal.usda.gov/

Re-check all vendor API syntax, pricing, beta status, and App Store rules immediately before release.

---

# 102. CURSOR MASTER BUILD PROMPT

Paste the following into a fresh Cursor agent after creating the Xcode repository and placing this specification at `/docs/PRODUCT_SPEC.md`.

```text
You are the lead iOS engineer for Project Plate, an iPhone-first AI photo calorie and macro tracker.

The complete source of truth is /docs/PRODUCT_SPEC.md. Read the entire document before modifying code.

Hard constraints:
- Native Swift + SwiftUI.
- iOS 18 minimum.
- iPhone first; no Android/cross-platform code.
- Local-first SwiftData.
- No account required for core use.
- No private AI provider secrets in the client.
- External services hidden behind protocols.
- AI output must be typed structured data.
- AI identifies foods/portions; deterministic nutrition data/math supplies calories/macros whenever possible.
- Camera, HealthKit, StoreKit and accessibility must use native Apple patterns.
- Visual style must follow the design system in the spec and must not copy competitor proprietary assets or exact layouts.
- Build for testability; every external service needs mocks/fakes.
- Do not add unrelated dependencies.
- Do not build future-phase features unless explicitly instructed.

Before coding:
1. Summarize the architecture you inferred from the spec.
2. Propose the initial folder/file tree.
3. Identify any technical contradictions or APIs that need current-doc verification.
4. Create a Phase 0 implementation plan.
5. Wait for approval before large architectural deviations.

For each implementation task:
- Explain which files you will add/change.
- Implement only the requested slice.
- Add/update tests.
- Build/test the project.
- Report compiler/test results.
- List remaining TODOs.
- Never claim success if the project does not compile.
```

---

# 103. FIRST CURSOR TASK AFTER MASTER PROMPT

```text
Implement Phase 0 only.

Create:
- SwiftUI app shell.
- iOS 18 deployment target.
- AppEnvironment dependency container.
- AppRouter/navigation shell.
- Today, History, Progress, Settings placeholder feature modules.
- Native TabView with a visually elevated central Scan action placeholder.
- DesignSystem semantic color, spacing, radius and typography tokens.
- Light/dark asset colors matching PRODUCT_SPEC.md.
- Reusable PrimaryButton, SecondaryButton, MetricCard, MacroProgressView and ConfidencePill.
- A Debug-only DesignSystemPreviewView.
- SwiftData container placeholder.
- Unit test target and one smoke test.
- SwiftUI previews for all components.

Do not add camera, AI, Firebase, HealthKit or StoreKit yet.
Do not add third-party dependencies.

Acceptance:
- App builds.
- Tabs navigate.
- Scan button presents a placeholder full-screen view and dismisses.
- Components render in light and dark mode.
- Dynamic Type does not clip component labels.
- Tests pass.

At the end, report:
- files created/changed.
- build result.
- test result.
- any warnings.
- suggested Phase 1 task breakdown.
```

---

# 104. PRODUCT DECISIONS THAT SHOULD REMAIN CONFIGURABLE

Do not bury these in code:
- Free AI scan limit.
- Monthly/annual paywall placement.
- Primary model.
- Escalation model.
- confidence threshold.
- image max dimension.
- activity multipliers.
- goal adjustment percentages.
- Apple local-provider rollout percentage.
- whether a trial exists.
- whether custom gateway is visible.
- whether CloudKit sync is enabled.

---

# 105. FINAL PRODUCT RULE

When there is a choice between:
- a more impressive AI demo, and
- a faster, clearer, more trustworthy food logger,

choose the food logger.

The winning product is not “ChatGPT sees food.”

The winning product is:

**“I can actually keep tracking because this takes seconds.”**
