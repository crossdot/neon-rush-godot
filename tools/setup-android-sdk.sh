#!/usr/bin/env bash
# One-time setup of a project-local Android SDK into .android-sdk/ (kept out of git).
# Idempotent: safe to re-run; only downloads what's missing.
set -euo pipefail
cd "$(dirname "$0")/.."
SDK="$PWD/.android-sdk"
export ANDROID_HOME="$SDK" ANDROID_SDK_ROOT="$SDK"
export ANDROID_USER_HOME="$SDK/.android"   # keep ~/.android writes inside workspace
mkdir -p "$SDK" "$ANDROID_USER_HOME"
export GRADLE_USER_HOME="$PWD/.gradle-home"
export npm_config_cache="$PWD/.npm-cache"

CT="$SDK/cmdline-tools/latest"
if [ ! -x "$CT/bin/sdkmanager" ]; then
  echo ">> downloading command-line tools…"
  TMP="$(mktemp -d)"
  curl -fsSL -o "$TMP/clt.zip" https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
  mkdir -p "$SDK/cmdline-tools"
  unzip -q "$TMP/clt.zip" -d "$SDK/cmdline-tools"
  rm -rf "$CT"; mv "$SDK/cmdline-tools/cmdline-tools" "$CT"
  rm -rf "$TMP"
fi

echo ">> installing SDK packages…"
yes | "$CT/bin/sdkmanager" --sdk_root="$SDK" --licenses >/dev/null 2>&1 || true
"$CT/bin/sdkmanager" --sdk_root="$SDK" \
  "platform-tools" "platforms;android-35" "build-tools;35.0.0"
echo ">> SDK ready at $SDK"
"$CT/bin/sdkmanager" --sdk_root="$SDK" --list_installed 2>/dev/null | sed -n '1,20p'
