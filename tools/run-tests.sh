#!/usr/bin/env bash
# Run every offline test: the addon's Lua logic and the Python game watcher.
# Usage (from anywhere):  bash tools/run-tests.sh
set -euo pipefail
cd "$(dirname "$0")/.."

LUA=""
for candidate in lua5.1 luajit lua; do
    if command -v "$candidate" >/dev/null 2>&1; then LUA="$candidate"; break; fi
done
if [ -z "$LUA" ]; then
    echo "No Lua interpreter found. Install one:  sudo apt install lua5.1   (or: luajit)"
    exit 1
fi

echo "== Lua tests ($LUA - WoW uses Lua 5.1)"
"$LUA" tests/run_tests.lua

echo "== Python tests (game watcher)"
python3 -m unittest discover -s tests -p "test_*.py"
