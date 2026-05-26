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

REMOTE_USER="$(<"${SECRETS_DIR}/remote_user")"
REMOTE_HOST="$(<"${SECRETS_DIR}/remote_host")"
SSH_KEY="${SECRETS_DIR}/ssh_key"

export BORG_RSH="ssh -i ${SSH_KEY}"
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
  local paths=("$@")

  local repo="${REMOTE_USER}@${REMOTE_HOST}:${repo_path}"
  local archive_name
  archive_name="backup-$(date +%Y-%m-%dT%H:%M:%S)"

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

BACKUP="${1:-}"

case "$BACKUP" in
  apps)
    log "===== Starting apps backup ====="
    # Tilde is expanded by the remote SSH shell, not locally.
    # shellcheck disable=SC2088
    run_backup "~/disk1/backups" 30 \
      "/mnt/storage/sonarr/Backups" \
      "/mnt/storage/radarr/Backups" \
      "/mnt/storage/prowlarr/Backups" \
      "/mnt/storage/emby/backups" \
      "/mnt/storage/mealie/backups" \
      "/mnt/storage/jellyseerr/backups"
    log "===== Apps backup completed successfully ====="
    ;;

  immich)
    log "===== Starting Immich backup ====="
    # shellcheck disable=SC2088
    run_backup "~/disk2/immich_backup" 60 \
      "/mnt/storage/immich/upload" \
      "/mnt/storage/pictures"
    log "===== Immich backup completed successfully ====="
    ;;

  *)
    echo "Usage: $0 {apps|immich}" >&2
    exit 1
    ;;
esac
