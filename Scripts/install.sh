#!/usr/bin/env bash
# Build Kalendario and install it into /Applications (or ~/Applications if not writable).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Kalendario"
SOURCE="$ROOT/dist/$APP_NAME.app"

"$ROOT/Scripts/build_app.sh"

TARGET_DIR="/Applications"
if [[ ! -w "$TARGET_DIR" ]]; then
  TARGET_DIR="$HOME/Applications"
  mkdir -p "$TARGET_DIR"
  echo "▸ /Applications is not writable, using $TARGET_DIR"
fi

# Replacing the bundle while the app is running fails, so quit it first.
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 1

rm -rf "$TARGET_DIR/$APP_NAME.app"
cp -R "$SOURCE" "$TARGET_DIR/$APP_NAME.app"
echo "✓ Installed in $TARGET_DIR/$APP_NAME.app"

open "$TARGET_DIR/$APP_NAME.app"