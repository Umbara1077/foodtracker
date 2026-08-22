# Running Project Plate on your Mac (never used Xcode before)

This is the zero-assumptions guide. If you have never opened Xcode, start at
[Step 1](#step-1--install-xcode) and do not skip anything.

**The one thing to understand first:** there is no `.xcodeproj` file in this
repository, and that is deliberate. The Xcode project is *generated* from
[`project.yml`](../project.yml) by a tool called XcodeGen. So there is nothing
to double-click until you have run the setup script once. If you go looking for
a project file in Finder and cannot find one, you have not done anything wrong.

---

## TL;DR

Once Xcode is installed and you have the code on your Mac:

```bash
./scripts/mac-setup.sh
```

That checks your whole toolchain, fixes what it can, generates
`ProjectPlate.xcodeproj`, and opens it. Then in Xcode pick an **iPhone
simulator** and press **▶**.

---

## Before you start

| You need | Notes |
|---|---|
| A Mac | Apple Silicon (M1–M4) or Intel, both fine |
| macOS recent enough for Xcode 16+ | Xcode 16 needs roughly macOS Sonoma 14.5 or later |
| ~40 GB free disk space | Xcode plus one simulator runtime is genuinely this big |
| An Apple ID | Free. Only needed to install from the App Store |
| 1–2 hours, mostly waiting | The downloads are the slow part, not the setup |

You do **not** need a paid Apple Developer account ($99/yr) to run the app in
the Simulator. You only need one to install on a physical iPhone — see
[Running on a real iPhone](#running-on-a-real-iphone).

You also do **not** need the backend in `backend/`. With no API URL configured
(the default), the app uses on-device mock meal analysis and runs fully offline.

---

## Step 1 — Install Xcode

1. Open the **App Store** app on your Mac.
2. Search for **Xcode**. The publisher is Apple.
3. Click **Get** / the cloud icon.

It is about a 10 GB download and can take 30–60 minutes, longer on slow wifi.
Let it finish completely.

> **Do not** install "Command Line Tools for Xcode" instead. That is a
> different, smaller thing and it is not enough — it has no simulators and no
> iOS SDK. The setup script checks for this and will tell you if you have the
> wrong one.

## Step 2 — Open Xcode once, by hand

Launch Xcode from Applications and let it finish its first run:

- Accept the licence agreement.
- If it offers to install additional components, say yes and enter your password.
- If it shows a "Platforms" screen offering **iOS**, install it. (If you do not
  see one, the setup script will handle it.)
- If it offers **watchOS** too, installing it gets you the Apple Watch
  companion app. It is optional — skipping it just means you build the iPhone
  app and widget only, which is the whole product minus the watch glance.

Quit Xcode when it is done. You are just getting the first-launch chores out of
the way.

## Step 3 — Get the code onto the Mac

Open **Terminal** (Cmd-Space, type "Terminal", Enter) and run:

```bash
git clone https://github.com/Umbara1077/foodtracker.git
```

```bash
cd foodtracker
```

If `git` is not installed, macOS will pop up a dialog offering to install the
developer tools — accept it, wait, then run the clone again.

## Step 4 — Run the setup script

```bash
./scripts/mac-setup.sh
```

It walks six checks and prints a ✓ or a clear explanation for each:

1. You are on macOS
2. Xcode is installed, selected, licensed, and new enough
3. Homebrew is installed (if not, it prints the official install command for you to run)
4. XcodeGen is installed (installs it via Homebrew if missing)
5. An iPhone simulator exists; whether the watchOS SDK is present
6. Generates `ProjectPlate.xcodeproj` and opens it

It will ask for your password once or twice for the `sudo` steps — that is
Xcode's licence and component install, which genuinely require admin rights.

The script is safe to re-run as many times as you like.

> If it reports no watchOS SDK, it automatically builds **iPhone + widget only**
> and tells you so. That is a complete, working app. Install the watchOS
> component later (Xcode ▸ Settings ▸ Components) and re-run to get the watch app.

## Step 5 — Press play

Xcode is now open on the project. Three things, in order:

1. **Wait for indexing.** The status bar at the top centre will say
   *"Indexing | Processing files"*. Building before this settles produces
   confusing errors. First time, give it a few minutes.

2. **Set the scheme and destination.** Top-left of the window, just right of
   the ▶ and ■ buttons, there are two dropdowns:

   ```
   [ ▶ ] [ ■ ]   ProjectPlate  >  iPhone 16 Pro
                 |__ scheme __|   |_ destination _|
   ```

   - Left dropdown (scheme): **ProjectPlate**
   - Right dropdown (destination): **any iPhone simulator**

   > This is the single most common beginner mistake. If the destination says
   > **"Any iOS Device (arm64)"**, the build will fail with signing errors,
   > because that means "build for a real iPhone". Pick a simulator by name.
   >
   > Pick an **iPhone 16 Pro** or newer if you want to see the Dynamic Island
   > Live Activity.

3. **Press ▶** (or Cmd-R).

The first build compiles the entire app from scratch — several minutes is
normal, and the fans may spin up. Later builds take seconds.

The Simulator app launches on its own and the app starts at onboarding.

---

## What works in the Simulator, and what does not

| Feature | Simulator | Notes |
|---|---|---|
| Onboarding, Today, History, Progress | yes | Full |
| Quick Add, Food Search, manual meals | yes | Use these to put data in |
| Recipe builder / recipe URL import | yes | |
| Meal photo scan, barcode scan, label OCR | no | Needs a real camera |
| Voice quick-add | partial | Uses the Mac's mic; can be flaky |
| Home Screen widget | yes | Long-press simulator home screen, Edit, then **+** |
| Live Activity / Dynamic Island | yes | Use an iPhone 16 Pro simulator |
| Paywall and subscriptions | yes | Fake StoreKit purchases, no real money — the scheme is wired to [`Products.storekit`](../ProjectPlate/Resources/Products.storekit) |
| Apple Health sync | partial | Works best on a real device |
| iCloud / CloudKit sync | no | Needs a paid account and a real device |
| Apple Watch app | yes | Only if you installed the watchOS SDK |

Because the camera does not exist in the Simulator, **use Quick Add or Food
Search** to log meals while you are exploring.

---

## Running the tests

In Xcode: **Product ▸ Test**, or Cmd-U.

From Terminal (this is exactly what CI runs):

```bash
./scripts/ci-ios.sh
```

---

## Troubleshooting

| What you see | What it means / what to do |
|---|---|
| No `.xcodeproj` anywhere in the folder | Expected. Run `./scripts/mac-setup.sh` — it is generated, not committed. |
| `xcodebuild: error: The directory ... does not contain an Xcode project` | Same as above — you have not generated it yet. |
| `bash: ./scripts/mac-setup.sh: Permission denied` | Run `chmod +x scripts/*.sh` then try again. |
| `xcode-select: error: tool 'xcodebuild' requires Xcode` | Only the Command Line Tools are installed. Run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`, or just re-run the setup script — it fixes this. |
| `brew: command not found` right after installing Homebrew | Homebrew printed two "Next steps" commands at the end of its install. Run them, or close and reopen Terminal. |
| `Signing for "ProjectPlate" requires a development team` | Your destination is set to a real device. Change the destination dropdown to an **iPhone simulator**. |
| `error: unable to find a destination matching the provided destination specifier` | No simulator installed. Xcode ▸ Settings ▸ Components ▸ iOS ▸ Get. |
| Anything mentioning **watchOS SDK** or `unsupported platform 'watchos'` | You do not have the watchOS SDK. Run `./scripts/mac-setup.sh --no-watch`, or install it: Xcode ▸ Settings ▸ Components ▸ watchOS. |
| `Cannot find type 'Foo' in scope` on files that obviously exist | Stale generated project. Quit Xcode, run `./scripts/bootstrap-ios.sh`, reopen. |
| Build succeeds but behaves oddly | Product ▸ **Clean Build Folder** (Cmd-Shift-K), build again. |
| Indexing never finishes | Quit Xcode, delete `~/Library/Developer/Xcode/DerivedData`, reopen. |
| Simulator boots to a black screen | Give it a minute on first launch. If stuck: Simulator ▸ Device ▸ Erase All Content and Settings. |
| Xcode will not install, or the App Store offers an old version | Your macOS is too old for Xcode 16. Apple menu ▸ System Settings ▸ General ▸ Software Update. |
| `git status` shows hundreds of new files | Should no longer happen — `.gitignore` now covers the generated project, DerivedData and `node_modules`. |

---

## Important: do not edit settings in Xcode's UI

This project's settings live in [`project.yml`](../project.yml). Every time you
run `bootstrap-ios.sh` or `mac-setup.sh`, `ProjectPlate.xcodeproj` is
**regenerated from scratch**, and any changes you made through Xcode's project
editor are wiped.

- Changing build settings, bundle IDs, capabilities, Info.plist keys → edit `project.yml`.
- Adding a Swift file → just put it in the right folder; sources are globbed by
  directory, then regenerate. You do not add files to targets by hand.
- Never commit `ProjectPlate.xcodeproj`.

---

## Running on a real iPhone

Simulator first. When you want it on your own phone, be aware of a real
constraint.

This app declares three capabilities that **Apple only provisions for paid
Apple Developer Program members** ($99/yr):

- HealthKit
- iCloud / CloudKit (`iCloud.com.projectplate.app`)
- App Groups (`group.com.projectplate.app`, how the widget and watch read your data)

### With a paid account (the clean path)

1. Xcode ▸ Settings ▸ Accounts ▸ **+** ▸ add your Apple ID.
2. Set `DEVELOPMENT_TEAM` in [`project.yml`](../project.yml) for the
   `ProjectPlate`, `ProjectPlateWidget` and `ProjectPlateWatch` targets, then
   regenerate.
3. Register the App Group and the iCloud container in the Apple Developer portal.
4. Plug in your iPhone, pick it as the destination, press ▶.
5. On the phone: Settings ▸ General ▸ VPN & Device Management ▸ trust your
   developer certificate.

See [`docs/APP_STORE_SUBMISSION.md`](APP_STORE_SUBMISSION.md) and
[`docs/TESTFLIGHT.md`](TESTFLIGHT.md) for the full release path.

### With a free Apple ID (limited)

You can side-load a **stripped-down** build only. You have to remove all three
capabilities first, which disables iCloud sync, Health sync, and the
widget/watch data sharing:

1. Change the bundle IDs in `project.yml` to something unique to you
   (e.g. `com.yourname.projectplate`).
2. Empty out the three `.entitlements` files, or remove the
   `CODE_SIGN_ENTITLEMENTS` lines from `project.yml`.
3. Regenerate, set your personal team in Signing & Capabilities, build to device.

Free-account builds also expire after 7 days and must be reinstalled.

**Honest recommendation:** if you just want to see and use the app, stay in the
Simulator. It is the full app minus the camera.

---

## Xcode vocabulary cheat sheet

| Term | What it actually means |
|---|---|
| **Scheme** | Which app plus which settings to build. You want `ProjectPlate`. |
| **Destination** | Where it runs — a named simulator, or a plugged-in device. |
| **Target** | One built thing. Here: the app, the widget, the watch app, the tests. |
| **Product ▸ Clean Build Folder** | Throw away compiled output. The "turn it off and on again" of Xcode. Cmd-Shift-K. |
| **DerivedData** | Xcode's build cache at `~/Library/Developer/Xcode/DerivedData`. Safe to delete. |
| **Signing** | Proving to Apple who built the app. Only matters for real devices. |
| **Capability** | An entitlement like HealthKit or iCloud that Apple must authorise. |

| Shortcut | Does |
|---|---|
| Cmd-R | Build and run |
| Cmd-B | Build only |
| Cmd-U | Run tests |
| Cmd-. | Stop |
| Cmd-Shift-K | Clean build folder |
| Cmd-Shift-O | Jump to any file by name |
