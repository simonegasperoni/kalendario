#!/usr/bin/env bash
# Build and launch Kalendario.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/Scripts/build_app.sh"
open "$ROOT/dist/Kalendario.app"