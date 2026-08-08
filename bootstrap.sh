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
  switch --flake ~/.dotfiles/nix#$FLAKE_HOST -b backup

echo "==> Step 5: Node.js via nvm (optional)"
NVM_DIR="${NVM_DIR:-$HOME/.local/share/nvm}"
NODE_VERSION="v24.18.1"
NODE_BIN="$NVM_DIR/$NODE_VERSION/bin"
if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
  echo "    node $(node --version 2>/dev/null) already installed, skipping"
elif [ -x "$NODE_BIN/node" ] && [ -x "$NODE_BIN/npm" ]; then
  # Installed by a previous run but not on PATH (e.g. fresh bash terminal
  # before nvm.fish activates): use it instead of asking again.
  echo "    node already installed at $NVM_DIR/$NODE_VERSION; adding to PATH for this run"
  export PATH="$NODE_BIN:$PATH"
else
  read -r -p "    Install Node.js v24.18.1 into ~/.local/share/nvm? [y/N] " REPLY
  if [ "$REPLY" != "y" ] && [ "$REPLY" != "Y" ]; then
    echo "    Skipped. The Pi step below will warn about missing npm."
  else
    case "$(uname -s)-$(uname -m)" in
      Darwin-arm64)  NODE_PLATFORM="darwin-arm64" ;;
      Darwin-x86_64) NODE_PLATFORM="darwin-x64" ;;
      Linux-x86_64)  NODE_PLATFORM="linux-x64" ;;
      Linux-aarch64) NODE_PLATFORM="linux-arm64" ;;
      *) NODE_PLATFORM="" ;;
    esac
    if [ -z "$NODE_PLATFORM" ]; then
      echo "    WARNING: unsupported platform ($(uname -s)-$(uname -m)); install Node.js manually"
    else
      echo "    Downloading node-$NODE_VERSION-$NODE_PLATFORM.tar.gz..."
      mkdir -p "$NVM_DIR/$NODE_VERSION"
      if curl -fsSL "https://nodejs.org/dist/$NODE_VERSION/node-$NODE_VERSION-$NODE_PLATFORM.tar.gz" \
          | tar -xz -C "$NVM_DIR/$NODE_VERSION"; then
        mv "$NVM_DIR/$NODE_VERSION/node-$NODE_VERSION-$NODE_PLATFORM"/* "$NVM_DIR/$NODE_VERSION/"
        rm -rf "$NVM_DIR/$NODE_VERSION/node-$NODE_VERSION-$NODE_PLATFORM"
        export PATH="$NODE_BIN:$PATH"
        # Refresh the nvm.fish version index (mirrors nvm.fish's _nvm_index_update),
        # so nvm ls/use/install work. Silently ignored if the fetch fails.
        curl -fsSL "https://nodejs.org/dist/index.tab" 2>/dev/null | awk -v OFS='\t' '
          /v0.9.12/ { exit }
          NR > 1 { print $1 (NR == 2 ? " latest" : $10 != "-" ? " lts/" tolower($10) : "") }
        ' > "$NVM_DIR/.index" 2>/dev/null || true
        # nvm.fish auto-activates the default version in new interactive shells.
        fish -c "set -U nvm_default_version $NODE_VERSION" >/dev/null 2>&1 || true
        echo "    Installed node $(node --version) + npm $(npm --version) at $NVM_DIR/$NODE_VERSION"
        echo "    Fish shells: nvm use default (or open a new shell)"
      else
        rm -rf "$NVM_DIR/$NODE_VERSION"
        echo "    WARNING: node download failed (network?); the Pi step will warn about missing npm."
      fi
    fi
  fi
fi

echo "==> Step 6: Pi CLI (optional)"
if command -v pi >/dev/null 2>&1; then
  echo "    pi already installed, skipping"
elif command -v npm >/dev/null 2>&1; then
  read -r -p "    Install Pi CLI via npm? [y/N] " REPLY
  if [ "$REPLY" != "y" ] && [ "$REPLY" != "Y" ]; then
    echo "    Skipped. Install manually later with:"
    echo "    npm install -g --ignore-scripts @earendil-works/pi-coding-agent"
  else
    npm install -g --ignore-scripts @earendil-works/pi-coding-agent

    # The npm global bin may not be on PATH in this shell; resolve pi directly.
    PI_BIN="$(npm prefix -g 2>/dev/null)/bin/pi"
    [ -x "$PI_BIN" ] || PI_BIN="$(command -v pi || true)"

    if [ ! -x "$PI_BIN" ]; then
      echo "    WARNING: pi binary not found after install."
      echo "    Add \"$(npm prefix -g)/bin\" to your PATH, then re-run ./refresh.sh"
    else
      # The pinned extension in settings.json depends on node-pty, a native module
      # with no prebuilt Linux binary. Get it building now so the first pi run works.
      if [ "$FLAKE_HOST" = "wsl" ]; then
        echo "    Ensuring native build toolchain (make + g++)..."
        if command -v make >/dev/null 2>&1 && { command -v g++ >/dev/null 2>&1 || command -v clang++ >/dev/null 2>&1; }; then
          echo "      make + C++ compiler already present"
        elif command -v apt-get >/dev/null 2>&1; then
          if sudo apt-get update -qq && sudo apt-get install -y -qq build-essential; then
            echo "      Installed build-essential"
          else
            echo "      WARNING: could not install build-essential (sudo may require a password)."
            echo "      Run: sudo apt-get install -y build-essential"
          fi
        else
          echo "      WARNING: no apt-get found; install make and a C++ compiler manually"
        fi
      fi

      PI_PKG="$(jq -r '.packages[]? // empty' "$DIR/home/.pi/agent/settings.json" 2>/dev/null | head -n1)" || true
      if [ -n "$PI_PKG" ]; then
        echo "    Installing pinned Pi package ($PI_PKG)..."
        "$PI_BIN" install "$PI_PKG" || echo "    WARNING: package install failed (pi will retry at first startup)"
      fi

      node_pty_ok() {
        node -e "require(process.env.HOME + '/.pi/agent/npm/node_modules/node-pty')" >/dev/null 2>&1
      }
      if ! command -v node >/dev/null 2>&1; then
        echo "    (skipping node-pty verification: node not on PATH)"
      elif node_pty_ok; then
        echo "      node-pty loads OK"
      elif [ "$FLAKE_HOST" = "wsl" ]; then
        echo "      node-pty failed to load; rebuilding with zig against the system glibc..."
        GLIBC_VER="$(ldd --version 2>/dev/null | head -1 | sed -nE 's/.*GLIBC ([0-9]+\.[0-9]+).*/\1/p')"
        [ -n "$GLIBC_VER" ] || GLIBC_VER="2.39"
        if (
          cd "$HOME/.pi/agent/npm/node_modules/node-pty" && \
          nix shell nixpkgs#zig nixpkgs#gnumake -c bash -c \
            "CC='zig cc -target x86_64-linux-gnu.$GLIBC_VER' CXX='zig c++ -target x86_64-linux-gnu.$GLIBC_VER' npm rebuild node-pty"
        ) && node_pty_ok; then
          echo "      node-pty rebuilt and loads OK"
        else
          echo "      WARNING: node-pty still broken (see README \"Native builds\")."
        fi
      else
        echo "      WARNING: node-pty failed to load. Ensure Xcode Command Line Tools: xcode-select --install"
      fi

      echo "    Pi ready. Authenticate and refresh model catalogs:"
      echo "      pi auth"
      echo "      pi update --models"
    fi
  fi
else
  echo "    npm not found. Accept the Node.js step (Step 5) or install Node.js manually:"
  echo "    npm install -g --ignore-scripts @earendil-works/pi-coding-agent"
fi

if [ "$FLAKE_HOST" = "wsl" ]; then
  echo "==> Step 7: install WezTerm on Windows and sync config"
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
