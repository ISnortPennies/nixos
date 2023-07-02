_: {
  config,
  lib,
  ...
}: {
  options.local.remoteBuild = {
    enable = lib.mkEnableOption "";
    isBuilder = lib.mkEnableOption "";
  };
  config = lib.mkMerge [
    (
      lib.mkIf config.local.remoteBuild.enable {
        nix = {
          settings = {
            keep-outputs = false;
            keep-derivations = false;
            builders-use-substitutes = true;
            max-jobs = 0;
            substituters = ["ssh-ng://nix-ssh@gerg-desktop" "https://cache.nixos.org/"];
            trusted-public-keys = ["gerg-desktop:6p1+h6jQnb1MOt3ra3PlQpfgEEF4zRrQWiEuAqcjBj8=" "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="];
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
              publicHostKey = config.local.keys.gerg-desktop_fingerprint;
            }
          ];
        };
      }
    )

    (
      let
        keys = [
          config.local.keys.root_moms-laptop
          config.local.keys.root_game-laptop
        ];
      in
        lib.mkIf
        config.local.remoteBuild.isBuilder
        {
          sops.secrets.store_key = {};
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
          services.openssh.extraConfig = ''
            Match User builder
              AllowAgentForwarding no
              AllowTcpForwarding no
              PermitTTY no
              PermitTunnel no
              X11Forwarding no
            Match All
          '';

          nix = {
            settings = {
              trusted-users = ["builder" "nix-ssh"];
              keep-outputs = true;
              keep-derivations = true;
              secret-key-files = config.sops.secrets.store_key.path;
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
