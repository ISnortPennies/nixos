{
  lanzaboote,
  config,
  lib,
  pkgs,
}:
let
  windowsConf = ''
    title  Windows
    efi     /shellx64.efi
    options -nointerrupt -noconsolein -noconsoleout HD2d65535a1:EFI\Microsoft\Boot\Bootmgfw.efi

  '';
in
{
  imports = [ lanzaboote.nixosModules.lanzaboote ];

  environment.systemPackages = [
    pkgs.sbctl
    (pkgs.writeShellScriptBin "windows" ''
      bootctl set-oneshot windows.conf
      bootctl set-timeout-oneshot 1
      reboot
    '')
  ];
  systemd.tmpfiles.rules = [
    "L+ /var/lib/sbctl  - - - - /persist/secureboot"
  ];

  boot = {
    initrd = {
      kernelModules = [ "igc" ];
      network = {
        enable = true;
        ssh = {
          enable = true;
          port = 22;
          hostKeys = [ "/persist/initrd-keys/ssh_host_ed5519_key" ];
          authorizedKeys = [ config.local.keys.gerg_gerg-phone ];
        };
      };
      systemd = {
        network = {
          enable = true;
          networks.enp11s0 = {
            name = "enp11s0";
            address = [ "192.168.1.4/24" ];
            gateway = [ "192.168.1.1" ];
            dns = [ "192.168.1.1" ];
            DHCP = "no";
            linkConfig = {
              MACAddress = "D8:5E:D3:E5:47:90";
              RequiredForOnline = "routable";
            };
          };
          wait-online.enable = false;
        };
        users.root.shell = "/bin/systemd-tty-ask-password-agent";
      };
    };

    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
      configurationLimit = 10;
      package = lib.mkForce (
        pkgs.writeShellApplication {
          name = "lzbt";
          runtimeInputs = [
            lanzaboote.packages.tool
            pkgs.coreutils
            pkgs.sbctl
          ];
          text = ''
            lzbt "$@"
            MP='${config.boot.loader.efi.efiSysMountPoint}'
            cp -f '${pkgs.edk2-uefi-shell.efi}' "$MP/shellx64.efi"
            mkdir -p "$MP/loader/entries"
            sbctl sign -s "$MP/shellx64.efi"
            cat << EOF > "$MP/loader/entries/windows.conf"
            ${windowsConf}
            EOF
          '';
        }
      );
    };

    loader = {
      systemd-boot = {
        enable = lib.mkForce false;
        extraFiles."shellx64.efi" = pkgs.edk2-uefi-shell.efi;
        extraEntries."windows.conf" = windowsConf;
      };
      grub.enable = lib.mkForce false;
      timeout = lib.mkForce 5;
      efi.efiSysMountPoint = "/efi22";
    };

    kernelPackages = pkgs.linuxPackagesFor (
      let
        version = "6.10.11";
        src = pkgs.fetchurl {
          url = "mirror://kernel/linux/kernel/v${builtins.head (lib.splitVersion version)}.x/linux-${version}.tar.xz";
          hash = "sha256-+02gRvjBhRWfRTfe2IejCsxp2RxVWg/3+rxFIPWaMJY=";
        };
      in
      (pkgs.linuxManualConfig {
        inherit src;
        inherit (config.boot) kernelPatches;
        version = "${version}-gerg";
        config = {
          CONFIG_RUST = "y";
          CONFIG_MODULES = "y";
        };
        configfile = ./kernelConfig;
      }).overrideAttrs
        (old: {
          passthru = old.passthru or { } // {
            features = lib.foldr (x: y: x.features or { } // y) {
              efiBootStub = true;
              netfilterRPFilter = true;
              ia32Emulation = true;
            } config.boot.kernelPatches;
          };
          meta = old.meta or { } // {
            broken = false;
          };
        })
    );
  };
}
