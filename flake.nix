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
        mkConfig = nodeRole:
          nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              sops-nix.nixosModules.sops
              ./configuration.nix
              ./kubernetes.nix
              ./sops.nix
              { inherit nodeRole; }
            ];
          };
      in {
        devShells.default =
          pkgs.mkShell { packages = with pkgs; [ age ssh-to-age ]; };

        packages.nixosConfigurations.server = mkConfig "server";
        packages.nixosConfigurations.agent = mkConfig "agent";
      });
}
