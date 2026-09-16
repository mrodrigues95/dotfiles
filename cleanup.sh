#!/usr/bin/env bash
# Unhook the old Nix/home-manager setup BEFORE running ./install.sh.
# Run this only on machines that previously ran the Nix-based bootstrap.
#
#   ./cleanup.sh            preview only (dry-run, changes nothing)
#   ./cleanup.sh --apply    prompted, ordered, idempotent (skips what's done)
#
# Never touched: ~/.pi/agent runtime state (auth.json, models-store.json,
# sessions/), home/ repo content, ~/.local/share/nvm (kept until mise node
# is verified). macOS and WSL aware.
set -euo pipefail

APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

case "$(uname -s)" in
  Darwin) OS="mac" ;;
  Linux)  OS="wsl" ;;
  *)      echo "Unsupported OS: $(uname -s)"; exit 1 ;;
esac

LOGIN_SHELL="$(getent passwd "$(whoami)" 2>/dev/null | cut -d: -f7 || echo "$SHELL")"
[ "$OS" = "mac" ] && LOGIN_SHELL="$(dscl . -read "/Users/$(whoami)" UserShell 2>/dev/null | awk '{print $2}' || echo "$SHELL")"

# Managed paths the Nix setup symlinked into /nix/store (mirrors mise/config.toml [dotfiles]).
STORE_LINKS=(
  "$HOME/.agents"
  "$HOME/.config/wezterm" "$HOME/.config/zed" "$HOME/.config/herdr"
  "$HOME/.config/starship.toml"
  "$HOME/.config/opencode/AGENTS.md"
  "$HOME/.claude/CLAUDE.md" "$HOME/.codex/AGENTS.md"
  "$HOME/.pi/agent/AGENTS.md" "$HOME/.pi/agent/settings.json"
  "$HOME/.pi/agent/extensions" "$HOME/.pi/agent/themes"
  "$HOME/.pi/agent/config/skill-gate.json"
  "$HOME/.pi/agent/pi-blackhole/pi-blackhole-config.json"
)

is_store_link() { [ -L "$1" ] && [[ "$(readlink "$1")" == /nix/store/* ]]; }

run() {
  if [ "$APPLY" = "1" ]; then "$@"
  else echo "    [dry-run] would run: $*"; fi
}

if [ "$APPLY" = "0" ]; then
  echo "Dry-run: Nix traces found on this machine (rerun with --apply to remove):"
else
  echo "==> Removing Nix traces (prompted, skips what's already done)"
fi

# 1. Login shell guard: refuse to pull the shell out from under yourself.
if [[ "$LOGIN_SHELL" == *nix-profile* ]] || [[ "$LOGIN_SHELL" == *fish* && ! -x "$(command -v zsh || true)" ]]; then
  echo "  [!] login shell is $LOGIN_SHELL"
  if [ "$APPLY" = "1" ]; then
    echo "      Refusing --apply while the Nix fish shell is your login shell."
    echo "      Run: chsh -s $(command -v zsh 2>/dev/null || echo /bin/bash)  (then re-login) and rerun ./cleanup.sh --apply"
    exit 1
  fi
else
  echo "  [ok] login shell: $LOGIN_SHELL"
fi

# 2. zsh first — it becomes the login shell, so it must exist before fish dies.
if command -v zsh >/dev/null 2>&1; then
  echo "  [ok] zsh already installed"
else
  echo "  [..] zsh missing"
  if [ "$OS" = "wsl" ]; then
    run sudo apt-get update -qq && run sudo apt-get install -y -qq zsh
  else
    run brew install zsh
  fi
fi

# 3. Home-manager store symlinks. Only links pointing into /nix/store are
# removed; real files/dirs (including ~/.pi/agent runtime state) are kept.
for p in "${STORE_LINKS[@]}"; do
  if is_store_link "$p"; then
    echo "  [..] store link: $p"
    run rm "$p"
  fi
done

# 4. hm-session-vars sourcing + nix PATH leftovers in shell rc files (backed
# up as <rc>.bak next to each edited file).
for rc in "$HOME/.bashrc" "$HOME/.profile" "$HOME/.zshrc"; do
  [ -f "$rc" ] || continue
  if grep -qE 'hm-session-vars|nix-profile|/nix/var/nix/profiles' "$rc" 2>/dev/null; then
    echo "  [..] nix lines in $rc"
    run sed -i.bak -E '/hm-session-vars|nix-profile|\/nix\/var\/nix\/profiles/d' "$rc"
  fi
done
# Fish config belongs to the removed setup; leave the file but neutralize the
# store-sourced line so a stray fish invocation can't fail.
FISH_RC="$HOME/.config/fish/config.fish"
if [ -f "$FISH_RC" ] && grep -q 'hm-session-vars' "$FISH_RC" 2>/dev/null; then
  echo "  [..] hm-session-vars source in fish config"
  run sed -i.bak -E '/hm-session-vars/d' "$FISH_RC"
fi

# 5. Home-manager generations (must run while nix still works — before step 6).
if command -v home-manager >/dev/null 2>&1; then
  echo "  [..] home-manager generations present"
  run home-manager expire-generations '-1 day'
else
  echo "  [ok] no home-manager on PATH"
fi

# 6. Determinate Nix itself; its uninstaller is interactive. Re-run this
# script afterwards to confirm clean.
if [ -e "/nix/nix-installer" ] || command -v nix >/dev/null 2>&1; then
  echo "  [..] Determinate Nix still installed"
  if [ "$APPLY" = "1" ]; then
    read -r -p "      Run '/nix/nix-installer uninstall' now? [y/N] " REPLY
    if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
      [ -e "/nix/nix-installer" ] && sudo /nix/nix-installer uninstall || echo "      no installer binary; remove via the Determinate docs"
    else
      echo "      Skipped — rerun ./cleanup.sh --apply after uninstalling."
    fi
  else
    echo "      [dry-run] would offer: sudo /nix/nix-installer uninstall"
  fi
else
  echo "  [ok] no Nix installation detected"
fi

# 7. Obsolete fish-toggle marker (fish matrix is gone; zsh everywhere).
if [ -f "$HOME/.nofish" ]; then
  echo "  [..] obsolete ~/.nofish marker"
  run rm "$HOME/.nofish"
fi

if [ "$APPLY" = "0" ]; then
  echo ""
  echo "Preview only — nothing changed. When ready: ./cleanup.sh --apply"
  echo "Then: ./install.sh"
else
  echo ""
  echo "==> Done. Verify with ./cleanup.sh (should report all [ok]), then ./install.sh"
fi