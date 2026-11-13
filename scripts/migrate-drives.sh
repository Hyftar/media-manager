#!/usr/bin/env bash

# =============================================================================
# One-time migration of the old storage drive (now mounted at PHOTOS_DIR) to
# the new layout:
#   1. app config        PHOTOS_DIR/<app>          -> CONFIG_DIR/<app>
#   2. Immich database   PHOTOS_DIR/immich/data    -> CONFIG_DIR/immich/postgres
#      (+ model cache)   PHOTOS_DIR/immich/model-cache -> CONFIG_DIR/immich/model-cache
#   3. books             PHOTOS_DIR/books          -> MEDIA_DIR/books
#
# Copies only: nothing is deleted from the photos drive. Destinations are made
# identical to their source (--delete), replacing anything configured on the
# new machine in the meantime. All stacks are stopped during the copy so that
# databases are consistent, then started again.
#
# Usage: sudo cia-migrate-drives [--dry-run]
# Paths come from modules/migration.nix (cia.paths).
# =============================================================================

set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:?CONFIG_DIR is not set}"
PHOTOS_DIR="${PHOTOS_DIR:?PHOTOS_DIR is not set}"
MEDIA_DIR="${MEDIA_DIR:?MEDIA_DIR is not set}"

APPS=(arcane caddy emby sonarr radarr prowlarr qbittorrent jellyseerr)
# Dependents first; started again in reverse order.
STACKS=(stack-immich stack-media stack-core)

DRY_RUN=false
case "${1:-}" in
  "") ;;
  --dry-run) DRY_RUN=true ;;
  *) echo "Usage: $0 [--dry-run]" >&2; exit 1 ;;
esac

log() {
  echo "[$(date '+%H:%M:%S')] $*"
}

die() {
  log "ERROR: $*" >&2
  exit 1
}

# --- Pre-flight checks -------------------------------------------------------

(( EUID == 0 )) || die "must run as root (sudo)"

# Without the real drives, the sources would be the empty placeholder folders
# and --delete would wipe the destinations.
for dir in "$PHOTOS_DIR" "$MEDIA_DIR"; do
  mountpoint -q "$dir" || die "$dir is not a mounted drive; set dataDrivesInstalled = true and deploy first"
done

# source|destination pairs; missing sources are skipped.
PAIRS=()
for app in "${APPS[@]}"; do
  PAIRS+=("${PHOTOS_DIR}/${app}|${CONFIG_DIR}/${app}")
done
PAIRS+=(
  "${PHOTOS_DIR}/immich/data|${CONFIG_DIR}/immich/postgres"
  "${PHOTOS_DIR}/immich/model-cache|${CONFIG_DIR}/immich/model-cache"
  "${PHOTOS_DIR}/books|${MEDIA_DIR}/books"
)

TODO=()
config_bytes=0
for pair in "${PAIRS[@]}"; do
  src="${pair%%|*}"
  if [[ -d "$src" ]]; then
    TODO+=("$pair")
    # Books go to the media drive; everything else to the main drive.
    if [[ "${pair##*|}" == "${CONFIG_DIR}"/* ]]; then
      config_bytes=$(( config_bytes + $(du -sb "$src" | cut -f1) ))
    fi
  else
    log "Skipping, not found: ${src}"
  fi
done
(( ${#TODO[@]} > 0 )) || die "nothing to migrate"

# Free space on the main drive, with a 10% margin.
mkdir -p "$CONFIG_DIR"
free_bytes=$(df --output=avail -B1 "$CONFIG_DIR" | tail -n1)
needed_bytes=$(( config_bytes + config_bytes / 10 ))
log "Config to copy: $(numfmt --to=iec "$config_bytes"), free on $(df --output=target "$CONFIG_DIR" | tail -n1): $(numfmt --to=iec "$free_bytes")"
(( needed_bytes < free_bytes )) || die "not enough space on the main drive"

log "Plan:"
for pair in "${TODO[@]}"; do
  log "  ${pair%%|*} -> ${pair##*|}"
done

if $DRY_RUN; then
  RSYNC_OPTS=(--dry-run --itemize-changes)
  log "Dry run: stacks keep running, nothing is copied."
else
  RSYNC_OPTS=()
  read -r -p "Stop all stacks and copy? [y/N] " answer
  [[ "$answer" == [yY] ]] || die "aborted"
fi

# --- Copy ----------------------------------------------------------------------

restart_stacks() {
  log "Starting stacks..."
  local i
  for (( i = ${#STACKS[@]} - 1; i >= 0; i-- )); do
    systemctl start "${STACKS[i]}" || log "WARNING: ${STACKS[i]} failed to start; see journalctl -u ${STACKS[i]}"
  done
}

if ! $DRY_RUN; then
  log "Stopping stacks..."
  for unit in "${STACKS[@]}"; do
    systemctl stop "$unit"
  done
  # Bring the services back even if a copy fails.
  trap restart_stacks EXIT
fi

for pair in "${TODO[@]}"; do
  src="${pair%%|*}"
  dst="${pair##*|}"
  log "Copying ${src} -> ${dst}"
  mkdir -p "$dst"
  # -aHAX: keep permissions, owners, hard links, ACLs and xattrs; numeric ids
  # because the uids are the same on both machines (fixed in the Nix config).
  rsync -aHAX --numeric-ids --delete "${RSYNC_OPTS[@]}" "${src}/" "${dst}/"
done

if ! $DRY_RUN; then
  log "Re-applying tmpfiles rules (ownership and permissions)..."
  systemd-tmpfiles --create || log "WARNING: systemd-tmpfiles reported errors"
  trap - EXIT
  restart_stacks
fi

log "Done. Once everything works, delete the old copies from ${PHOTOS_DIR}:"
for pair in "${TODO[@]}"; do
  log "  ${pair%%|*}"
done
