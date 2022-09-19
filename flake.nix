{
  description = "my personal configurations";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable"; 
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spicetify-nix.url = "github:the-argus/spicetify-nix";
    webcord.url = "github:fufexan/webcord-flake";
  };

  outputs = {self, nixpkgs, home-manager, spicetify-nix, webcord, ... }@inputs:
  let
    username = "gerg";
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
        packageOverrides = super: let self = super.pkgs; in {
          #more overrides can go here
          polkit_fix = self.polkit_gnome.overrideAttrs ( oldAttrs: rec 
          {
            postInstall = ''
             mkdir $out/bin
             ln -s $out/libexec/polkit-gnome-authentication-agent-1 $out/bin/polkit-gnome
            '';
          });
          nerdfonts-overpass = self.nerdfonts.override {
            fonts = [ "Overpass" ];
          };
        };
      };
      overlays = [
          (final: prev: rec {
            t-rex-miner = final.callPackage ./pkgs/t-rex-miner {};
            afk-cmds = final.callPackage ./pkgs/afk-cmds {};
            }
          )];
    };
    lib = nixpkgs.lib;
  in {
    homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ./home-manager/home.nix
      ];
      extraSpecialArgs = { inherit spicetify-nix; };
    };
    homeConfigurations.root = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ./home-manager/root.nix
      ];
    };
    nixosConfigurations = {
      gerg-laptop = lib.nixosSystem { 
        inherit system pkgs;
        specialArgs = inputs;
        modules = [
          ./configuration.nix
          ./systems/laptop.nix
        ];
      };
      gerg-desktop = lib.nixosSystem { 
        inherit system pkgs;
        specialArgs = inputs;
        modules = [
          ./configuration.nix
          ./systems/desktop.nix
        ];
      };
    };
  };
}
