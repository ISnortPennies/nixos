_: {
  pkgs,
  config,
  self,
  ...
}: {
  #discord bot stuff
  systemd.services.parrot = {
    enable = true;
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network-online.target"];
    script = "${self.packages.${pkgs.system}.parrot}/bin/parrot";
    serviceConfig = {
      EnvironmentFile = config.sops.secrets.discordenv.path;
      Restart = "on-failure";
      RestartSec = "30s";
    };
  };
  sops.secrets.discordenv = {};
}
