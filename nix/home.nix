{ config, lib, pkgs, username, fish, herdr, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in

{
  home.stateVersion = "24.11";

  home.packages = with pkgs; [
    ripgrep
    fd
    fzf
    jq
    eza
    wezterm
    nerd-fonts.hack
    herdr
    # herdr pane shell: herdr itself falls back to $SHELL when default_shell is
    # unset, which stays the old login shell (e.g. zsh) on machines where only
    # the interactive shell switched to fish. This wrapper is on PATH for both
    # fish and no-fish variants: fish where installed, else the login shell.
    (pkgs.writeShellScriptBin "herdr-shell" ''
      if command -v fish >/dev/null 2>&1; then exec fish -l; fi
      exec "$SHELL" -l
    '')
  ];

  fonts.fontconfig.enable = true;

  home.sessionPath = [
    "${config.home.homeDirectory}/.nix-profile/bin"
    "/nix/var/nix/profiles/default/bin"
    "${config.home.homeDirectory}/.opencode/bin"
  ];

  programs.fish = lib.mkIf fish {
    enable = true;
    shellInit = ''
      # Fallback PATH for nvm-managed Node. Appended (not prepended) so the
      # version nvm.fish activates always wins; this keeps the pinned version's
      # global binaries (e.g. pi) reachable when another version is active.
      # Keep in sync with NODE_VERSION in bootstrap.sh.
      set -gx PATH $PATH "$HOME/.local/share/nvm/v24.18.1/bin"
    '';
    plugins = [
      {
        name = "fisher";
        src = pkgs.fetchFromGitHub {
          owner = "jorgebucaran";
          repo = "fisher";
          rev = "4.4.8";
          sha256 = "sha256-Sf671UGOQXtOMrqoEOIBG5TCt0p5fd+aKGF2ExImbbs=";
        };
      }
      {
        # Fish-native nvm (does not need bash nvm). Node binaries live in
        # ~/.local/share/nvm/<version> (nvm_data), managed by bootstrap.sh.
        name = "nvm.fish";
        src = pkgs.fetchFromGitHub {
          owner = "jorgebucaran";
          repo = "nvm.fish";
          rev = "abd3002b6d2d578d484a5aea94dd1517dded6d42";
          sha256 = "15i404nnks9zb75b6avnsg29x0v937mkh4pxnx8fchhbv0zyin84";
        };
      }
    ];
    shellAbbrs = {
      ".." = "cd ..";
      ls = "eza";
      ll = "eza -l";
      la = "eza -la";
    };
    interactiveShellInit = ''
      starship init fish | source
    '';
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$cmd_duration$line_break$character";
      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
      };
      cmd_duration.format = "[$duration]($style) ";
      azure.symbol = "☁️ ";
      battery = {
        full_symbol = "• ";
        charging_symbol = "⇡ ";
        discharging_symbol = "⇣ ";
        unknown_symbol = "❓ ";
        empty_symbol = "❗ ";
      };
      erlang.symbol = "ⓔ ";
      nodejs.symbol = "[⬢](bold green) ";
      pulumi.symbol = "🧊 ";
    };
  };

  home.file.".agents".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.agents";

  home.file.".config/wezterm".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/wezterm";
  home.file.".config/zed".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/zed";
  home.file.".config/herdr".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/herdr";
  home.file.".config/rpiv-advisor".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/rpiv-advisor";

  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.agents/AGENTS.md";
  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.agents/AGENTS.md";
  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.agents/AGENTS.md";
  home.file.".pi/agent/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.agents/AGENTS.md";

  # Pi: link only authored files/directories. Runtime state stays
  # local under ~/.pi/agent and is never managed here.
  home.file.".pi/agent/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/settings.json";
  home.file.".pi/agent/extensions".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/extensions";
  home.file.".pi/agent/themes".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/themes";
}
