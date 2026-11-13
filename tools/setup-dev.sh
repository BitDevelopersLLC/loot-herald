#!/usr/bin/env bash
# One-time setup for developing Loot Herald on a Linux server (bigweb).
# Safe to re-run: it only reports, plus a few harmless fixes. With --install it
# also installs Lua 5.1 with apt (asks for your sudo password).
#
# Usage:  bash tools/setup-dev.sh [--install]
set -uo pipefail
cd "$(dirname "$0")/.."

INSTALL=0
[ "${1:-}" = "--install" ] && INSTALL=1
MISSING=0
ok()   { printf '  \033[32mOK\033[0m       %s\n' "$1"; }
miss() { printf '  \033[33mMISSING\033[0m  %s\n           -> %s\n' "$1" "$2"; MISSING=1; }
have() { command -v "$1" >/dev/null 2>&1; }

echo "Loot Herald developer setup in $(pwd)"
FS_TYPE="$(stat -f -c %T . 2>/dev/null || echo unknown)"
echo "  (filesystem: $FS_TYPE)"
if [ ! -w . ]; then
    echo
    echo "You can't write to this folder. Fix it with:"
    echo "    sudo chown -R \"\$USER\": \"$(pwd)\""
    exit 1
fi
echo
echo "1. Tools"
if have git; then ok "git $(git --version | awk '{print $3}')"; else miss "git" "sudo apt install git"; fi
if have python3; then ok "python3 $(python3 --version | awk '{print $2}')"; else miss "python3" "sudo apt install python3"; fi

LUA=""
for c in lua5.1 luajit lua; do have "$c" && { LUA="$c"; break; }; done
if [ -z "$LUA" ] && [ "$INSTALL" = 1 ]; then
    sudo apt-get update -qq && sudo apt-get install -y lua5.1 && LUA="lua5.1"
fi
if [ -n "$LUA" ]; then ok "Lua for tests: $LUA"; else miss "Lua 5.1 (for the tests)" "sudo apt install lua5.1   or re-run: bash tools/setup-dev.sh --install"; fi

if have gh; then
    ok "GitHub CLI $(gh --version | head -1 | awk '{print $3}')"
    if gh auth status >/dev/null 2>&1; then ok "GitHub CLI is logged in"; else miss "GitHub CLI login" "gh auth login   (account: BitDevelopersLLC)"; fi
else
    miss "GitHub CLI (gh)" "https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
fi
if have claude; then ok "Claude Code $(claude --version 2>/dev/null | head -1)"; else miss "Claude Code" "curl -fsSL https://claude.ai/install.sh | bash"; fi

echo
echo "2. Git"
if [ ! -d .git ]; then
    git init -q -b main && ok "created a new git repo (branch main)"
else
    ok "git repo exists ($(git branch --show-current 2>/dev/null || echo '?'))"
fi
git config core.ignorecase false
# Drives formatted NTFS/exFAT (common for big data disks) can't store the
# executable bit. If so, tell git to ignore permissions so files don't all
# show as changed.
PROBE=".filemode-probe.$$"
touch "$PROBE"
if chmod +x "$PROBE" 2>/dev/null && [ -x "$PROBE" ] && chmod -x "$PROBE" 2>/dev/null && [ ! -x "$PROBE" ]; then
    git config core.filemode true
    ok "file permissions work on this drive"
else
    git config core.filemode false
    echo "  NOTE     this drive doesn't keep file permissions ($FS_TYPE); git is set to ignore them. Run scripts with 'bash tools/...'."
fi
rm -f "$PROBE"
if [ -n "$(git config user.email 2>/dev/null)" ]; then
    ok "git identity: $(git config user.name) <$(git config user.email | sed 's/^[^@]*/.../')>"
else
    miss "git identity" 'git config --global user.name "Your Name" && git config --global user.email "you@example.com"'
fi
if git remote get-url origin >/dev/null 2>&1; then
    ok "GitHub remote: $(git remote get-url origin)"
else
    echo "  --       no GitHub remote yet (creating the public repo needs the owner's OK; see .claude/memory/checkpoint.md)"
fi
chmod +x tools/*.sh tools/*.py 2>/dev/null && ok "scripts marked executable"

echo
echo "3. Tests"
if [ -n "$LUA" ]; then
    if bash tools/run-tests.sh >/tmp/lootherald-tests.log 2>&1; then
        ok "all tests pass ($(grep -E 'passed, [0-9]+ failed' /tmp/lootherald-tests.log | tail -1 | xargs))"
    else
        miss "tests" "see /tmp/lootherald-tests.log"
    fi
else
    echo "  --       skipped (no Lua yet)"
fi

echo
echo "4. Game watcher (dry run - changes nothing)"
if have python3; then
    python3 tools/check_game_version.py 2>&1 | sed 's/^/  /'
else
    echo "  --       skipped (no python3 yet)"
fi

echo
if [ "$MISSING" = 1 ]; then
    echo "Fix the MISSING items above, then run this script again."
else
    echo "Ready. Start Claude Code here (ideally inside tmux):"
    echo "    tmux new -s lootherald      # later: tmux attach -t lootherald"
    echo "    claude"
    echo "Then say: \"Read .claude/memory/checkpoint.md and continue.\""
fi
