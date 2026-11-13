#!/usr/bin/env bash
# Pack the whole project (code, docs, Claude memory, private notes) into one
# archive whose top folder is LootHerald/, ready to copy to another machine.
# Leaves out .git and caches; tools/setup-dev.sh recreates git on the server.
#
# Usage (Git Bash on Windows, or Linux):  bash tools/package-for-transfer.sh [output-dir]
set -euo pipefail
cd "$(dirname "$0")/.."
SRC_NAME="$(basename "$(pwd)")"
OUT_DIR="${1:-..}"
OUT="$OUT_DIR/LootHerald-transfer-$(date +%Y%m%d).tar.gz"

tar -czf "$OUT" \
    --exclude=.git --exclude=__pycache__ --exclude='*.pyc' --exclude='*.zip' \
    --transform "s,^$SRC_NAME,LootHerald," \
    -C .. "$SRC_NAME"

echo "Created: $(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"
echo "Files:   $(tar -tzf "$OUT" | grep -vc '/$')"
