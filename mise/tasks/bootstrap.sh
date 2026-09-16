#!/usr/bin/env bash
# mise bootstrap task: whatever the declarative phases can't express.
# Runs on every `mise bootstrap`, so every step must be repeat-safe
# ([tools] node/jq/zig are already on PATH when it runs).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
NPM_GLOBAL="$HOME/.local/share/npm-global"

step_npm_prefix() {
  # A version-independent prefix, so `pi` survives node upgrades.
  if [ "$(npm config get prefix 2>/dev/null)" != "$NPM_GLOBAL" ]; then
    echo "--> npm: setting global prefix to $NPM_GLOBAL"
    npm config set prefix "$NPM_GLOBAL"
  fi
  case ":$PATH:" in
    *":$NPM_GLOBAL/bin:"*) ;;
    *) export PATH="$NPM_GLOBAL/bin:$PATH" ;;
  esac
}

step_pi() {
  echo "--> pi: checking CLI"
  if ! command -v pi >/dev/null 2>&1; then
    echo "    installing @earendil-works/pi-coding-agent ..."
    npm install -g --ignore-scripts @earendil-works/pi-coding-agent
  else
    echo "    pi already installed ($(pi --version 2>/dev/null || echo unknown)), skipping"
  fi

  echo "--> pi: checking pinned extension packages"
  while IFS= read -r PI_PKG; do
    [ -n "$PI_PKG" ] || continue
    echo "    pi install $PI_PKG"
    pi install "$PI_PKG" || echo "    WARNING: package install failed for $PI_PKG (pi retries at startup)"
  done < <(jq -r '.packages[]? // empty' "$REPO_ROOT/home/.pi/agent/settings.json" 2>/dev/null)
}

step_node_pty() {
  # Pi's pinned extension needs node-pty (a native module with no Linux
  # prebuild); rebuild it only when it actually fails to load.
  node_pty_ok() {
    node -e "require(process.env.HOME + '/.pi/agent/npm/node_modules/node-pty')" >/dev/null 2>&1
  }
  if ! command -v node >/dev/null 2>&1; then
    echo "--> node-pty: node not on PATH, skipping"
    return
  fi
  if node_pty_ok; then
    echo "--> node-pty loads OK, skipping"
    return
  fi
  if [ "$(uname -s)" != "Linux" ]; then
    echo "--> WARNING: node-pty failed to load. Ensure Xcode Command Line Tools: xcode-select --install"
    return
  fi
  echo "--> node-pty broken; checking toolchain and rebuilding with zig ..."
  if ! command -v make >/dev/null 2>&1 || { ! command -v g++ >/dev/null 2>&1 && ! command -v clang++ >/dev/null 2>&1; }; then
    echo "    WARNING: no C toolchain (expected from [bootstrap.packages] apt:build-essential); run: mise bootstrap"
    return
  fi
  if ! command -v zig >/dev/null 2>&1; then
    echo "    WARNING: zig not on PATH (mise [tools] should provide it); cannot rebuild"
    return
  fi
  GLIBC_VER="$(getconf GNU_LIBC_VERSION | awk '{print $2}')"
  [ -n "$GLIBC_VER" ] || GLIBC_VER="2.39"
  if (
    cd "$HOME/.pi/agent/npm/node_modules/node-pty" && \
    CC="zig cc -target x86_64-linux-gnu.$GLIBC_VER" \
    CXX="zig c++ -target x86_64-linux-gnu.$GLIBC_VER" \
    npm rebuild node-pty
  ) && node_pty_ok; then
    echo "    node-pty rebuilt and loads OK"
  else
    echo "    WARNING: node-pty still broken; pi will retry at startup"
  fi
}

step_wezterm_windows() {
  # WSL only: WezTerm runs on the Windows side. Install once, sync config always.
  [ "$(uname -s)" = "Linux" ] || return 0
  command -v cmd.exe >/dev/null 2>&1 || return 0
  if cmd.exe /c 'where wezterm' >/dev/null 2>&1; then
    echo "--> WezTerm already installed on Windows, skipping winget"
  else
    echo "--> installing WezTerm via winget ..."
    cmd.exe /c 'winget install --id wez.wezterm --accept-source-agreements --accept-package-agreements' || {
      echo "    WARNING: winget install failed; install manually from https://wezterm.org"
    }
  fi
  WIN_PROFILE="$(wslpath -u "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')")"
  if [ -n "$WIN_PROFILE" ]; then
    mkdir -p "$WIN_PROFILE/.config/wezterm" "$WIN_PROFILE/AppData/Roaming/Zed"
    cp "$REPO_ROOT/home/.config/wezterm/wezterm.lua" "$WIN_PROFILE/.config/wezterm/wezterm.lua"
    cp "$REPO_ROOT/home/.config/zed/settings.json" "$WIN_PROFILE/AppData/Roaming/Zed/settings.json"
    echo "--> synced wezterm + zed config to Windows side"
  else
    echo "    WARNING: could not detect Windows profile; copy wezterm.lua + settings.json manually"
  fi
}

step_npm_prefix
step_pi
step_node_pty
step_wezterm_windows
echo "--> bootstrap task done"
