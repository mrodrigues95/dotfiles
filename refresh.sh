#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

case "$(uname -s)" in
  Darwin) FLAKE_HOST="mac" ;;
  Linux)  FLAKE_HOST="wsl" ;;
  *)      echo "Unsupported OS: $(uname -s)"; exit 1 ;;
esac

ln -sfn "$DIR" ~/.dotfiles

NIX_BIN="$(command -v nix)"
"$NIX_BIN" run github:nix-community/home-manager/release-26.05#home-manager -- \
  switch --flake ~/.dotfiles/nix#$FLAKE_HOST -b backup

if [ "$FLAKE_HOST" = "wsl" ]; then
  WIN_PROFILE="$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r' | sed 's/\\/\//g' | sed 's/^C:/\/mnt\/c/')"
  if [ -n "$WIN_PROFILE" ]; then
    WEZTERM_WIN_DIR="$WIN_PROFILE/.config/wezterm"
    mkdir -p "$WEZTERM_WIN_DIR"
    cp "$DIR/home/.config/wezterm/wezterm.lua" "$WEZTERM_WIN_DIR/wezterm.lua"

    ZED_WIN_DIR="$WIN_PROFILE/AppData/Roaming/Zed"
    mkdir -p "$ZED_WIN_DIR"
    cp "$DIR/home/.config/zed/settings.json" "$ZED_WIN_DIR/settings.json"
  fi
fi
