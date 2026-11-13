# Moving Loot Herald to the bigweb server

The goal: the project lives on **bigweb** (the Ubuntu home server). You SSH in
from any computer, run `claude` in the project folder, and carry on where you
left off. The project's memory (`.claude/memory/`) moves with it.

Replace `you@bigweb` below with the user and address you normally SSH to.

## 1. Copy the package to bigweb (on the Windows PC)

The package is a single file whose top folder is `LootHerald/`. It contains the
code, docs, Claude memory and your private `trademark-search/` notes. It leaves
out `.git`, which is recreated on the server, because there are no commits yet
and the Windows git settings don't suit Linux.

The package is already built:
`C:\Users\rando\Dropbox\SourceCode\repos\BitDevelopersLLC\LootHerald-transfer-20261113.tar.gz`

To rebuild it later, run `bash tools/package-for-transfer.sh` in Git Bash. In
PowerShell:

```powershell
scp "C:\Users\rando\Dropbox\SourceCode\repos\BitDevelopersLLC\LootHerald-transfer-20261113.tar.gz" you@bigweb:~/
```

## 2. Unpack and set up (on bigweb)

The project folder on bigweb is **`/mnt/bigdata/projects/loot-herald`**. Its
name matches the GitHub repo `loot-herald`. The package's top folder is
`LootHerald/`, so `--strip-components=1` unpacks its contents straight into
`loot-herald/`.

```bash
ssh you@bigweb
mkdir -p /mnt/bigdata/projects/loot-herald
tar -xzf ~/LootHerald-transfer-20261113.tar.gz -C /mnt/bigdata/projects/loot-herald --strip-components=1
cd /mnt/bigdata/projects/loot-herald
bash tools/setup-dev.sh --install          # checks tools, installs Lua 5.1, creates git, runs tests
```

Don't rename the **inner** `LootHerald/` folder. That one is the addon, and
WoW needs its name to match `LootHerald.toc`.

If `mkdir` or the setup script says you can't write there, `/mnt/bigdata` is
probably owned by root. Fix it once with
`sudo chown -R "$USER": /mnt/bigdata/projects`.

The setup script also detects whether the drive is NTFS or exFAT, which can't
store file permissions. If it is, git is told to ignore permissions so files
don't all show as changed.

`setup-dev.sh` reports each item as **OK** or **MISSING** with the command that
fixes it. Re-run it until everything is OK. It checks:
- git, python3, and Lua 5.1 for the tests. `--install` adds Lua with apt.
- The GitHub CLI and its login. Run `gh auth login` with the `BitDevelopersLLC` account.
- Claude Code: `curl -fsSL https://claude.ai/install.sh | bash`, then run
  `claude` once to log in. Over SSH it prints a link to open in your browser.
- Your git name and email: `git config --global user.name ...` and `user.email ...`.
- That all tests pass and the game watcher can reach Blizzard's patch server.

## 3. Claude Code settings on bigweb (once)

Your memory rule is that memory lives in the project folder, never in
`~/.claude/`. Turn off machine-local auto memory on bigweb too. In
`~/.claude/settings.json`:

```json
{ "autoMemoryEnabled": false }
```

If the file already exists, merge this line in rather than overwriting it.
The project's `CLAUDE.md` already tells Claude to keep memory in
`.claude/memory/`.

## 4. Start working

Use tmux so a dropped SSH connection doesn't end the session:

```bash
cd /mnt/bigdata/projects/loot-herald
tmux new -s lootherald        # reconnect later with: tmux attach -t lootherald
claude
```

Then say: **"Read .claude/memory/checkpoint.md and continue."**

## 5. Testing in game (the game runs on your Windows PC)

Code goes from bigweb to GitHub, and from GitHub to the PC.

1. Once the GitHub repo exists, Claude pushes changes from bigweb (with your OK).
2. **One-time setup on the Windows gaming PC:** clone the repo, then link the
   addon folder into WoW so `git pull` updates the game copy.

   ```powershell
   git clone https://github.com/BitDevelopersLLC/loot-herald.git C:\dev\loot-herald
   cmd /c mklink /J "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\LootHerald" "C:\dev\loot-herald\LootHerald"
   ```

   Adjust the WoW path if it's installed somewhere else. The junction means no
   copying.
3. Each test: `git pull` in `C:\dev\loot-herald`, then restart WoW (for new
   files) or `/reload` (for changed files).

**Before the repo exists**, copy just the addon folder back to the PC instead.
In PowerShell on the PC:

```powershell
scp -r you@bigweb:/mnt/bigdata/projects/loot-herald/LootHerald "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\"
```

## 6. Retire the Dropbox copy

After bigweb is working (setup-dev.sh says Ready, and Claude has resumed
there), move the Dropbox folder `...\BitDevelopersLLC\WOWDungeonDrop` into
`...\BitDevelopersLLC\_Archive\`. That way nobody edits two copies. The
workspace memory index in Dropbox already points to bigweb.
