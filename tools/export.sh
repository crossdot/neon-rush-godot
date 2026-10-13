#!/usr/bin/env bash
# NEON RUN — воспроизводимый Godot-экспорт (Android APK + Linux десктоп).
# Работает и в песочнице: пути данных/конфига берутся из XDG_* (иначе ~/.local, ~/.config).
# Флаги:
#   --with-android   дополнительно установить Android SDK и собрать APK
#   --linux-only     собрать только Linux бинарник (не тянуть Android SDK)
#   GODOT_BIN=...    переопределить бинарник (по умолчанию godot)
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT_BIN="${GODOT_BIN:-godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"          # репозиторий (для tools/setup-android-sdk.sh)
WITH_ANDROID=0
LINUX_ONLY=0
for a in "$@"; do
  case "$a" in
    --with-android) WITH_ANDROID=1 ;;
    --linux-only)   LINUX_ONLY=1 ;;
    *) echo "unknown arg: $a" >&2; exit 1 ;;
  esac
done

# --- версия движка и каталоги данных/шаблонов ---
VER_FULL="$( "$GODOT_BIN" --version 2>/dev/null | tr -d '[:space:]' )"
VER="$( printf '%s' "$VER_FULL" | sed -E 's/^([0-9][0-9.]*\.stable).*/\1/' )"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/godot"
TPL_ROOT="$DATA_DIR/export_templates"
TPL_DIR="$TPL_ROOT/$VER"
# editor settings лежит как editor_settings-<major>.<minor>.tres
MAJMIN="$( printf '%s' "$VER" | sed -E 's/^([0-9]+\.[0-9]+).*/\1/' )"
EDSET="$CONF_DIR/editor_settings-$MAJMIN.tres"

echo "godot=$GODOT_BIN ver=$VER data=$DATA_DIR"

# --- 1. экспорт-шаблоны (скачать, если нет) ---
if [ ! -f "$TPL_DIR/version.txt" ]; then
  echo ">> installing export templates ($VER)…"
  mkdir -p "$TPL_DIR"
  TMP="$(mktemp -d)"
  TPZ="$(mktemp)"
  curl -fsSL -o "$TPZ" "https://github.com/godotengine/godot/releases/download/$VER/Godot_${VER}_export_templates.tpz"
  unzip -j -o "$TPZ" 'templates/version.txt' 'templates/linux_debug.x86_64' 'templates/linux_release.x86_64' \
     'templates/android_debug.apk' 'templates/android_release.apk' 'templates/android_source.zip' \
     'templates/icudt_godot.dat' -d "$TPL_DIR" >/dev/null 2>&1
  rm -rf "$TPZ" "$TMP"
  echo "   -> $TPL_DIR"
fi

# --- 2. Android SDK (только с --with-android) ---
ANDROID_SDK="$ROOT/.android-sdk"
JAVA_HOME="${JAVA_HOME:-}"
if [ "$LINUX_ONLY" = "0" ]; then
  if [ ! -x "$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager" ]; then
    echo ">> setting up Android SDK…"
    bash "$ROOT/tools/setup-android-sdk.sh"
  fi
  if [ -z "$JAVA_HOME" ]; then
    JH="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
    JAVA_HOME="${JH:-}"
  fi
  # прописать пути SDK/JDK в editor settings
  if [ -n "$JAVA_HOME" ] && [ -d "$ANDROID_SDK/platform-tools" ] && [ -d "$ANDROID_SDK/build-tools" ]; then
    python3 - "$EDSET" "$JAVA_HOME" "$ANDROID_SDK" <<'PY'
import sys, os
path, java, sdk = sys.argv[1], sys.argv[2], sys.argv[3]
def setline(lines, key, val):
    for i, l in enumerate(lines):
        if l.startswith(key + ' =') or l.startswith(key + '='):
            lines[i] = key + ' = "' + val + '"'
            return
    lines.append(key + ' = "' + val + '"')
os.makedirs(os.path.dirname(path), exist_ok=True)
lines = []
if os.path.exists(path):
    lines = open(path, encoding='utf-8').read().splitlines()
setline(lines, 'export/android/java_sdk_path', java)
setline(lines, 'export/android/android_sdk_path', sdk)
open(path, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
print('   -> editor settings updated:', path)
PY
  fi
fi

# --- 3. экспорт ---
mkdir -p build
echo ">> exporting Linux…"
"$GODOT_BIN" --headless --path . --export-debug "Linux/X11" build/neon-run.x86_64 || true
if [ "$WITH_ANDROID" = "1" ] && [ "$LINUX_ONLY" = "0" ]; then
  echo ">> exporting Android APK…"
  "$GODOT_BIN" --headless --path . --export-debug Android build/neon-run.apk
  echo "APK: $(pwd)/build/neon-run.apk"
fi
echo "DONE."
