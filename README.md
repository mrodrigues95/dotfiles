# dotfiles

Terminal environment for macOS and WSL, managed with home-manager. One repo, one command.

Installs CLI tools (ripgrep, fd, fzf, jq, eza), fish + starship, WezTerm, Zed config, the shared `~/.agents` folder, Pi config, and (optionally) Node via nvm.

## Setup

```sh
git clone https://github.com/mrodrigues/dotfiles.git
cd dotfiles
./bootstrap.sh
```

`bootstrap.sh` runs every step in order; already-installed items self-skip, so re-running is the way to catch up on one thing.

1. **Install Determinate Nix** (skipped if already installed)
2. **Symlink this repo → `~/.dotfiles`**
3. **Fix username in `nix/flake.nix`** — checks against your actual user
4. **`home-manager switch`** — CLI tools + config symlinks
5. **Node.js v24.18.1 via nvm** — node + npm under `~/.local/share/nvm`
6. **Pi CLI via npm** — plus WSL build toolchain + `node-pty` prebuild
7. **(WSL only) WezTerm on Windows** — winget install + config sync

No other prerequisites — Nix comes from the script itself (Claude/Codex/OpenCode and Node are optional extras).

Validate without applying:

```sh
nix flake check ./nix --no-build
nix build ./nix#homeConfigurations.wsl.activationPackage --dry-run   # or .mac.
```

## Daily use

After changing anything in `nix/` (or a Windows-synced config on WSL):

```sh
./refresh.sh
```

Symlinked files (wezterm.lua, zed settings, etc.) are live instantly — no refresh needed on the Linux/macOS side.

## Fish on/off

Fish is optional. The choice is a `~/.nofish` marker (machine-local), honored by bootstrap, refresh, and WezTerm:

- **Enable**: `./bootstrap.sh --fish`, or `rm -f ~/.nofish` + `./refresh.sh`
- **Disable**: `./bootstrap.sh --nofish`, or `touch ~/.nofish` + `./refresh.sh`
- With the marker, home-manager builds the `-nofish` config (no fish) and WezTerm silently falls back to your default shell
- Node works without fish — binaries are in `~/.local/share/nvm/v24.18.1/bin` (the `nvm` command is fish-only)
- If fish is your WSL login shell, switch away first (`chsh`)

## Repo layout

- `nix/flake.nix` — entry point; configs `mac`, `wsl`, and their `-nofish` variants
- `nix/home.nix` — packages, fish, starship, symlinks
- `bootstrap.sh` — first-time setup (runs every step; each self-skips)
- `refresh.sh` — re-apply after changes
- `home/` — the live config files (symlinked into `~`)

## Where config lives

`home/` is the real config. home-manager symlinks `~/.agents`, `~/.config/{wezterm,zed,herdr}`, and `~/.pi/agent/*` to the matching paths in the repo, so editing here edits your live config — no drift. On WSL, native Windows apps can't follow Linux symlinks, so `refresh.sh` also copies wezterm.lua + zed settings to the Windows side. WezTerm pane chords use a CTRL+Q leader.

## Pi

Pi is opt-in; only the authored files under `home/.pi/agent` are managed (settings, extensions, themes, AGENTS.md) — runtime state stays local.

On WSL, Pi's pinned extension needs `node-pty`, which has no Linux prebuild. `bootstrap.sh` installs `build-essential`, pre-installs the package so the compile happens at setup, and rebuilds with zig against your glibc if the load still fails. Manual fallback:

```sh
sudo apt-get install -y build-essential
cd ~/.pi/agent/npm/node_modules/node-pty
nix shell nixpkgs#zig nixpkgs#gnumake -c bash -c \
  "CC='zig cc -target x86_64-linux-gnu.2.39' CXX='zig c++ -target x86_64-linux-gnu.2.39' npm rebuild node-pty"   # 2.39 = your `ldd --version` glibc
```

## Make it yours

- **Username**: bootstrap detects yours and offers to update `nix/flake.nix` (or edit it manually)
- **Host labels**: `mac`, `wsl`, and the `-nofish` variants appear in `flake.nix`, `bootstrap.sh`, and `refresh.sh` — rename all three if you change them