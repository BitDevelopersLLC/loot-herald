#!/usr/bin/env python3
"""Watch Blizzard's public patch server for new WoW Forever builds.

Run by .github/workflows/game-watch.yml every 6 hours. It reads the live
version of each product in PRODUCTS from Blizzard's patch server, e.g.

    http://us.patch.battle.net:1119/wowf/versions  ->  1.60.1.70938

and compares it with what this repo knows:

* New **game version** (the interface number changes, e.g. 1.60.1 -> 1.61.0,
  16001 -> 16100): opens a pull request that adds the new interface number
  to LootHerald.toc, plus an issue with the patch-day checklist.
* New **build** of the same version (a hotfix): adds a comment to the
  "Game build log" issue asking for a quick /lh selftest in game.

Without --apply it only prints what it would do (safe to run locally).
Standard library only; needs the `gh` CLI and git when --apply is used.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOC = ROOT / "LootHerald" / "LootHerald.toc"
STATE = ROOT / "tools" / "known-builds.json"

# Blizzard product codes to watch. Add a test-server code here when Blizzard
# publishes one for WoW Forever (none existed as of 2026-11-13).
PRODUCTS = {"wowf": "WoW Forever (live)"}
PATCH_URL = "http://us.patch.battle.net:1119/{product}/versions"
LOG_ISSUE_TITLE = "Game build log (automatic)"
LABEL = "game-update"
KEEP_INTERFACES = 2  # how many interface numbers to keep in the .toc


# --------------------------------------------------------------------------
# Pure helpers (unit-tested in tests/test_check_game_version.py)
# --------------------------------------------------------------------------
def parse_versions(text: str, region: str = "us") -> dict | None:
    """Parse Blizzard's pipe-separated versions file. Returns {build, version}."""
    header = None
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("##"):
            continue
        cols = line.split("|")
        if header is None:
            header = [c.split("!")[0] for c in cols]
            continue
        row = dict(zip(header, cols))
        if row.get("Region") == region and row.get("VersionsName"):
            return {"build": int(row["BuildId"]), "version": row["VersionsName"]}
    return None


def interface_for(version: str) -> int:
    """1.60.1.70938 -> 16001  (major*10000 + minor*100 + patch)."""
    major, minor, patch = (int(x) for x in version.split(".")[:3])
    return major * 10000 + minor * 100 + patch


def toc_interfaces(toc_text: str) -> list[int]:
    m = re.search(r"^## Interface:\s*(.+)$", toc_text, re.M)
    return [int(x) for x in re.findall(r"\d+", m.group(1))] if m else []


def bump_toc(toc_text: str, new_interface: int) -> str:
    """Put the new interface number first and keep the newest older ones."""
    current = toc_interfaces(toc_text)
    if new_interface in current:
        return toc_text
    values = sorted(set([new_interface] + current), reverse=True)[:KEEP_INTERFACES]
    line = "## Interface: " + ", ".join(str(v) for v in values)
    return re.sub(r"^## Interface:.*$", line, toc_text, count=1, flags=re.M)


def decide(live: dict, known: dict | None, toc_ifaces: list[int]) -> str | None:
    """'patch' for a new game version, 'build' for a hotfix build, None if nothing changed."""
    if interface_for(live["version"]) not in toc_ifaces:
        return "patch"
    if not known or known.get("version") != live["version"]:
        return "build"
    return None


def patch_issue_body(product_label: str, live: dict, interface: int) -> str:
    return f"""Blizzard's patch server reports a new {product_label} version: **{live['version']}** (interface **{interface}**).

A pull request adding `{interface}` to `LootHerald.toc` was opened automatically. Patch-day checklist (details in `docs/MAINTENANCE.md`):

- [ ] Read the patch notes: class/talent changes, stat changes, new items, new dungeons
- [ ] In game: `/lh selftest` on two or more characters and paste the output here
- [ ] In game: `/lh test`, one real dungeon run, and a check that tooltips show the Loot Herald line
- [ ] Update `Data/Profiles.lua` weights / `Data/ClassRules.lua` / `Data/TooltipPatterns.lua` if needed
- [ ] Update the hit cap defaults in `Core/Init.lua` if the patch changed hit
- [ ] Set `ns.DATA_REVIEWED_FOR` in `Data/Profiles.lua` to `{'.'.join(live['version'].split('.')[:3])}`
- [ ] `lua tests/run_tests.lua` passes
- [ ] Merge the TOC pull request, bump `## Version`, update CHANGELOG, tag a release
"""


# --------------------------------------------------------------------------
# Side effects
# --------------------------------------------------------------------------
def fetch(product: str) -> dict | None:
    with urllib.request.urlopen(PATCH_URL.format(product=product), timeout=20) as resp:
        return parse_versions(resp.read().decode("utf-8", "replace"))


def run(*cmd: str, check: bool = True) -> str:
    out = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    if check and out.returncode != 0:
        raise RuntimeError(f"{' '.join(cmd)} failed: {out.stderr.strip()}")
    return out.stdout.strip()


def ensure_label() -> None:
    run("gh", "label", "create", LABEL, "--color", "d4af37",
        "--description", "New WoW Forever patch or build", "--force", check=False)


def find_issue(title: str) -> str | None:
    out = run("gh", "issue", "list", "--state", "open", "--label", LABEL, "--limit", "100",
              "--json", "number,title", check=False)
    for issue in json.loads(out or "[]"):
        if issue["title"] == title:
            return str(issue["number"])
    return None


def git_identity() -> None:
    run("git", "config", "user.name", "github-actions[bot]")
    run("git", "config", "user.email", "41898282+github-actions[bot]@users.noreply.github.com")


def save_state(state: dict) -> None:
    STATE.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def handle_build(product: str, label: str, live: dict, state: dict, apply: bool) -> None:
    msg = (f"New {label} build **{live['version']}** detected. Same game version, so no TOC change. "
           f"Quick check: run `/lh selftest` in game and report anything it flags.")
    print(f"[build] {product}: {msg}")
    state[product] = live
    if not apply:
        return
    ensure_label()
    number = find_issue(LOG_ISSUE_TITLE)
    if number:
        run("gh", "issue", "comment", number, "--body", msg)
    else:
        run("gh", "issue", "create", "--title", LOG_ISSUE_TITLE, "--label", LABEL,
            "--body", "Every new WoW Forever build is logged here automatically.\n\n" + msg)
    save_state(state)
    git_identity()
    run("git", "add", str(STATE.relative_to(ROOT)))
    if run("git", "status", "--porcelain", str(STATE.relative_to(ROOT))):
        run("git", "commit", "-m", f"Record {label} build {live['version']}")
        run("git", "push")


def handle_patch(product: str, label: str, live: dict, state: dict, apply: bool) -> None:
    interface = interface_for(live["version"])
    title = f"WoW Forever patch {live['version']} (interface {interface})"
    branch = f"auto/interface-{interface}"
    print(f"[patch] {product}: {title}; would open PR on {branch} and a checklist issue")
    if not apply:
        return
    if run("git", "ls-remote", "--heads", "origin", branch, check=False):
        print("  branch already exists; skipping (PR already open)")
        return
    ensure_label()
    git_identity()
    run("git", "checkout", "-b", branch)
    TOC.write_text(bump_toc(TOC.read_text(encoding="utf-8"), interface), encoding="utf-8")
    state[product] = live
    save_state(state)
    run("git", "add", str(TOC.relative_to(ROOT)), str(STATE.relative_to(ROOT)))
    run("git", "commit", "-m", f"Add interface {interface} for {label} {live['version']}")
    run("git", "push", "-u", "origin", branch)
    pr = run("gh", "pr", "create", "--title", f"Add interface {interface} ({live['version']})",
             "--label", LABEL, "--body",
             f"Automatic: {label} is now {live['version']}. Merge after the in-game checklist in the linked issue passes.")
    if not find_issue(title):
        run("gh", "issue", "create", "--title", title, "--label", LABEL,
            "--body", patch_issue_body(label, live, interface) + f"\nPull request: {pr}\n")
    run("git", "checkout", "-")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--apply", action="store_true", help="create issues/PRs and commit (used by CI)")
    args = parser.parse_args()

    state = json.loads(STATE.read_text(encoding="utf-8")) if STATE.exists() else {}
    toc_ifaces = toc_interfaces(TOC.read_text(encoding="utf-8"))
    print(f"TOC interfaces: {toc_ifaces}")

    for product, label in PRODUCTS.items():
        try:
            live = fetch(product)
        except Exception as exc:  # network trouble shouldn't fail the whole job
            print(f"[warn] {product}: could not read patch server: {exc}")
            continue
        if not live:
            print(f"[warn] {product}: no US version listed")
            continue
        action = decide(live, state.get(product), toc_ifaces)
        print(f"{product}: live {live['version']} -> {action or 'no change'}")
        if action == "patch":
            handle_patch(product, label, live, state, args.apply)
        elif action == "build":
            handle_build(product, label, live, state, args.apply)

    if not args.apply:
        print("(dry run - nothing was changed)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
