{ config, pkgs, ... }:
let
  appUser = "beer_tracker";
  appGroup = "beer_tracker";

  beerTrackerVersion = "0.1.0";
  beerTrackerAppName = "beer_tracker";   # must match :app in mix.exs
  beerTrackerRelease = pkgs.fetchurl {
    url = "https://github.com/Hyftar/beer_tracker/releases/download/v${beerTrackerVersion}/${beerTrackerAppName}-${beerTrackerVersion}.tar.gz";
    hash = "sha256-0GSjhxE5AIJD9YMw0DVmt8P3fNCoYn1TtfYCxxclYHo=";
  };

  beerTrackerDir = pkgs.runCommand "beer-tracker-release" { } ''
    mkdir -p $out
    tar xzf ${beerTrackerRelease} -C $out --strip-components=1
  '';

  startScript = pkgs.writeShellScript "beer-tracker-start" ''
    export PHX_HOST="beer.grosluxe.ca"
    export PORT="8337"
    export PHX_SERVER="true"
    export DATABASE_URL="postgresql://${appUser}:$(cat ${config.sops.secrets."beer-tracker/db_password".path})@localhost:5432/beer_tracker"
    export SECRET_KEY_BASE="$(cat ${config.sops.secrets."beer-tracker/secret_key_base".path})"
    # MQTT — subscribe to the loopback Mosquitto listener
    export MQTT_HOST="127.0.0.1"
    export MQTT_PORT="1884"
    export MQTT_TOPIC="ispindel/#"
    exec ${beerTrackerDir}/bin/${beerTrackerAppName} start
  '';
in
{
  sops.secrets."mosquitto/ispindel_password" = {
    sopsFile = ../secrets/beer.yaml;
    owner = "mosquitto";
    mode = "0400";
  };
  sops.secrets."beer-tracker/db_password" = {
    sopsFile = ../secrets/beer.yaml;
    owner = appUser;
    group = "postgres";   # db-init runs as postgres and reads this
    mode = "0440";
  };
  sops.secrets."beer-tracker/secret_key_base" = {
    sopsFile = ../secrets/beer.yaml;
    owner = appUser;
    mode = "0400";
  };

  users.groups.${appGroup}.gid = 2011;
  users.users.${appUser} = {
    isSystemUser = true;
    isNormalUser = false;
    createHome = false;
    group = appGroup;
    uid = 908;
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/beer-tracker 0750 ${appUser} ${appGroup} -"
  ];

  services.mosquitto = {
    enable = true;
    listeners = [
      # External listener — iSpindel authenticates with SOPS-managed password
      {
        port = 1883;
        users.ispindel = {
          passwordFile = config.sops.secrets."mosquitto/ispindel_password".path;
          acl = [ "readwrite #" ];
        };
      }
      # Loopback listener — Phoenix app subscribes without auth
      {
        port = 1884;
        address = "127.0.0.1";
        omitPasswordAuth = true;
        settings.allow_anonymous = true;
        acl = [ "pattern readwrite #" ];
      }
    ];
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16.withPackages (ps: [ ps.timescaledb ]);
    settings.shared_preload_libraries = "timescaledb";
    ensureDatabases = [ "beer_tracker" ];
    ensureUsers = [{
      name = appUser;
      ensureDBOwnership = true;
    }];
  };

  # Sets the DB password and enables the TimescaleDB extension on first boot.
  # Re-runs on subsequent boots but ALTER USER is idempotent.
  systemd.services.beer-tracker-db-init = {
    description = "Beer Tracker PostgreSQL initialisation";
    after = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ config.services.postgresql.package ];   # provides psql
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "postgres";
      ExecStart = pkgs.writeShellScript "beer-tracker-db-init" ''
        psql -d beer_tracker -c "ALTER USER ${appUser} WITH PASSWORD '$(cat ${config.sops.secrets."beer-tracker/db_password".path})';"
        psql -d beer_tracker -c "CREATE EXTENSION IF NOT EXISTS timescaledb;"
      '';
    };
  };

  systemd.services.beer-tracker = {
    description = "Beer Tracker Phoenix Application";
    after = [ "network.target" "postgresql.service" "beer-tracker-db-init.service" ];
    requires = [ "postgresql.service" "beer-tracker-db-init.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "exec";
      User = appUser;
      Group = appGroup;
      WorkingDirectory = "/var/lib/beer-tracker";
      ExecStart = startScript;
      Restart = "on-failure";
      RestartSec = 10;
    };
  };

  networking.firewall.allowedTCPPorts = [ 1883 ];
}
