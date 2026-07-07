#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

case "$(uname -s)" in
  Darwin) FLAKE_HOST="mac" ;;
  Linux)  FLAKE_HOST="wsl" ;;
  *)      echo "Unsupported OS: $(uname -s)"; exit 1 ;;
esac

echo "==> Step 1: Determinate Nix"
if command -v nix >/dev/null 2>&1; then
  echo "    nix already installed, skipping"
else
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

echo "==> Step 2: symlink this repo to ~/.dotfiles"
ln -sfn "$DIR" ~/.dotfiles

echo "==> Step 3: personalize the configured username"
REAL_USER="$(whoami)"
FLAKE_USER="$(sed -nE 's/^[[:space:]]*username = "([^"]+)";.*/\1/p' "$DIR/nix/flake.nix" | head -n1)"
if [ -z "$FLAKE_USER" ]; then
  echo "    Could not find the \"username = \" line in flake.nix."
  echo "    Edit nix/flake.nix yourself before continuing."
  exit 1
elif [ "$FLAKE_USER" != "$REAL_USER" ]; then
  echo "    flake.nix is configured for user \"$FLAKE_USER\", but you are \"$REAL_USER\"."
  read -r -p "    Rewrite flake.nix's \"username = \" line to \"$REAL_USER\"? [y/N] " REPLY
  if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
    if [ "$(uname -s)" = "Darwin" ]; then
      sed -i '' -E "s/^([[:space:]]*username = \")[^\"]+(\";.*)/\1${REAL_USER}\2/" "$DIR/nix/flake.nix"
    else
      sed -i -E "s/^([[:space:]]*username = \")[^\"]+(\";.*)/\1${REAL_USER}\2/" "$DIR/nix/flake.nix"
    fi
    echo "    Updated. Review the change with: git diff nix/flake.nix"
  else
    echo "    Skipped. Edit the \"username = \" line in nix/flake.nix yourself before continuing."
    exit 1
  fi
else
  echo "    flake.nix already matches \"$REAL_USER\", nothing to do."
fi

echo "==> Step 4: first home-manager switch (pinned to release-26.05)"
NIX_BIN="$(command -v nix)"
"$NIX_BIN" run github:nix-community/home-manager/release-26.05#home-manager -- \
  switch --flake ~/.dotfiles/nix#$FLAKE_HOST

if [ "$FLAKE_HOST" = "wsl" ]; then
  echo "==> Step 5: install WezTerm on Windows and sync config"
  echo "    Installing WezTerm via winget..."
  cmd.exe /c 'winget install --id wez.wezterm --accept-source-agreements --accept-package-agreements' || {
    echo "    Warning: winget install failed. Install WezTerm manually from https://wezterm.org"
  }

  WIN_PROFILE="$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r' | sed 's/\\/\//g' | sed 's/^C:/\/mnt\/c/')"
  if [ -n "$WIN_PROFILE" ]; then
    WEZTERM_WIN_DIR="$WIN_PROFILE/.config/wezterm"
    mkdir -p "$WEZTERM_WIN_DIR"
    cp "$DIR/home/.config/wezterm/wezterm.lua" "$WEZTERM_WIN_DIR/wezterm.lua"
    echo "    Synced config to $WEZTERM_WIN_DIR"
  else
    echo "    Warning: Could not detect Windows user profile. Copy wezterm.lua manually."
  fi
fi

echo "==> Done. Use ./refresh.sh for future changes."
