_: {
  config,
  lib,
  ...
}: {
  options.localModules.remoteBuild = {
    enable = lib.mkEnableOption "";
    isBuilder = lib.mkEnableOption "";
  };
  config = lib.mkMerge [
    (
      lib.mkIf config.localModules.remoteBuild.enable {
        nix = {
          settings = {
            keep-outputs = false;
            keep-derivations = false;
            builders-use-substitutes = true;
            max-jobs = 0;
            substituters = ["ssh-ng://nix-ssh@gerg-desktop" "https://cache.nixos.org/"];
            trusted-public-keys = ["gerg-desktop:6p1+h6jQnb1MOt3ra3PlQpfgEEF4zRrQWiEuAqcjBj8=" "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="];
            secret-key-files = "/persist/cache-keys/cache-priv-key.pem";
          };
          distributedBuilds = true;
          buildMachines = [
            {
              hostName = "gerg-desktop";
              protocol = "ssh-ng";
              maxJobs = 32;
              systems = ["x86_64-linux" "i686-linux"];
              supportedFeatures = ["big-parallel" "nixos-test" "kvm" "benchmark"];
              sshUser = "builder";
              sshKey = "/etc/ssh/ssh_host_ed25519_key";
              publicHostKey = "BQxvBOWsTw1gdNDR0KzrSRmbVhDrJdG05vYXkVmw8yA";
            }
          ];
        };
        programs.ssh.knownHosts = {
          gerg-desktop = {
            extraHostNames = ["gerg-desktop.lan"];
            publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIeHsGcmOdIMzV+SNe4WFcA3CPHCNb1aqxThkXtm7G/1";
          };
        };
      }
    )

    (
      let
        keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIq9YTf4jlVCKBKn44m4yJvj94C7pTOyaa4VjZFohNqD root@mom-laptop"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJUKHZasYQUAmRBiqtx1drDxfq18/N4rKydCtPHx461I root@game-laptop"
        ];
      in
        lib.mkIf
        config.localModules.remoteBuild.isBuilder
        {
          users = {
            groups.builder = {};
            users.builder = {
              createHome = false;
              isSystemUser = true;
              openssh.authorizedKeys = {inherit keys;};
              useDefaultShell = true;
              group = "builder";
            };
          };

          nix = {
            settings = {
              trusted-users = ["builder" "nix-ssh"];
              keep-outputs = true;
              keep-derivations = true;
            };
            sshServe = {
              enable = true;
              write = true;
              inherit keys;
              protocol = "ssh-ng";
            };
          };
        }
    )
  ];
}
