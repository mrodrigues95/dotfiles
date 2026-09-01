#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

case "$(uname -s)" in
  Darwin) FLAKE_HOST="mac" ;;
  Linux)  FLAKE_HOST="wsl" ;;
  *)      echo "Unsupported OS: $(uname -s)"; exit 1 ;;
esac

# Fish toggle marker: present = fish disabled. Picked up by step 5,
# refresh.sh, and WezTerm's shell fallback.
NOFISH="$HOME/.nofish"

# ---------------------------------------------------------------------------
# Step functions
# ---------------------------------------------------------------------------

step_install_nix() {
  echo "==> Step 1: Install Determinate Nix"
  if command -v nix >/dev/null 2>&1; then
    echo "    nix already installed, skipping"
  else
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
      | sh -s -- install --no-confirm
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  fi
}

step_symlink_repo() {
  echo "==> Step 2: Symlink this repo to ~/.dotfiles"
  ln -sfn "$DIR" ~/.dotfiles
}

step_fix_username() {
  echo "==> Step 3: Personalize the configured username"
  REAL_USER="$(whoami)"
  FLAKE_USER="$(sed -nE 's/^[[:space:]]*username = "([^"]+)";.*/\1/p' "$DIR/nix/flake.nix" | head -n1)"
  # homeDirectory must follow the username: /Users/<user> on macOS, /home/<user> on Linux.
  [ "$(uname -s)" = "Darwin" ] && HOME_PREFIX="/Users" || HOME_PREFIX="/home"
  FLAKE_HOME="$(sed -nE "s|^[[:space:]]*homeDirectory = \"(${HOME_PREFIX}/[^\"]+)\";.*|\1|p" "$DIR/nix/flake.nix" | head -n1)"
  EXPECT_HOME="${HOME_PREFIX}/${REAL_USER}"
  if [ -z "$FLAKE_USER" ]; then
    echo "    Could not find the \"username = \" line in flake.nix."
    echo "    Edit nix/flake.nix yourself before continuing."
    exit 1
  elif [ "$FLAKE_USER" != "$REAL_USER" ] || [ "$FLAKE_HOME" != "$EXPECT_HOME" ]; then
    echo "    flake.nix is configured for user \"$FLAKE_USER\" (home $FLAKE_HOME), but you are \"$REAL_USER\" (home $EXPECT_HOME)."
    read -r -p "    Rewrite flake.nix's username + homeDirectory for \"$REAL_USER\"? [y/N] " REPLY
    if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
      SEDI=(sed -i)
      [ "$(uname -s)" = "Darwin" ] && SEDI=(sed -i '')
      "${SEDI[@]}" -E "s/^([[:space:]]*username = \")[^\"]+(\";.*)/\1${REAL_USER}\2/" "$DIR/nix/flake.nix"
      # homeDirectory per host block: each line keeps its own /Users or /home prefix.
      "${SEDI[@]}" -E "s,^([[:space:]]*homeDirectory = \")/(Users|home)/[^\"]+(\";.*),\1/\2/${REAL_USER}\3," "$DIR/nix/flake.nix"
      echo "    Updated. Review the change with: git diff nix/flake.nix"
    else
      echo "    Skipped. Edit the \"username = \" line in nix/flake.nix yourself before continuing."
      exit 1
    fi
  else
    echo "    flake.nix already matches \"$REAL_USER\", nothing to do."
  fi
}

step_fish() {
  echo "==> Step 4: Fish shell (home-manager)"
  if [ -f "$NOFISH" ]; then
    rm -f "$NOFISH"
    echo "    Fish enabled (removed $NOFISH). It will be installed on the"
    echo "    next home-manager switch (step 5 or ./refresh.sh)."
  else
    echo "    Fish already enabled, nothing to do."
  fi
}

step_home_switch() {
  echo "==> Step 5: First home-manager switch (pinned to release-26.05)"
  HM_HOST="$FLAKE_HOST"
  if [ -f "$NOFISH" ]; then
    HM_HOST="${FLAKE_HOST}-nofish"
    echo "    Fish is disabled (~/.nofish exists) - using homeConfigurations.$HM_HOST (no fish)."
  fi
  NIX_BIN="$(command -v nix)"
  "$NIX_BIN" run github:nix-community/home-manager/release-26.05#home-manager -- \
    switch --flake ~/.dotfiles/nix#$HM_HOST -b backup
}

step_node() {
  echo "==> Step 6: Node.js via nvm (optional)"
  NVM_DIR="${NVM_DIR:-$HOME/.local/share/nvm}"
  NODE_VERSION="v24.18.1"
  NODE_BIN="$NVM_DIR/$NODE_VERSION/bin"
  # Skip only when the on-PATH node really is ours (lives under NVM_DIR). A node
  # from elsewhere (e.g. a previous bash-nvm install) is invisible to nvm.fish,
  # so it must not satisfy this check. process.execPath resolves symlinks and
  # works where readlink -f does not (macOS).
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1 \
     && [[ "$(node -p 'process.execPath' 2>/dev/null)" == "$NVM_DIR"/* ]]; then
    echo "    node $(node --version 2>/dev/null) already installed in $NVM_DIR, skipping"
  elif [ -x "$NODE_BIN/node" ] && [ -x "$NODE_BIN/npm" ]; then
    # Installed by a previous run but not on PATH (e.g. fresh bash terminal
    # before nvm.fish activates): use it instead of asking again.
    echo "    node already installed at $NVM_DIR/$NODE_VERSION; adding to PATH for this run"
    export PATH="$NODE_BIN:$PATH"
  else
    if command -v node >/dev/null 2>&1; then
      echo "    Note: node $(node --version 2>/dev/null) found at $(command -v node) - outside $NVM_DIR,"
      echo "    so nvm.fish shells can't see it; installing ours."
    fi
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
          if [ -f "$NOFISH" ]; then
            # Fish disabled: skip the fish-native nvm bits, tell the user how
            # to use node in their current shell instead.
            echo "    Installed node $(node --version) + npm $(npm --version) at $NVM_DIR/$NODE_VERSION"
            echo "    Fish is not enabled - add $NODE_BIN to your shell PATH,"
            echo "    or re-enable Fish (menu item 4) for the nvm command."
          else
            # nvm.fish auto-activates the default version in new interactive shells.
            fish -c "set -U nvm_default_version $NODE_VERSION" >/dev/null 2>&1 || true
            echo "    Installed node $(node --version) + npm $(npm --version) at $NVM_DIR/$NODE_VERSION"
            echo "    Fish shells: nvm use default (or open a new shell)"
          fi
        else
          rm -rf "$NVM_DIR/$NODE_VERSION"
          echo "    WARNING: node download failed (network?); the Pi step will warn about missing npm."
        fi
      fi
    fi
  fi
}

step_pi() {
  echo "==> Step 7: Pi CLI (optional)"
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

        while IFS= read -r PI_PKG; do
          [ -n "$PI_PKG" ] || continue
          echo "    Installing pinned Pi package ($PI_PKG)..."
          "$PI_BIN" install "$PI_PKG" || echo "    WARNING: package install failed for $PI_PKG (pi will retry at first startup)"
        done < <(jq -r '.packages[]? // empty' "$DIR/home/.pi/agent/settings.json" 2>/dev/null)

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
    echo "    npm not found. Accept the Node.js step (Step 6) or install Node.js manually:"
    echo "    npm install -g --ignore-scripts @earendil-works/pi-coding-agent"
  fi
}

step_wezterm_windows() {
  echo "==> Step 8: install WezTerm on Windows and sync config"
  echo "    Installing WezTerm via winget..."
  cmd.exe /c 'winget install --id wez.wezterm --accept-source-agreements --accept-package-agreements' || {
    echo "    Warning: winget install failed. Install WezTerm manually from https://wezterm.org"
  }

  WIN_PROFILE="$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r' | sed 's/\\/\//g' | sed 's/^C:/\/mnt\/c/')"
  if [ -n "$WIN_PROFILE" ]; then
    WEZTERM_WIN_DIR="$WIN_PROFILE/.config/wezterm"
    mkdir -p "$WEZTERM_WIN_DIR"
    cp "$DIR/home/.config/wezterm/wezterm.lua" "$WEZTERM_WIN_DIR/wezterm.lua"

    ZED_WIN_DIR="$WIN_PROFILE/AppData/Roaming/Zed"
    mkdir -p "$ZED_WIN_DIR"
    cp "$DIR/home/.config/zed/settings.json" "$ZED_WIN_DIR/settings.json"

    echo "    Synced config to $WEZTERM_WIN_DIR and $ZED_WIN_DIR"
  else
    echo "    Warning: Could not detect Windows user profile. Copy wezterm.lua and settings.json manually."
  fi
}

# ---------------------------------------------------------------------------
# Interactive selection
# ---------------------------------------------------------------------------

STEPS_DESC=()
STEPS_FN=()

add_step() {
  STEPS_DESC+=("$1")
  STEPS_FN+=("$2")
}

add_step "Install Determinate Nix - Nix package manager (home-manager needs it)" step_install_nix
add_step "Symlink this repo to ~/.dotfiles - makes it available to home-manager and refresh.sh" step_symlink_repo
add_step "Fix username in nix/flake.nix - checks against your user, offers to fix on mismatch" step_fix_username
add_step "Fish shell (home-manager) - fish + fisher + nvm.fish + starship init + abbrs; deselect = keep zsh/bash" step_fish
add_step "Home-manager switch - CLI tools + config symlinks (.agents, wezterm, zed, herdr, Pi, AGENTS.md)" step_home_switch
add_step "Node.js v24.18.1 via nvm - node + npm into ~/.local/share/nvm (works with or without fish)" step_node
add_step "Pi CLI via npm - pi-coding-agent + pinned packages + node-pty prep (WSL: build toolchain)" step_pi
if [ "$FLAKE_HOST" = "wsl" ]; then
  add_step "WezTerm on Windows + config sync - winget install; copy wezterm.lua + zed settings.json" step_wezterm_windows
fi
N_STEPS="${#STEPS_FN[@]}"

# Parse the raw selection string into the SELECTED array (ascending, deduped).
# Returns non-zero on invalid input; prints the offending token.
parse_selection() {
  local input="$1" tok a b i
  SELECTED=()
  [ -z "$input" ] && return 0
  input="${input//,/ }"       # commas act as separators too
  [ -z "${input//[[:space:]]/}" ] && {
    echo "    Nothing entered (empty input)."
    return 1
  }
  for tok in $input; do
    if [[ "$tok" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      a="${BASH_REMATCH[1]}"
      b="${BASH_REMATCH[2]}"
      if (( a > b )); then
        echo "    Invalid range: $tok"
        return 1
      fi
      for (( i = a; i <= b; i++ )); do
        if (( i < 1 || i > N_STEPS )); then
          echo "    Invalid item: $i (max $N_STEPS)"
          return 1
        fi
        SELECTED+=("$i")
      done
    elif [[ "$tok" =~ ^[0-9]+$ ]]; then
      if (( tok < 1 || tok > N_STEPS )); then
        echo "    Invalid item: $tok (max $N_STEPS)"
        return 1
      fi
      SELECTED+=("$tok")
    else
      echo "    Invalid input: $tok"
      return 1
    fi
  done
  SELECTED=($(printf '%s\n' "${SELECTED[@]}" | sort -nu))
  return 0
}

contains_step() {
  local want="$1" s
  for s in "${SELECTED[@]}"; do
    [ "$s" = "$want" ] && return 0
  done
  return 1
}

force_step() {
  local want="$1" why="$2" s
  for s in "${SELECTED[@]}"; do
    [ "$s" = "$want" ] && return 0
  done
  echo "    Adding item $want: ${STEPS_DESC[$((want - 1))]} ($why)"
  SELECTED+=("$want")
  SELECTED=($(printf '%s\n' "${SELECTED[@]}" | sort -nu))
}

select_steps() {
  echo
  echo "==> Interactive setup - pick what to run"
  for (( i = 0; i < N_STEPS; i++ )); do
    local desc="${STEPS_DESC[$i]}"
    if (( i + 1 == 4 )); then
      if [ -f "$NOFISH" ]; then
        desc="$desc (currently: off)"
      else
        desc="$desc (currently: on)"
      fi
    fi
    printf '   [%d] %s\n' "$((i + 1))" "$desc"
  done
  echo

  if [ -t 0 ]; then
    while true; do
      printf '   Choose items (e.g. "1 3 5-7", "all", "none"; Enter = all): '
      if ! read -r input; then
        echo
        echo "    Input closed; exiting."
        exit 0
      fi
      if [ -z "$input" ] || [ "$input" = "all" ]; then
        SELECTED=($(seq 1 "$N_STEPS"))
        return 0
      fi
      if [ "$input" = "none" ]; then
        echo "    Nothing selected; exiting."
        exit 0
      fi
      if parse_selection "$input"; then
        return 0
      fi
      echo "    Try again."
    done
  else
    # Non-interactive stdin: single shot. EOF or empty = run everything.
    if ! read -r input; then input=""; fi
    if [ -z "$input" ] || [ "$input" = "all" ]; then
      SELECTED=($(seq 1 "$N_STEPS"))
      return 0
    fi
    if [ "$input" = "none" ]; then
      echo "    Nothing selected; exiting."
      exit 0
    fi
    if ! parse_selection "$input"; then
      echo "    Invalid input; running all steps."
      SELECTED=($(seq 1 "$N_STEPS"))
    fi
    return 0
  fi
}

# ---------------------------------------------------------------------------
# Main flow
# ---------------------------------------------------------------------------

select_steps

# Harden prerequisites for the home-manager switch (step 5).
if contains_step 5; then
  force_step 2 "the home-manager switch reads ~/.dotfiles"
  force_step 3 "the home-manager switch must run with the correct username"
  if ! command -v nix >/dev/null 2>&1; then
    force_step 1 "nix must be installed for the home-manager switch"
  fi
fi

# Fish marker follows item 4's selection: selected => enabled (step_fish
# removes the marker), deselected => disabled so steps 5/6 see the right state.
if ! contains_step 4; then
  if [ ! -f "$NOFISH" ]; then
    touch "$NOFISH"
    echo "    Item 4 (Fish) not selected - disabled ($NOFISH created)."
    echo "    Home-manager and WezTerm will use your default shell instead."
  fi
fi

echo
echo "==> Will run:"
for s in "${SELECTED[@]}"; do
  printf '    [%d] %s\n' "$s" "${STEPS_DESC[$((s - 1))]}"
done
echo

for s in "${SELECTED[@]}"; do
  "${STEPS_FN[$((s - 1))]}"
done

echo
echo "==> Done. Use ./refresh.sh for future changes."