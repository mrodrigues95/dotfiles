#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d%H%M%S)"

info()  { printf "\033[1;34m[INFO]\033[0m %s\n" "$1"; }
ok()    { printf "\033[1;32m[ OK ]\033[0m %s\n" "$1"; }
warn()  { printf "\033[1;33m[WARN]\033[0m %s\n" "$1"; }
err()   { printf "\033[1;31m[FAIL]\033[0m %s\n" "$1"; exit 1; }

require_sudo() {
    if ! command -v sudo &>/dev/null; then
        err "sudo is required but not available."
    fi
}

detect_os() {
    case "$OSTYPE" in
        darwin*)  echo "macos" ;;
        linux*)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo "wsl"
            else
                echo "linux"
            fi
            ;;
        *) err "Unsupported OS: $OSTYPE" ;;
    esac
}

safe_symlink() {
    local src="$1" dst="$2"
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        ok "Symlink already correct: $dst"
        return
    fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        warn "Backing up $dst -> $BACKUP_DIR/"
        mkdir -p "$BACKUP_DIR"
        mv "$dst" "$BACKUP_DIR/"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -sfn "$src" "$dst"
    ok "Symlinked $src -> $dst"
}

install_packages_macos() {
    info "Installing packages via Homebrew..."
    if ! command -v brew &>/dev/null; then
        info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    brew install fish tmux starship
    ok "Packages installed"
}

install_packages_wsl() {
    require_sudo
    info "Installing packages via apt..."
    sudo apt update
    sudo apt install -y fish tmux
    ok "Packages installed via apt"
    if ! command -v starship &>/dev/null; then
        info "Installing Starship..."
        sudo sh -c "$(curl -fsSL https://starship.rs/install.sh)" -- -y
        ok "Starship installed"
    else
        ok "Starship already installed"
    fi
}

set_default_shell() {
    local fish_path
    fish_path="$(command -v fish)" || err "Fish not found after install"
    if [ "$SHELL" = "$fish_path" ]; then
        ok "Default shell is already Fish"
        return
    fi
    info "Setting default shell to Fish..."
    if ! grep -q "$fish_path" /etc/shells 2>/dev/null; then
        require_sudo
        echo "$fish_path" | sudo tee -a /etc/shells >/dev/null
    fi
    if chsh -s "$fish_path" "$(whoami)" 2>/dev/null; then
        ok "Default shell set to Fish"
    else
        require_sudo
        sudo chsh -s "$fish_path" "$(whoami)"
        ok "Default shell set to Fish (via sudo)"
    fi
}

setup_symlinks() {
    info "Setting up symlinks..."
    safe_symlink "$DOTFILES_DIR/fish"          "$HOME/.config/fish"
    safe_symlink "$DOTFILES_DIR/starship/starship.toml" "$HOME/.config/starship.toml"
    safe_symlink "$DOTFILES_DIR/tmux/.tmux.conf"       "$HOME/.tmux.conf"
}

setup_fish() {
    info "Setting up Fisher plugins..."
    fish -c "fisher update" || fish -c "fisher install jorgebucaran/fisher"
    ok "Fisher plugins ready"
}

setup_tmux() {
    local tpm_dir="$HOME/.tmux/plugins/tpm"
    if [ ! -d "$tpm_dir" ]; then
        info "Cloning TPM..."
        git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
    else
        ok "TPM already cloned"
    fi
    info "Installing tmux plugins..."
    "$tpm_dir/bin/install_plugins" || true
    ok "Tmux plugins installed"
}

main() {
    echo "============================================"
    echo "  Dotfiles Bootstrap"
    echo "============================================"
    OS=$(detect_os)
    info "Detected OS: $OS"
    case "$OS" in
        macos) install_packages_macos ;;
        wsl)   install_packages_wsl ;;
    esac
    set_default_shell
    setup_symlinks
    setup_fish
    setup_tmux
    echo ""
    ok "All done! Restart your shell or run 'exec fish' to start using Fish."
}

main "$@"
