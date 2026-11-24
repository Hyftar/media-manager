#!/usr/bin/env bash
# Deploys one commit of Subcipher on the swarm. Runs ON THE SERVER, as the
# forced command of the GitHub Actions SSH key (see deploy/nixos.nix), so the
# key can do nothing else:
#
#   ssh -p 22 subcipher-deploy@server <40-character commit SHA> < settings.env
#
# The settings of the stack (the variables of deploy/.env.example, from the
# GitHub secrets) come on stdin as KEY=VALUE lines. They are parsed, never
# run: only the known names are accepted, and values are taken literally.
#
# It fetches deploy/stack.yaml at that commit from GitHub, deploys the image
# built from that commit (ghcr.io/...:sha-<SHA>) with those settings, then
# waits for the swarm to finish the update and fails if it was rolled back.
#
# By hand, on the server, with a .env file:
#   sudo -H -u subcipher-deploy subcipher-deploy <SHA> < deploy.env
set -euo pipefail

repo="${SUBCIPHER_REPO:-Hyftar/subcipher-decoder}"
image_repo="${SUBCIPHER_IMAGE_REPO:-ghcr.io/hyftar/subcipher-decoder}"
stack="${STACK_NAME:-subcipher}"
timeout="${DEPLOY_TIMEOUT:-300}"

# The settings deploy/stack.yaml reads (see deploy/.env.example). Not
# SUBCIPHER_IMAGE: the image is the one of the commit.
settings=(
  POSTGRES_PASSWORD SECRET_KEY_BASE
  PHX_HOST PHX_SCHEME PHX_URL_PORT PHX_CHECK_ORIGIN APP_PORT
  SMTP_HOST SMTP_PORT SMTP_USERNAME SMTP_PASSWORD SMTP_TLS SMTP_SSL
  MAIL_FROM MAIL_FROM_NAME
)

# The command: a full commit SHA, nothing else gets through.
sha="${SSH_ORIGINAL_COMMAND:-${1:-}}"
if [[ ! "$sha" =~ ^[0-9a-f]{40}$ ]]; then
  echo "usage: <40-character commit SHA> < settings.env" >&2
  exit 2
fi

if [[ -t 0 ]]; then
  echo "Give the settings on stdin (KEY=VALUE lines): ... < deploy.env" >&2
  exit 2
fi

# Start from none of them, whatever the environment has.
unset "${settings[@]}"

# KEY=VALUE lines; blank lines and # comments are skipped, and one pair of
# quotes around a value is removed. Values are never printed (secrets).
lineno=0
while IFS= read -r line || [[ -n "$line" ]]; do
  lineno=$((lineno + 1))
  line="${line%$'\r'}"
  [[ -z "${line//[[:space:]]/}" || "$line" =~ ^[[:space:]]*# ]] && continue

  if [[ ! "$line" =~ ^([A-Z][A-Z0-9_]*)=(.*)$ ]]; then
    echo "settings, line $lineno: not KEY=VALUE." >&2
    exit 2
  fi
  name="${BASH_REMATCH[1]}"
  value="${BASH_REMATCH[2]}"

  if [[ " ${settings[*]} " != *" $name "* ]]; then
    echo "settings, line $lineno: unknown setting $name." >&2
    exit 2
  fi

  if [[ ${#value} -ge 2 && ( "$value" == \"*\" || "$value" == \'*\' ) ]]; then
    value="${value:1:${#value}-2}"
  fi

  export "$name=$value"
done

# The published port: not one of the host's (22, 80, 443...).
if [[ -n "${APP_PORT:-}" ]] && ! [[ "$APP_PORT" =~ ^[0-9]{4,5}$ && "$APP_PORT" -ge 1024 && "$APP_PORT" -le 65535 ]]; then
  echo "settings: APP_PORT must be a port number from 1024 to 65535." >&2
  exit 2
fi

# Only commits already on main. GitHub serves commits pushed to forks under
# this repository's URLs too: without this, the key could deploy a stack.yaml
# of anyone's making (bind-mounting / or the Docker socket: root).
status="$(curl -fsSL --retry 3 -H 'Accept: application/vnd.github+json' \
  "https://api.github.com/repos/$repo/compare/main...$sha?per_page=1" \
  | jq -r .status)"
if [[ "$status" != behind && "$status" != identical ]]; then
  echo "Commit $sha is not on main (status: $status)." >&2
  exit 2
fi

# One deploy at a time.
exec 9>"$HOME/.deploy.lock"
flock 9

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

curl -fsSL --retry 3 -o "$workdir/stack.yaml" \
  "https://raw.githubusercontent.com/$repo/$sha/deploy/stack.yaml"

image="$image_repo:sha-$sha"
export SUBCIPHER_IMAGE="$image"

echo "Deploying $image"
docker stack deploy \
  --with-registry-auth \
  --resolve-image always \
  --prune \
  -c "$workdir/stack.yaml" \
  "$stack"

# Wait for the app's rolling update. Failed if the swarm rolled back (the new
# container never got healthy): a rollback puts the previous image back in
# the service. Done once no update is in progress and a container of the new
# image runs. (The update state alone can be a leftover of the last deploy.)
service="${stack}_app"
deadline=$((SECONDS + timeout))

while ((SECONDS < deadline)); do
  spec_image="$(docker service inspect "$service" \
    --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}')"
  state="$(docker service inspect "$service" \
    --format '{{if .UpdateStatus}}{{.UpdateStatus.State}}{{end}}')"

  if [[ "$spec_image" != "$image"* ]]; then
    echo "Deploy failed: the swarm went back to $spec_image (state: $state)." >&2
    docker service ps "$service" | head -n 6 >&2
    exit 1
  fi

  case "$state" in
    updating | rollback_started | paused | rollback_paused) ;;
    *)
      tasks="$(docker service ps "$service" --filter desired-state=running \
        --format '{{.Image}} {{.CurrentState}}')"
      if awk -v image="$image" 'index($0, image) && / Running/ { found = 1 }
          END { exit !found }' <<<"$tasks"; then
        echo "Deployed $image"
        exit 0
      fi
      ;;
  esac

  sleep 5
done

echo "Deploy timed out after ${timeout}s (state: ${state:-none})." >&2
exit 1
