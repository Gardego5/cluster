{
  description = "a basic flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, flake-utils, sops-nix, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        mkConfig = role:
          nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              sops-nix.nixosModules.sops
              ./configuration.nix
              ./kubernetes.nix
              /etc/nixos/.extra.nix
              { inherit role; }
            ];
          };
      in {
        devShells.default =
          pkgs.mkShell { packages = with pkgs; [ age ssh-to-age ]; };

        packages.nixosConfigurations.first = mkConfig "first";
        packages.nixosConfigurations.server = mkConfig "server";
        packages.nixosConfigurations.agent = mkConfig "agent";
      });
}
