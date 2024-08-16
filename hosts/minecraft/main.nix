{
  config,
  modulesPath,
  pkgs,
  lib,
  ...
}:
{
  imports = [ "${modulesPath}/profiles/qemu-guest.nix" ];
  services.qemuGuest.enable = true;

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

  users = {
    mutableUsers = false;
    users.root = {
      password = "changeme";
      #hashedPassword = "!";
      openssh.authorizedKeys.keys = builtins.attrValues {
        inherit (config.local.keys) gerg_gerg-desktop gerg_gerg-phone gerg_gerg-windows;
      };

    };
  };

  services.openssh = {
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
    settings.PermitRootLogin = lib.mkForce "prohibit-password";
  };

  networking = {
    useNetworkd = false;
    useDHCP = false;
    hostId = "287a56db";
    firewall.enable = true;
  };

  systemd.network = {
    enable = true;
    networks.default = {
      matchConfig.Name = "en*";
      networkConfig = {
        DHCP = "yes";
        IPv6PrivacyExtensions = false;
        IPv6AcceptRA = true;
      };
    };
  };

  boot = {
    loader.systemd-boot = {
      enable = true;
      configurationLimit = 10;
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
  system.stateVersion = "24.11";
}
