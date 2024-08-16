{
  config,
  modulesPath,
  pkgs,
  lib,
  ...
}:
{
  imports = [ "${modulesPath}/profiles/qemu-guest.nix" ];

  local = {
    remoteBuild.enable = true;
    hardware = {
      gpuAcceleration.disable = true;
      sound.disable = true;
    };
    bootConfig = {
      disable = true;
    };

  };
  environment = {
    systemPackages = builtins.attrValues { inherit (pkgs) neovim; };
  };

  users.users = {
    mutableUsers = false;
    root = {
      hashedPassword = "!";
      openssh.authorizedKeys.keys = builtins.attrValues {
        inherit (config.local.keys) gerg_gerg-desktop gerg_gerg-phone gerg_gerg-windows;
      };

    };
  };

  services.openssh.settings.PermitRootLogin = lib.mkForce "prohibit-password";

  networking = {
    useNetworkd = false;
    useDHCP = false;
    hostId = "287a56db";
    firewall.enable = true;
  };

  systemd.network = {
    enable = true;
    networks."10-lan" = {
      matchConfig.Name = "lan";
      networkConfig.DHCP = "ipv4";
    };
  };
  boot = {
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
  system.stateVersion = "24.11";
}
