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

echo "==> Done. Use ./refresh.sh for future changes."
