# Docker Compose stacks managed by Arcane.
#
# Compose files live in this repo as plain YAML (stacks/<name>/). Nix only
# supplies the variables (uids, gids, paths) through a generated `.env`, plus
# optional secret env files from sops. Each stack is copied to
# /opt/stacks/<name>, which Arcane scans as its projects directory, so Arcane
# can update and redeploy them. Edit the stacks in git, not in Arcane's UI: the
# copies are read-only and are overwritten on every deploy.
{ config, lib, pkgs, ... }:
let
  inherit (lib) mkOption types;

  cfg = config.cia.stacks;
  root = "/opt/stacks";
  compose = "${pkgs.docker-compose}/bin/docker-compose";

  toEnv = attrs: lib.concatStrings (lib.mapAttrsToList (k: v: "${k}=${toString v}\n") attrs);

  # The stack as it will appear on disk, validated at build time.
  mkSource =
    name: stack:
    pkgs.runCommand "stack-${name}" { nativeBuildInputs = [ pkgs.docker-compose ]; } ''
      cp -r ${stack.source} $out
      chmod -R u+w $out
      cp ${pkgs.writeText "${name}.env" (toEnv stack.env)} $out/.env

      # Validate YAML and variable interpolation; secret files are only
      # available on the server, so stand in empty ones.
      cp -r $out check
      ${lib.concatMapStrings (f: "touch check/${f}\n") (lib.attrNames stack.secrets)}
      docker-compose --project-directory check -f check/compose.yaml config --quiet
    '';

  # Refers to /etc/stacks/<name> (stable path) rather than the store path, so
  # a change to the stack reloads the unit instead of restarting it: only the
  # services whose configuration changed get recreated.
  mkDeploy =
    name: stack:
    pkgs.writeShellScript "stack-${name}-deploy" ''
      set -euo pipefail
      mkdir -p ${root}/${name}
      ${pkgs.rsync}/bin/rsync -r --checksum --delete --chmod=D755,F644 /etc/stacks/${name}/ ${root}/${name}/
      ${lib.concatStrings (
        lib.mapAttrsToList (file: path: ''
          install -m 0400 -o ${stack.secretsOwner} ${path} ${root}/${name}/${file}
        '') stack.secrets
      )}
      cd ${root}/${name}
      ${compose} up -d --remove-orphans
    '';

  mkStop =
    name:
    pkgs.writeShellScript "stack-${name}-stop" ''
      cd ${root}/${name} && ${compose} down
    '';

  unitsFor = stack: map (d: "stack-${d}.service") stack.dependsOn ++ stack.after;
in
{
  options.cia.stacksDirectory = mkOption {
    type = types.str;
    default = root;
    readOnly = true;
    description = "Where stacks are deployed; Arcane's projects directory.";
  };

  options.cia.stacks = mkOption {
    default = { };
    description = "Docker Compose stacks deployed to ${root} and managed by Arcane.";
    type = types.attrsOf (
      types.submodule {
        options = {
          source = mkOption {
            type = types.path;
            description = "Directory containing compose.yaml (and any files it mounts with relative paths).";
          };

          env = mkOption {
            type = types.attrsOf (types.oneOf [ types.str types.int ]);
            default = { };
            description = "Variables written to the stack's .env, used for interpolation in compose.yaml.";
          };

          secrets = mkOption {
            type = types.attrsOf types.str;
            default = { };
            example = {
              "secrets.env" = "/run/secrets-rendered/app.env";
            };
            description = "Files copied into the stack directory at deploy time (file name to source path), e.g. sops templates.";
          };

          secretsOwner = mkOption {
            type = types.str;
            default = "root";
            description = "Owner of the copied secret files. Arcane must be able to read them to redeploy the stack.";
          };

          dependsOn = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Stacks that must be up first (e.g. the one creating a shared network).";
          };

          after = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Other systemd units to start after.";
          };
        };
      }
    );
  };

  config = lib.mkIf (cfg != { }) {
    environment.etc = lib.mapAttrs' (
      name: stack: lib.nameValuePair "stacks/${name}" { source = mkSource name stack; }
    ) cfg;

    systemd.tmpfiles.rules = [ "d ${root} 0755 root root -" ];

    systemd.services = lib.mapAttrs' (
      name: stack:
      lib.nameValuePair "stack-${name}" {
        description = "Docker Compose stack ${name}";
        after = [ "docker.service" "network-online.target" ] ++ unitsFor stack;
        wants = [ "docker.service" "network-online.target" ] ++ unitsFor stack;
        wantedBy = [ "multi-user.target" ];
        reloadTriggers = [ (mkSource name stack) ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          TimeoutStartSec = 600;
          ExecStart = mkDeploy name stack;
          ExecReload = mkDeploy name stack;
          ExecStop = mkStop name;
        };
      }
    ) cfg;
  };
}
