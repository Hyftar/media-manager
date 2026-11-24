# Continuous deployment of Subcipher (github.com/Hyftar/subcipher-decoder),
# a swarm stack outside Arcane: its GitHub Actions deploy each push to main.
# The stack file lives in that repository (deploy/stack.yaml).
#
# The `subcipher-deploy` user is in the docker group (root-equivalent), so its
# only SSH key can do nothing but run scripts/subcipher-deploy.sh with the SHA
# of a commit on main and the stack settings on stdin: no shell, no
# forwarding, no pty, no other command.
{ config, pkgs, ... }:

let
  # The public half of the key given to GitHub Actions (DEPLOY_SSH_KEY).
  publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFFdYFwf6JbkvF74TvexQVmTd0gxQtsmUZyk+fwSd1NQ subcipher-machine-user";

  subcipher-deploy = pkgs.writeShellApplication {
    name = "subcipher-deploy";
    runtimeInputs = [
      config.virtualisation.docker.package
      pkgs.coreutils
      pkgs.curl
      pkgs.gawk
      pkgs.jq
      pkgs.util-linux # flock
    ];
    text = builtins.readFile ../scripts/subcipher-deploy.sh;
  };
in
{
  users.users.subcipher-deploy = {
    isSystemUser = true;
    group = "subcipher-deploy";
    extraGroups = [ "docker" ];
    home = "/var/lib/subcipher-deploy";
    createHome = true;
    # sshd runs the forced command through the login shell: not nologin.
    shell = pkgs.bash;
    openssh.authorizedKeys.keys = [
      ''restrict,command="${subcipher-deploy}/bin/subcipher-deploy" ${publicKey}''
    ];
  };

  users.groups.subcipher-deploy = { };

  # To redeploy by hand: sudo -H -u subcipher-deploy subcipher-deploy <SHA> < deploy.env
  environment.systemPackages = [ subcipher-deploy ];
}
