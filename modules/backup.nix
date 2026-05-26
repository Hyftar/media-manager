{ config, pkgs, ... }:

let
  borgUser = config.users.users.hyftar.name;

  backupScript = pkgs.writeShellApplication {
    name = "borg-backup";
    runtimeInputs = [ pkgs.borgbackup pkgs.openssh ];
    text = builtins.readFile ../scripts/backup.sh;
  };

  secretOpts = {
    owner = borgUser;
    mode = "0400";
  };
in
{
  sops.defaultSopsFile = ../secrets/borg.yaml;
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";

  sops.secrets = {
    "borg/remote_user" = secretOpts;
    "borg/remote_host" = secretOpts;
    "borg/passphrase" = secretOpts;
    "borg/ssh_key" = secretOpts // {
      sopsFile = ../secrets/borg.key;
      format = "binary";
    };
  };

  systemd.services."config-backup" = {
    description = "Backup app configs and databases";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = borgUser;
      ExecStart = "${backupScript}/bin/borg-backup apps";
    };
  };

  systemd.timers."config-backup" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 05:00:00";
      Persistent = true;
      AccuracySec = "1h";
    };
  };

  systemd.services."immich-backup" = {
    description = "Backup immich uploads";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = borgUser;
      ExecStart = "${backupScript}/bin/borg-backup immich";
    };
  };

  systemd.timers."immich-backup" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 03:00:00";
      Persistent = true;
      AccuracySec = "1h";
    };
  };
}
