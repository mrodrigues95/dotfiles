# dotfiles

Terminal environment for macOS and WSL, managed with home-manager. One repo, one command, consistent setup everywhere.

## What you get

- CLI tools (ripgrep, fd, fzf, jq, eza)
- Fish shell with autosuggestions and syntax highlighting
- Starship prompt
- WezTerm config (cross-platform with platform-specific background blur)
- herdr config (install herdr separately)
- opencode agent config

## Prerequisites

- **Nix** - installed automatically by `bootstrap.sh` via Determinate Nix
- **WezTerm** - install separately (`brew install --cask wezterm` on macOS, download from [wezterm.org](https://wezterm.org) on Windows)
- **herdr** - install via Homebrew (`brew install herdr`)

## Fresh-machine setup

```sh
git clone https://github.com/mrodrigues/dotfiles.git
cd dotfiles
./bootstrap.sh
```

`bootstrap.sh` does four things:
1. Installs Determinate Nix (if not present)
2. Symlinks this repo to `~/.dotfiles`
3. Checks the `username` in `flake.nix` against your actual username, offers to fix if they differ
4. Runs the first `home-manager switch`

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

You only need to run this when changing something in `nix/` (packages, shell config, etc.). Symlinked files like `wezterm.lua` update instantly since they're symlinked, not copied.

## Repo tour

- `nix/flake.nix` - entry point. Defines two `homeConfigurations`: `mac` and `wsl`
- `nix/home.nix` - shared home-manager config: packages, Fish, Starship, symlinks
- `home/.config/wezterm/wezterm.lua` - WezTerm config (rose-pine-moon, Hack Nerd Font, platform-specific blur)
- `home/.config/herdr/` - herdr config (symlinked to `~/.config/herdr`)
- `home/AGENTS.md` - opencode agent instructions (blank, edit to your liking)
- `bootstrap.sh` - first-time setup
- `refresh.sh` - re-applies config after changes

## Make it yours

If you clone this repo, review these before running `bootstrap.sh`:

- **Username**: `bootstrap.sh` detects your username and offers to update `nix/flake.nix`. Or change the `username` lines in `nix/flake.nix` manually.
- **Host label**: `mac` and `wsl` are used in `flake.nix`, `bootstrap.sh`, and `refresh.sh`. If you rename them, update all three.
