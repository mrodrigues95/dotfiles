#!/usr/bin/env bash
# Re-running is safe: every phase self-skips when converged.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

case "$(uname -s)" in
  Darwin|Linux) ;;
  *) echo "Unsupported OS: $(uname -s) (macOS or WSL/Linux only)"; exit 1 ;;
esac

MISE_BIN="$HOME/.local/bin/mise"

step_install_mise() {
  echo "==> Step 1: mise"
  if [ -x "$MISE_BIN" ]; then
    echo "    mise already installed ($("$MISE_BIN" --version 2>/dev/null || echo unknown)), skipping"
  else
    echo "    installing to ~/.local/bin ..."
    curl --proto '=https' --tlsv1.2 -sSf -L https://mise.run | sh
  fi
  export PATH="$HOME/.local/bin:$PATH"
}

step_symlink_repo() {
  echo "==> Step 2: Symlink this repo to ~/.dotfiles + global config"
  ln -sfn "$DIR" ~/.dotfiles
  # The global config is a separate file holding only [tools]: ours has
  # relative paths, which a symlinked config resolves from its own directory.
  mkdir -p ~/.config/mise
  ln -sfn ~/.dotfiles/mise/global-config.toml ~/.config/mise/config.toml
  echo "    ~/.dotfiles -> $DIR"
  echo "    ~/.config/mise/config.toml -> ~/.dotfiles/mise/global-config.toml"
}

step_guard() {
  echo "==> Step 3: Trust config, check for conflicts"
  # On a fresh machine the config is untrusted and dot commands refuse to run.
  ( cd "$DIR" && "$MISE_BIN" trust >/dev/null 2>&1 || true )
  # A real file/dir where a symlink belongs fails mid-bootstrap; catch it now.
  DRY_OUT="$(cd "$DIR" && "$MISE_BIN" dot apply --dry-run 2>&1)" || {
    echo "$DRY_OUT" | head -8
    echo "    A real file/dir blocks a dotfile link (see path above)."
    echo "    Back it up and remove it, then rerun ./install.sh — or overwrite it with:"
    echo "      mise -C ~/.dotfiles dot apply --force"
    exit 1
  }
  echo "    clean"
}

step_bootstrap() {
  echo "==> Step 4: mise bootstrap (packages -> dotfiles -> tools -> tasks)"
  ( cd "$DIR" && "$MISE_BIN" bootstrap )
  echo ""
  echo "    Next: open a new shell (zsh + starship + tools), then check:"
  echo "      mise doctor && mise bootstrap status --missing"
  echo "    Set zsh as login shell when ready: chsh -s \$(command -v zsh)"
}

step_install_mise
step_symlink_repo
step_guard
step_bootstrap

echo ""
echo "==> Done."
