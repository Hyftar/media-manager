{
  description = "Media Manager NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, sops-nix, ... }:
  let
    lib = nixpkgs.lib;
  in
  {
    nixosConfigurations = {
      closet-intelligence-agency = lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          sops-nix.nixosModules.sops
          ./configuration.nix
          ./hardware-configuration.nix
        ];
      };
    };
  };
}
