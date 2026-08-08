# dotfiles

Terminal environment for macOS and WSL, managed with home-manager. One repo, one command, consistent setup everywhere.

## What you get

- CLI tools (ripgrep, fd, fzf, jq, eza)
- Fish shell with autosuggestions and syntax highlighting
- Starship prompt
- WezTerm (installed via Nix on macOS, via winget on WSL + config synced to Windows side)
- Zed (config synced to Windows side on WSL; install manually)
- Agents config (Claude, Codex, OpenCode) all share one `AGENTS.md`
- Pi config (settings, pinned packages, and local extension/theme directories)

## Prerequisites

- **Nix** - installed automatically by `bootstrap.sh` via Determinate Nix
- **Claude / Codex / OpenCode** (optional) - install any of these to use the shared `AGENTS.md` config
- **Node.js + npm** (optional, for Pi) - Pi is installed via npm; on a fresh machine install Node first (e.g. via [nvm](https://github.com/nvm-sh/nvm)) or accept the skip in `bootstrap.sh`

## Fresh-machine setup

```sh
git clone https://github.com/mrodrigues/dotfiles.git
cd dotfiles
./bootstrap.sh
```

`bootstrap.sh` does five things (six on WSL):
1. Installs Determinate Nix (if not present)
2. Symlinks this repo to `~/.dotfiles`
3. Checks the `username` in `flake.nix` against your actual username, offers to fix if they differ
4. Runs the first `home-manager switch`
5. Optionally installs the Pi CLI via npm (skipped if Node/npm is missing or you decline); on WSL it also installs a build toolchain and pre-builds the pinned extension's native module (`node-pty`) so Pi works on first run
6. (WSL only) Installs WezTerm on Windows via winget and syncs config

After that, `home-manager` is available and you're on the normal workflow below.

### Validate without applying

Once Nix is installed, you can check that the config builds without touching your system:

```sh
nix flake check ./nix --no-build
nix build ./nix#homeConfigurations.mac.activationPackage --dry-run  # macOS
nix build ./nix#homeConfigurations.wsl.activationPackage --dry-run  # WSL
```

## Daily use

Edit the config files in place, then apply:

```sh
./refresh.sh
```

You only need to run this when changing something in `nix/` (packages, shell config, etc.). Symlinked files like `wezterm.lua` update instantly on macOS. On WSL, `refresh.sh` also copies the config to the Windows side so native WezTerm and Zed pick up changes.

## Repo tour

- `nix/flake.nix` - entry point. Defines two `homeConfigurations`: `mac` and `wsl`
- `nix/home.nix` - shared home-manager config: packages, Fish, Starship, and the symlinks described below
- `bootstrap.sh` - first-time setup
- `refresh.sh` - re-applies config after changes
- `home/` - the actual config files that get symlinked into place (WezTerm, Zed, shared `AGENTS.md`, Pi config)

## How the symlinks work

When you run `./refresh.sh`, home-manager creates symlinks like this:

```
~/.config/zed  →  ~/dotfiles/home/.config/zed
~/.config/wezterm  →  ~/dotfiles/home/.config/wezterm
~/.pi/agent/settings.json  →  ~/dotfiles/home/.pi/agent/settings.json
~/.pi/agent/extensions  →  ~/dotfiles/home/.pi/agent/extensions
~/.pi/agent/themes  →  ~/dotfiles/home/.pi/agent/themes
```

This means the files under `home/` are the real files. Editing them here — e.g. opening `home/.config/zed/settings.json` in your editor — is editing your live config instantly. No rebuild, no copying, no drift between what's in the repo and what's on disk.

This works on macOS and Linux. On WSL, the Linux side uses symlinks just the same. However, native Windows apps (WezTerm GUI, Zed GUI) can't follow Linux symlinks, so `refresh.sh` also copies those config files to the Windows filesystem under `/mnt/c/Users/...`. You only need to re-run `refresh.sh` after editing a synced config from the Linux side, or when changing something that isn't just a symlinked file (like a package list or shell config).

## Pi configuration

Pi is an opt-in CLI; this repo does not vendor it. Home Manager links only the authored Pi files below; everything else about Pi stays local to `~/.pi/agent` on each machine.

### Native builds (Linux/WSL)

The `@plannotator/pi-extension` package pulls in `node-pty`, a native module with no prebuilt Linux binary (macOS and Windows ship prebuilds; Linux compiles from source). `bootstrap.sh` handles this automatically when you opt into Pi:

1. Ensures `make` + a C++ compiler, installing `build-essential` via apt when missing (requires sudo)
2. Pre-installs the pinned package so the compile happens during setup, not at first `pi` launch
3. Verifies `node-pty` actually loads; if it fails (e.g. a Nix toolchain on PATH links against a newer glibc than your system glibc), rebuilds it with zig targeting your system glibc version — no sudo needed for the fallback since Nix was already installed in step 1

If the automatic steps fail (e.g. apt/sudo unavailable), do them by hand:

```sh
sudo apt-get install -y build-essential   # Debian/Ubuntu (WSL)
cd ~/.pi/agent/npm/node_modules/node-pty
# replace 2.39 with your `ldd --version` glibc version
nix shell nixpkgs#zig nixpkgs#gnumake -c bash -c \
  "CC='zig cc -target x86_64-linux-gnu.2.39' CXX='zig c++ -target x86_64-linux-gnu.2.39' npm rebuild node-pty"
```

## Make it yours

If you clone this repo, review these before running `bootstrap.sh`:

- **Username**: `bootstrap.sh` detects your username and offers to update `nix/flake.nix`. Or change the `username` lines in `nix/flake.nix` manually.
- **Host label**: `mac` and `wsl` are used in `flake.nix`, `bootstrap.sh`, and `refresh.sh`. If you rename them, update all three.
