{
  description = "dotfiles - terminal environment for macOS and WSL";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    herdr.url = "github:herdrdev/herdr/v0.8.2";
    # herdr pins an older nixpkgs that fetches crates from crates.io/api
    # (403-blocked); our nixpkgs vendors from static.crates.io instead.
    herdr.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, home-manager, nixpkgs, herdr }:
    let
      mkHome = { system, username, homeDirectory, fish ? true }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = {
            inherit username fish;
            herdr = herdr.packages.${system}.default;
          };
          modules = [
            ./home.nix
            {
              home.username = username;
              home.homeDirectory = homeDirectory;
            }
          ];
        };

      macArgs = {
        system = "aarch64-darwin";
        username = "mrodrigues";
        homeDirectory = "/Users/mrodrigues";
      };
      wslArgs = {
        system = "x86_64-linux";
        username = "mrodrigues";
        homeDirectory = "/home/mrodrigues";
      };
    in
    {
      homeConfigurations = {
        "mac" = mkHome macArgs;
        # No-fish variants: selected by bootstrap.sh / refresh.sh when the
        # ~/.nofish marker exists (skip fish, keep the default shell).
        "mac-nofish" = mkHome (macArgs // { fish = false; });
        "wsl" = mkHome wslArgs;
        "wsl-nofish" = mkHome (wslArgs // { fish = false; });
      };
    };
}
