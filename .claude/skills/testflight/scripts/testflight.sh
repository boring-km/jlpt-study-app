#!/usr/bin/env bash
# Ship a new TestFlight build: bump build number → commit → (push) → build+upload → verify.
#
# Usage: testflight.sh [--dry-run] [--no-push] [--no-bump] [--version X.Y.Z]
#   --dry-run    check prerequisites and print the plan; change nothing
#   --no-push    commit the bump locally but do not push
#   --no-bump    use the current pubspec version as-is (build must not already exist in ASC)
#   --version    also set the marketing version (e.g. 1.3.0); build number still +1
set -euo pipefail

DRY=0; PUSH=1; BUMP=1; NEW_VER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --no-push) PUSH=0 ;;
    --no-bump) BUMP=0 ;;
    --version) NEW_VER="$2"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
EXPORT_PLIST="ios/ExportOptions.plist"

# ---- prerequisites --------------------------------------------------------
[[ -f pubspec.yaml ]] || { echo "ERROR: pubspec.yaml not found"; exit 1; }
[[ -f "$EXPORT_PLIST" ]] || { echo "ERROR: $EXPORT_PLIST missing (method=app-store-connect, destination=upload)"; exit 1; }
grep -q "<string>upload</string>" "$EXPORT_PLIST" || { echo "ERROR: $EXPORT_PLIST destination is not 'upload'"; exit 1; }
if [[ -n "$(git status --porcelain)" ]]; then
  if [[ $DRY -eq 1 ]]; then
    echo "WARN: working tree not clean (real run would abort):"; git status --short
  else
    echo "ERROR: working tree not clean — commit or stash first:"; git status --short; exit 1
  fi
fi
command -v flutter >/dev/null || { echo "ERROR: flutter not on PATH"; exit 1; }

CUR_LINE="$(grep -E '^version: ' pubspec.yaml)"
CUR_VER="${CUR_LINE#version: }"
CUR_NAME="${CUR_VER%%+*}"; CUR_BUILD="${CUR_VER##*+}"
[[ "$CUR_BUILD" =~ ^[0-9]+$ ]] || { echo "ERROR: cannot parse build number from '$CUR_VER'"; exit 1; }

if [[ $BUMP -eq 1 ]]; then
  NEXT_NAME="${NEW_VER:-$CUR_NAME}"; NEXT_BUILD=$((CUR_BUILD + 1))
else
  NEXT_NAME="$CUR_NAME"; NEXT_BUILD="$CUR_BUILD"
fi
NEXT_VER="${NEXT_NAME}+${NEXT_BUILD}"

echo "== TestFlight =="
echo "current: $CUR_VER"
echo "next:    $NEXT_VER"
echo "push:    $PUSH   bump: $BUMP   dry-run: $DRY"
if [[ $DRY -eq 1 ]]; then
  echo "(dry run) would: sed version → commit 'chore: bump version to $NEXT_VER' → $( [[ $PUSH -eq 1 ]] && echo push → ) flutter build ipa --release --export-options-plist=$EXPORT_PLIST → verify ContentDelivery.log"
  exit 0
fi

# ---- bump + commit (+ push) -------------------------------------------------
if [[ $BUMP -eq 1 ]]; then
  sed -i '' "s/^version: .*/version: $NEXT_VER/" pubspec.yaml
  git add pubspec.yaml
  git commit -m "chore: bump version to $NEXT_VER

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
  if [[ $PUSH -eq 1 ]]; then git push; fi
fi

# ---- build + upload ---------------------------------------------------------
START_TS=$(date +%s)
set +e
flutter build ipa --release --export-options-plist="$EXPORT_PLIST" 2>&1 | grep -v '^\s*$' | tail -n 25
set -e
# NOTE: flutter prints "Flutter failed to list directory ... build/ios/ipa" in upload mode.
# That is harmless: destination=upload leaves no IPA on disk. The real verdict is the log below.

# ---- verify -----------------------------------------------------------------
LOGDIR="$(find "${TMPDIR:-/tmp}" /var/folders -maxdepth 4 -type d -name 'Runner_*.xcdistributionlogs' -newermt "@$START_TS" 2>/dev/null | sort | tail -n 1)"
if [[ -z "$LOGDIR" ]]; then
  echo "RESULT: UNKNOWN — no xcdistributionlogs directory newer than build start; check Xcode Organizer / App Store Connect."
  exit 3
fi
CDL="$LOGDIR/ContentDelivery.log"
if grep -q "UPLOAD SUCCEEDED" "$CDL" 2>/dev/null; then
  UUID="$(grep -o 'Delivery UUID: [0-9a-f-]*' "$LOGDIR"/*.log 2>/dev/null | head -n 1 | cut -d' ' -f3)"
  echo "RESULT: UPLOAD SUCCEEDED — $NEXT_VER (Delivery UUID ${UUID:-n/a})"
  echo "log: $CDL"
  exit 0
fi
echo "RESULT: UPLOAD FAILED or not confirmed — see $CDL"
grep -i "error\|fail" "$CDL" | grep -vi "noerror\|error: nil\|errorHandler" | tail -n 10
exit 4
