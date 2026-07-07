{
  description = "dotfiles - terminal environment for macOS and WSL";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, home-manager, nixpkgs }:
    let
      mkHome = { system, username, homeDirectory }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = { inherit username; };
          modules = [
            ./home.nix
            {
              home.username = username;
              home.homeDirectory = homeDirectory;
            }
          ];
        };
    in
    {
      homeConfigurations."mac" = mkHome {
        system = "aarch64-darwin";
        username = "mrodrigues";
        homeDirectory = "/Users/mrodrigues";
      };

      homeConfigurations."wsl" = mkHome {
        system = "x86_64-linux";
        username = "mrodrigues";
        homeDirectory = "/home/mrodrigues";
      };
    };
}
