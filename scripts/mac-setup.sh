#!/usr/bin/env bash
# One-command setup for running Project Plate on a Mac.
#
#   ./scripts/mac-setup.sh                   checks everything, generates, opens Xcode
#   ./scripts/mac-setup.sh --no-watch        skip the Apple Watch target
#   ./scripts/mac-setup.sh --with-watch      require the Watch target (fail without watchOS SDK)
#   ./scripts/mac-setup.sh --no-open         generate but don't launch Xcode
#   ./scripts/mac-setup.sh --local-xcodegen  build XcodeGen into ~/.local instead of
#                                            using Homebrew (no admin rights needed)
#
# Needs no admin rights unless Xcode itself is unconfigured.
# Safe to re-run at any time.
set -euo pipefail
cd "$(dirname "$0")/.."

bold=$(tput bold 2>/dev/null || true); dim=$(tput dim 2>/dev/null || true)
red=$(tput setaf 1 2>/dev/null || true); grn=$(tput setaf 2 2>/dev/null || true)
ylw=$(tput setaf 3 2>/dev/null || true); rst=$(tput sgr0 2>/dev/null || true)

ok()   { echo "  ${grn}✓${rst} $*"; }
warn() { echo "  ${ylw}!${rst} $*"; }
step() { echo; echo "${bold}$*${rst}"; }
die()  { echo; echo "${red}✗ $*${rst}" >&2; exit 1; }

# True only if we can actually escalate — on managed Macs we often can't.
have_sudo() { sudo -n true 2>/dev/null || sudo -v 2>/dev/null; }

WATCH_MODE=auto
OPEN_XCODE=1
FORCE_LOCAL_XCODEGEN=0
for arg in "$@"; do
  case "$arg" in
    --no-watch)        WATCH_MODE=off ;;
    --with-watch)      WATCH_MODE=on ;;
    --no-open)         OPEN_XCODE=0 ;;
    --local-xcodegen)  FORCE_LOCAL_XCODEGEN=1 ;;
    -h|--help)         sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option: $arg (try --help)" ;;
  esac
done

echo "${bold}Project Plate — Mac setup${rst}"

# ---------------------------------------------------------------- 1. macOS
step "1/6  Checking you're on a Mac"
[[ "$(uname -s)" == "Darwin" ]] || die "This needs macOS. You're on $(uname -s).
   The iOS app cannot be built on Windows or Linux — Apple's SDKs are macOS-only."
ok "macOS $(sw_vers -productVersion) on $(uname -m)"

# ---------------------------------------------------------------- 2. Xcode
step "2/6  Checking Xcode"
if [[ ! -d /Applications/Xcode.app ]]; then
  die "Xcode is not installed in /Applications.

   Install it from the Mac App Store (search \"Xcode\"), then re-run this script.
   It is a ~10 GB download and can take 30-60 minutes. Open it once when it
   finishes so it can install its extra components."
fi
ok "Xcode.app found"

DEVDIR="$(xcode-select -p 2>/dev/null || true)"
if [[ "$DEVDIR" != *"Xcode.app"* ]]; then
  warn "Command line tools point at: ${DEVDIR:-<nothing>}"
  if have_sudo; then
    echo "    ${dim}sudo xcode-select -s /Applications/Xcode.app/Contents/Developer${rst}"
    sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
    ok "switched to Xcode"
  else
    die "They must point at Xcode, and changing that needs admin rights you don't have.

   Ask whoever administers this Mac to run:
     sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

   Or, without admin, set it for your shell only and re-run this script:
     export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer"
  fi
else
  ok "command line tools point at Xcode"
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  warn "Xcode needs its licence accepted / components installed."
  if have_sudo; then
    sudo xcodebuild -license accept || true
    sudo xcodebuild -runFirstLaunch || true
  else
    die "That needs admin rights you don't have.
   Open Xcode once from Applications and accept the prompts by hand, then re-run."
  fi
fi
xcodebuild -version >/dev/null 2>&1 || die "xcodebuild still won't run.
   Open Xcode once from Applications, accept the prompts, then re-run this."

XCVER="$(xcodebuild -version | head -1 | awk '{print $2}')"
XCMAJ="${XCVER%%.*}"
if [[ "$XCMAJ" -lt 16 ]]; then
  die "Xcode $XCVER is too old. This app targets iOS 18, which needs Xcode 16 or newer.
   Update Xcode from the Mac App Store. If the App Store won't offer you a newer
   version, update macOS first (Apple menu ▸ System Settings ▸ General ▸ Software Update)."
fi
ok "Xcode $XCVER (need 16+)"

# ------------------------------------------------------------- 3. Homebrew
# Homebrew is a convenience, not a requirement — XcodeGen can be built locally.
step "3/6  Checking Homebrew (optional)"
if ! command -v brew >/dev/null 2>&1; then
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [[ -x "$candidate" ]] && eval "$("$candidate" shellenv)" && break
  done
fi
if command -v brew >/dev/null 2>&1; then
  ok "Homebrew $(brew --version | head -1 | awk '{print $2}')"
else
  warn "Homebrew not installed — that's fine, XcodeGen will be built in your home folder."
  FORCE_LOCAL_XCODEGEN=1
fi

# ------------------------------------------------------------- 4. XcodeGen
step "4/6  Checking XcodeGen"

# Build XcodeGen from source into ~/.local. Needs no admin rights and never
# touches Homebrew — the escape hatch for shared or managed Macs where
# /opt/homebrew is owned by somebody else.
install_xcodegen_locally() {
  local src="$HOME/.local/src/XcodeGen"
  echo "    Building XcodeGen into ${bold}\$HOME/.local${rst} — no admin needed."
  echo "    ${dim}Compiles from source; a few minutes of build output is normal.${rst}"
  mkdir -p "$HOME/.local/src"
  if [[ -d "$src/.git" ]]; then
    git -C "$src" pull --ff-only || true
  else
    rm -rf "$src"
    git clone --depth 1 https://github.com/yonaskolb/XcodeGen.git "$src"
  fi
  make -C "$src" PREFIX="$HOME/.local" install
  export PATH="$HOME/.local/bin:$PATH"

  # Persist on PATH for future shells.
  local rc
  for rc in "$HOME/.zshrc" "$HOME/.bash_profile"; do
    [[ -e "$rc" ]] || continue
    grep -qF '.local/bin' "$rc" 2>/dev/null && continue
    printf '\n# added by Project Plate mac-setup.sh\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$rc"
    echo "    Added ~/.local/bin to PATH in $(basename "$rc")"
  done
}

# Homebrew can be present but owned by another user. Detect that up front
# instead of letting 'brew install' fail with a wall of chown advice.
brew_is_writable() {
  local prefix
  prefix="$(brew --prefix 2>/dev/null || true)"
  [[ -n "$prefix" && -w "$prefix/Cellar" ]]
}

if command -v xcodegen >/dev/null 2>&1; then
  ok "XcodeGen already installed"
elif [[ "$FORCE_LOCAL_XCODEGEN" -eq 1 ]]; then
  install_xcodegen_locally
elif brew_is_writable; then
  echo "    Not found — installing (${dim}brew install xcodegen${rst})…"
  brew install xcodegen || {
    warn "Homebrew install failed — falling back to a local build."
    install_xcodegen_locally
  }
else
  warn "Homebrew exists but $(brew --prefix 2>/dev/null) is not writable by you."
  echo "    Somebody else installed it on this Mac, so 'brew install' would fail."
  echo "    Skipping Homebrew and building XcodeGen in your home folder instead."
  echo "    ${dim}(With admin you could instead run:"
  echo "     sudo chown -R \$(whoami) $(brew --prefix 2>/dev/null) && brew install xcodegen)${rst}"
  install_xcodegen_locally
fi

command -v xcodegen >/dev/null 2>&1 || die "XcodeGen still isn't available.
   Build it by hand:
     git clone https://github.com/yonaskolb/XcodeGen.git ~/xcodegen-src
     cd ~/xcodegen-src && make PREFIX=\$HOME/.local install
     export PATH=\"\$HOME/.local/bin:\$PATH\""
ok "XcodeGen $(xcodegen --version 2>/dev/null | awk '{print $NF}')"

# ------------------------------------------------------------- 5. Platforms
step "5/6  Checking simulators and SDKs"
if ! xcrun simctl list devices available 2>/dev/null | grep -q "iPhone"; then
  warn "No iPhone simulator installed yet — downloading the iOS platform."
  echo "    ${dim}xcodebuild -downloadPlatform iOS${rst}  (large download, be patient)"
  xcodebuild -downloadPlatform iOS || die "Could not download the iOS simulator.
   Do it from Xcode instead: Xcode ▸ Settings ▸ Components ▸ iOS ▸ Get."
fi
ok "iPhone simulator available: $(xcrun simctl list devices available | grep -m1 'iPhone' | sed 's/^ *//;s/ (.*//')"

HAS_WATCH_SDK=0
xcodebuild -showsdks 2>/dev/null | grep -qi "watchos" && HAS_WATCH_SDK=1

BOOTSTRAP_ARGS=()
case "$WATCH_MODE" in
  on)
    [[ "$HAS_WATCH_SDK" -eq 1 ]] || die "--with-watch was requested but no watchOS SDK is installed.
   Get it via Xcode ▸ Settings ▸ Components ▸ watchOS ▸ Get."
    ok "watchOS SDK present — building the full app including Apple Watch" ;;
  off)
    BOOTSTRAP_ARGS+=(--no-watch)
    ok "skipping the Apple Watch target (--no-watch)" ;;
  auto)
    if [[ "$HAS_WATCH_SDK" -eq 1 ]]; then
      ok "watchOS SDK present — building the full app including Apple Watch"
    else
      BOOTSTRAP_ARGS+=(--no-watch)
      warn "No watchOS SDK installed — building iPhone + widget only."
      echo "    The iPhone app is complete; only the Watch companion is left out."
      echo "    To add it later: Xcode ▸ Settings ▸ Components ▸ watchOS ▸ Get,"
      echo "    then re-run ${dim}./scripts/mac-setup.sh${rst}"
    fi ;;
esac

# ------------------------------------------------------------- 6. Generate
step "6/6  Generating the Xcode project"
./scripts/bootstrap-ios.sh "${BOOTSTRAP_ARGS[@]+"${BOOTSTRAP_ARGS[@]}"}"
[[ -d ProjectPlate.xcodeproj ]] || die "ProjectPlate.xcodeproj was not created."
ok "ProjectPlate.xcodeproj ready"

echo
echo "${grn}${bold}Done.${rst}"
echo
echo "Next, in Xcode:"
echo "  1. Wait for the top bar to stop saying \"Indexing\"."
echo "  2. Scheme selector (top left, next to ▶) → ${bold}ProjectPlate${rst}."
echo "  3. Device selector (just right of it) → any ${bold}iPhone${rst} simulator."
echo "  4. Press ${bold}▶${rst}  (or Cmd-R). First build takes a few minutes."
echo
echo "Full walkthrough + troubleshooting: ${bold}docs/RUN_ON_MAC.md${rst}"

if [[ "$OPEN_XCODE" -eq 1 ]]; then
  echo
  echo "Opening Xcode…"
  open ProjectPlate.xcodeproj
fi
