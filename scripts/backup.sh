#!/usr/bin/env bash

# =============================================================================
# Borg Backup Script
#
# Secrets are provisioned by sops-nix at $BORG_SECRETS_DIR (default
# /run/secrets/borg) as tmpfs files restricted to the service user:
#   - remote_user  (SSH user)
#   - remote_host  (SSH host)
#   - passphrase   (borg repo passphrase)
#   - ssh_key      (SSH private key)
# =============================================================================

set -euo pipefail

SECRETS_DIR="${BORG_SECRETS_DIR:-/run/secrets/borg}"

# Data locations, set by modules/backup.nix from cia.paths.
CONFIG_DIR="${CONFIG_DIR:?CONFIG_DIR is not set}"
PHOTOS_DIR="${PHOTOS_DIR:?PHOTOS_DIR is not set}"

REMOTE_USER="$(<"${SECRETS_DIR}/remote_user")"
REMOTE_HOST="$(<"${SECRETS_DIR}/remote_host")"
SSH_KEY="${SECRETS_DIR}/ssh_key"

# accept-new: the first run on a fresh install has no known_hosts entry yet.
export BORG_RSH="ssh -i ${SSH_KEY} -o StrictHostKeyChecking=accept-new"
export BORG_PASSCOMMAND="cat ${SECRETS_DIR}/passphrase"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

on_error() {
  log "ERROR: Backup failed at line $1. Exit code: $2"
  exit "$2"
}

trap 'on_error $LINENO $?' ERR

# =============================================================================
# run_backup REPO_PATH KEEP_LAST PATHS...
#   REPO_PATH  - remote path for the borg repository
#   KEEP_LAST  - number of archives to keep
#   PATHS...   - one or more local paths to back up
# =============================================================================
run_backup() {
  local repo_path="$1"
  local keep_last="$2"
  shift 2

  # Skip paths that don't exist (yet): borg would otherwise exit with a
  # warning and fail the whole run.
  local paths=() path
  for path in "$@"; do
    if [[ -e "$path" ]]; then
      paths+=("$path")
    else
      log "Skipping missing path: ${path}"
    fi
  done
  if (( ${#paths[@]} == 0 )); then
    log "Nothing to back up for ${repo_path}"
    return 0
  fi

  local repo="${REMOTE_USER}@${REMOTE_HOST}:${repo_path}"
  local archive_name
  archive_name="backup-$(date +%Y-%m-%dT%H:%M:%S)"

  # `borg init` refuses to touch an existing repository, so this only ever
  # creates new ones.
  if ! borg info "${repo}" >/dev/null 2>&1; then
    log "Initialising repository: ${repo}"
    borg init --encryption=repokey-blake2 --make-parent-dirs "${repo}"
  fi

  log "--- Backing up: ${paths[*]} -> ${repo} ---"

  log "Creating archive: ${archive_name}"
  borg create \
    --verbose \
    --stats \
    --show-rc \
    --compression lz4 \
    --progress \
    "${repo}::${archive_name}" \
    "${paths[@]}"

  log "Pruning old archives (keeping last ${keep_last})..."
  borg prune \
    --list \
    --show-rc \
    --keep-last "${keep_last}" \
    "${repo}"

  log "Compacting repository..."
  borg compact "${repo}"

  log "Running repository check..."
  borg check "${repo}"

  log "--- Done: ${repo} ---"
}

# The new server (i5-14500, NixOS 26.05) writes to its own repositories so it
# can't prune the old server's archives. The old ones stay in ~/disk1/backups
# and ~/disk2/immich_backup.
# Tilde is expanded by the remote SSH shell, not locally.
# shellcheck disable=SC2088
REPO_ROOT_1="~/disk1/cia-2026"
# shellcheck disable=SC2088
REPO_ROOT_2="~/disk2/cia-2026"

BACKUP="${1:-}"

case "$BACKUP" in
  apps)
    log "===== Starting apps backup ====="
    run_backup "${REPO_ROOT_1}/backups" 30 \
      "${CONFIG_DIR}/sonarr/Backups" \
      "${CONFIG_DIR}/radarr/Backups" \
      "${CONFIG_DIR}/prowlarr/Backups" \
      "${CONFIG_DIR}/emby/backups" \
      "${CONFIG_DIR}/jellyseerr/backups"
    log "===== Apps backup completed successfully ====="
    ;;

  immich)
    log "===== Starting Immich backup ====="
    run_backup "${REPO_ROOT_2}/immich_backup" 60 \
      "${PHOTOS_DIR}/immich/upload" \
      "${PHOTOS_DIR}/pictures"
    log "===== Immich backup completed successfully ====="
    ;;

  *)
    echo "Usage: $0 {apps|immich}" >&2
    exit 1
    ;;
esac
