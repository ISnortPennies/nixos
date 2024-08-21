{
  modulesPath,
  pkgs,
  lib,
  ...
}:
{
  local = {
    hardware = {
      gpuAcceleration.disable = true;
      sound.disable = true;
    };
    bootConfig.disable = true;
    sops.disable = true;
  };
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
    "${modulesPath}/profiles/minimal.nix"
  ];
  environment.noXlibs = false;

  services.qemuGuest.enable = true;

  environment.systemPackages = [
    pkgs.neovim
    pkgs.rsync
  ];

  users = {
    mutableUsers = false;
    users.root = {
      hashedPassword = "!";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILZKIp3iObuxEUPx1dsMiN3vyMaMQb0N1gKJY78TtRxd"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILpYY2uw0OH1Re+3BkYFlxn0O/D8ryqByJB/ljefooNc"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJWbwkFJmRBgyWyWU+w3ksZ+KuFw9uXJN3PwqqE7Z/i8"
      ];
    };
  };

  services.openssh = {
    enable = true;
    hostKeys = lib.mkForce [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
    settings.PermitRootLogin = "prohibit-password";
  };

  networking = {
    hostName = "proxy";
    useNetworkd = false;
    useDHCP = false;
  };

  systemd.network = {
    enable = true;
    networks.default = {
      name = "en*";
      DHCP = "ipv4";
      addresses = [ { Address = "2a01:4ff:f0:b7fd::/64"; } ];
      gateway = [ "fe80::1" ];
      linkConfig.RequiredForOnline = "routable";
    };
  };

  boot = {
    loader = {
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
      grub = {
        enable = true;
        configurationLimit = 10;
      };
    };
    kernelPackages = pkgs.linuxPackages_latest;
    initrd = {
      systemd.enable = true;
      availableKernelModules = [
        "ahci"
        "xhci_pci"
        "virtio_pci"
        "virtio_scsi"
        "sd_mod"
        "sr_mod"
      ];
    };
  };

  ###
  i18n.defaultLocale = "en_US.UTF-8";
  time.timeZone = "America/New_York";
  ###
  documentation.info.enable = false;
  documentation.nixos.enable = false;
  programs.command-not-found.enable = false;
  programs.nano.enable = false;
  ###

  system.stateVersion = "24.11";
  nixpkgs.hostPlatform = "x86_64-linux";
}