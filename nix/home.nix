{ config, pkgs, username, ... }:

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
  ];

  fonts.fontconfig.enable = true;

  home.sessionPath = [
    "${config.home.homeDirectory}/.nix-profile/bin"
    "/nix/var/nix/profiles/default/bin"
    "${config.home.homeDirectory}/.opencode/bin"
  ];

  programs.fish = {
    enable = true;
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

  home.file.".config/wezterm".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/wezterm";
  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
}
