# dotfiles

Terminal environment for macOS and WSL, managed with mise. One repo, one command.

Installs CLI tools (ripgrep, fd, fzf, jq, eza, starship, herdr), zsh, WezTerm,
Zed config, the shared `~/.agents` folder, Pi config, and Node 24.

## Setup

```sh
git clone https://github.com/mrodrigues95/dotfiles.git
cd dotfiles
./install.sh
```

`install.sh` installs mise, symlinks this repo → `~/.dotfiles` (and
`mise/global-config.toml` → `~/.config/mise/config.toml`, which puts the
`[tools]` list in every shell), then runs `mise bootstrap`, which converges
in order: OS packages (zsh, build tools, WezTerm + font casks on mac) →
dotfile symlinks → versioned tools (node + CLIs) → the `bootstrap` task
(Pi CLI, node-pty check, WSL Windows-side WezTerm install + config sync).

No other prerequisites. Re-running is safe — every phase self-skips when
already converged.

Validate without applying:

```sh
mise bootstrap --dry-run
mise dot apply --dry-run
mise bootstrap status --missing
```

## Coming from the old Nix setup

Machines that ran the previous Nix/home-manager bootstrap must run this step
first — the old symlinks point into `/nix/store`, and `mise dot`
reports those entries as already `applied` (it only checks that the target
is a link), so `apply` would silently skip them and they would dangle once
Nix is uninstalled. Regular-file conflicts would instead need
`--force-dotfiles`:

```sh
./cleanup.sh            # preview what would be removed (changes nothing)
./cleanup.sh --apply    # prompted, ordered, re-runnable
./install.sh
```

`cleanup.sh` installs zsh first, removes home-manager's store symlinks and
generations, drops Nix PATH lines from rc files (backed up), and offers the
Determinate uninstaller. It never touches `~/.pi/agent` runtime state
(auth, models), `home/` content, or the old nvm Node (kept until mise's
Node is verified). It refuses to run while Nix fish is your current shell —
`chsh` away and re-login first.

After `mise bootstrap` converges and tools check out, uninstall
Determinate Nix (if `cleanup.sh` didn't already):
`/nix/nix-installer uninstall`. Then set zsh as your login shell:
`chsh -s $(command -v zsh)`.

## Daily use

Bootstrap sections live in the repo `mise/config.toml`, so run those from the
repo (`install.sh` does the `cd` for you):

```sh
mise -C ~/.dotfiles bootstrap          # converge everything after pulling / editing
mise -C ~/.dotfiles dot apply          # dotfiles only (faster loop while editing configs)
mise -C ~/.dotfiles dot add -l ~/.newrc # capture a new dotfile into home/
mise -C ~/.dotfiles run bootstrap      # provisioning task only (Pi packages, WSL sync)
```

Dotfile entries live in `mise/config.toml`, not in the tools-only global
config, so pass `-l` when adding new ones.

Symlinked files (`.zshrc`, wezterm.lua, zed settings, agents, …) are live
instantly once linked — `apply` is only needed to create new links.

Useful inspections:

```sh
mise config ls                  # which config files are active
mise ls --current               # selected tool versions
mise tasks ls                   # available tasks
mise dot status                 # dotfile state
mise bootstrap status --missing # anything not yet converged (exit 1 if so)
```

## Repo layout

- `install.sh` — first-time setup (installs mise, links repo, runs bootstrap)
- `mise/config.toml` — OS packages, dotfiles, and the `bootstrap` task
- `mise/global-config.toml` — the `[tools]` list, single source of truth
  (symlinked to `~/.config/mise/config.toml` so every shell gets tools)
- `mise/tasks/bootstrap.sh` — provisioning task (Pi CLI, node-pty, WSL Windows sync)
- `cleanup.sh` — one-time migration off the old Nix setup (dry-run by default)
- `home/` — the live config files (symlinked into `~`)

## Where config lives

`home/` is the real config. `mise dot apply` symlinks `~/.zshrc`,
`~/.agents`, `~/.config/{wezterm,zed,herdr,starship.toml}`, and the
`~/.pi/agent/*` authored files to the matching paths in the repo, so editing
here edits your live config — no drift. On WSL, native Windows apps can't
follow Linux symlinks, so the `bootstrap` task also copies wezterm.lua + zed
settings to the Windows side. WezTerm pane chords use a CTRL+Q leader.

## Shell

zsh only. Prompt via starship; `ls`/`ll`/`la` → eza and `..`/bare
directories via `AUTO_CD`, both in `.zshrc`; completions via compinit. mise
activates in `.zshrc`, so `node`, `rg`, `eza`, … are on PATH in every shell.

## Pi

Pi installs via npm into `~/.local/share/npm-global` (a version-independent
prefix, so Node upgrades don't orphan it). Only the authored files under
`home/.pi/agent` are managed (settings, extensions, AGENTS.md, skill-gate,
pi-blackhole config) — runtime state stays local.

On WSL, Pi's pinned extension needs `node-pty`, which has no Linux prebuild.
The `bootstrap` task rebuilds it with zig (from mise `[tools]`) against your
glibc when the load check fails. Manual fallback:

```sh
sudo apt-get install -y build-essential          # normally done by `mise bootstrap`
cd ~/.pi/agent/npm/node_modules/node-pty
GLIBC=$(getconf GNU_LIBC_VERSION | awk '{print $2}')
CC="zig cc -target x86_64-linux-gnu.$GLIBC" \
CXX="zig c++ -target x86_64-linux-gnu.$GLIBC" mise exec -- npm rebuild node-pty
```
