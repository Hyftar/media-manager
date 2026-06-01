{ config, pkgs, ... }:
let
  repoUrl = "https://github.com/Hyftar/beer_tracker";
in
{
  sops.secrets."beer-github-runner/token" = {
    sopsFile = ../secrets/beer-github-runner.yaml;
  };

  services.github-runners.beer-tracker = {
    enable = true;
    name = "cia-server-beer-tracker";
    url = repoUrl;
    tokenFile = config.sops.secrets."beer-github-runner/token".path;
    replace = true;
    extraLabels = [ "nixos" "x86_64" ];

    extraPackages = with pkgs; [
      git
      gnutar
      gzip
      gnumake
      gcc
      elixir
      erlang
    ];
  };
}
