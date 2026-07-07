#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

case "$(uname -s)" in
  Darwin) FLAKE_HOST="mac" ;;
  Linux)  FLAKE_HOST="wsl" ;;
  *)      echo "Unsupported OS: $(uname -s)"; exit 1 ;;
esac

ln -sfn "$DIR" ~/.dotfiles
exec home-manager switch --flake ~/.dotfiles/nix#$FLAKE_HOST
