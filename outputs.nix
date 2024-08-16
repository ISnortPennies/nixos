inputs@{ self, unstable, ... }:
let
  lib = import ./lib inputs;
in
lib.gerg-utils (s: unstable.legacyPackages.${s}) {
  inherit lib;
  nixosConfigurations = lib.mkHosts "x86_64-linux" [
    "gerg-desktop"
    "media-laptop"
    "iso"
    "minecraft"
  ];

  nixosModules = lib.mkModules "${self}/modules";

  diskoConfigurations = lib.mkDisko [
    "gerg-desktop"
    "media-laptop"
    "minecraft"
  ];

  formatter = pkgs: inputs.self.packages.${pkgs.stdenv.system}.lint;

  devShells = pkgs: { default = pkgs.mkShellNoCC { packages = [ pkgs.sops ]; }; };

  packages = lib.mkPackages "${self}/packages";
}
