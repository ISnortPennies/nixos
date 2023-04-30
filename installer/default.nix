{disko, ...}: {
  lib,
  modulesPath,
  pkgs,
  ...
}: {
  imports = [
    "${modulesPath}/profiles/minimal.nix"
    "${modulesPath}/installer/cd-dvd/installation-cd-base.nix"
  ];

  environment = {
    noXlibs = lib.mkOverride 500 false;
    defaultPackages = [];
    systemPackages = [
      pkgs.gitMinimal
      pkgs.neovim
      disko.packages.${pkgs.system}.default
    ];
    variables = {
      EDITOR = "nvim";
    };
  };
  documentation = {
    man.enable = lib.mkOverride 500 false;
    doc.enable = lib.mkOverride 500 false;
  };

  fonts.fontconfig.enable = lib.mkForce false;

  isoImage = {
    edition = lib.mkForce "gerg-minimal";
    isoName = lib.mkForce "NixOS.iso";
  };
  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes" "repl-flake"];
      auto-optimise-store = true;
    };
  };
  sound.enable = false;
}