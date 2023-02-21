_: {
  config,
  lib,
  options,
  pkgs,
  ...
}:
with lib; let
  cfg = config.localModules.sxhkd;
  keybindingsStr = ''
    XF86AudioPlay
      playerctl play-pause
    XF86AudioPause
      playerctl play-pause
    XF86AudioStop
      playerctl stop
    XF86AudioNext
      playerctl next
    XF86AudioPrev
      playerctl previous
    XF86AudioRaiseVolume
      amixer sset Master 40+
    XF86AudioLowerVolume
      amixer sset Master 40-
    XF86AudioMute
      amixer sset Master toggle
    XF86MonBrightnessUp
      brightnessctl s 20+
    XF86MonBrightnessDown
      brightnessctl s 20-
    Print
      maim $HOME/Screenshots/$(date +%Y-%m-%d_%H-%m-%s).jpg
    Print + shift
      maim | xclip -selection clipboard -t image/png
    super + Print
      maim -s $HOME/Screenshots/$(date +%Y-%m-%d_%H-%m-%s).jpg
    super + Print + shift
      maim -s | xclip -selection clipboard -t image/png
  '';
  configFile = pkgs.writeText "sxhkdrc" keybindingsStr;
in {
  options.localModules.sxhkd = {
    enable = mkEnableOption "simple X hotkey daemon";
  };
  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.maim #screenshooter
      pkgs.brightnessctl #brightness control for laptop
      pkgs.playerctl #music control
      pkgs.xclip
      pkgs.coreutils
    ];
    systemd.user.services.sxhkd = {
      description = "sxhkd hotkey daemon";
      wantedBy = ["graphical-session.target"];
      partOf = ["graphical-session.target"];
      serviceConfig = {
        ExecStart = "${pkgs.sxhkd}/bin/sxhkd -c ${configFile}";
        RestartSec = 3;
        Restart = "always";
      };
    };
  };
}
