#!/usr/bin/env bash

# Attach pre-generated DEP-11 metadata to an aptly-published repository.
# Workflow:
#   1) aptly publish repo <repo> filesystem:public
#   2) copy DEP-11 files into dists/<suite>/<component>/dep11/
#   3) aptly publish update <suite> filesystem:public
#
# This script does NOT generate DEP-11 metadata.

set -Eeuo pipefail

# -----------------------------
# Configuration (env-overridable)
# -----------------------------
REPO_NAME="${REPO_NAME:-}"
SUITE="${SUITE:-bookworm}"
COMPONENT="${COMPONENT:-main}"
PUBLISH_ENDPOINT="${PUBLISH_ENDPOINT:-filesystem:public}"
PUBLIC_DIR="${PUBLIC_DIR:-/var/www/aptly/public}"
DEP11_SOURCE_DIR="${DEP11_SOURCE_DIR:-}"
RUN_INITIAL_PUBLISH="${RUN_INITIAL_PUBLISH:-true}"
DRY_RUN="${DRY_RUN:-false}"

# -----------------------------
# Helpers
# -----------------------------
log() {
  printf '[INFO] %s\n' "$*"
}

err() {
  printf '[ERROR] %s\n' "$*" >&2
}

die() {
  err "$*"
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    printf '[DRY-RUN] %q' "$1"
    shift
    for arg in "$@"; do
      printf ' %q' "$arg"
    done
    printf '\n'
  else
    "$@"
  fi
}

# -----------------------------
# Validation
# -----------------------------
require_cmd aptly
require_cmd install
require_cmd find

[[ -n "$REPO_NAME" ]] || die "REPO_NAME is required (e.g. export REPO_NAME=my-repo)"
[[ -n "$DEP11_SOURCE_DIR" ]] || die "DEP11_SOURCE_DIR is required (directory with pre-generated DEP-11 files)"
[[ -d "$DEP11_SOURCE_DIR" ]] || die "DEP11_SOURCE_DIR does not exist: $DEP11_SOURCE_DIR"
[[ -d "$PUBLIC_DIR" ]] || die "PUBLIC_DIR does not exist: $PUBLIC_DIR"

# Require at least one Components file and one icons archive to avoid broken updates.
mapfile -t components_files < <(find "$DEP11_SOURCE_DIR" -maxdepth 1 -type f -name 'Components-*.yml.gz' | sort)
mapfile -t icons_files < <(find "$DEP11_SOURCE_DIR" -maxdepth 1 -type f -name 'icons-*.tar.gz' | sort)

(( ${#components_files[@]} > 0 )) || die "No Components-*.yml.gz files found in $DEP11_SOURCE_DIR"
(( ${#icons_files[@]} > 0 )) || die "No icons-*.tar.gz files found in $DEP11_SOURCE_DIR"

TARGET_DEP11_DIR="$PUBLIC_DIR/dists/$SUITE/$COMPONENT/dep11"

log "Repository: $REPO_NAME"
log "Suite/component: $SUITE/$COMPONENT"
log "Publish endpoint: $PUBLISH_ENDPOINT"
log "Public dir: $PUBLIC_DIR"
log "DEP-11 source: $DEP11_SOURCE_DIR"
log "Target dep11 dir: $TARGET_DEP11_DIR"

# -----------------------------
# 1) Publish repository (optional if already published)
# -----------------------------
if [[ "$RUN_INITIAL_PUBLISH" == "true" ]]; then
  log "Running initial aptly publish step"
  run aptly publish repo "$REPO_NAME" "$PUBLISH_ENDPOINT"
else
  log "Skipping initial publish because RUN_INITIAL_PUBLISH=$RUN_INITIAL_PUBLISH"
fi

# -----------------------------
# 2) Copy DEP-11 metadata into published tree
# -----------------------------
log "Copying DEP-11 files into published repository"
run install -d -m 0755 "$TARGET_DEP11_DIR"

# Copy only known DEP-11 artifacts and preserve deterministic permissions.
for src in "${components_files[@]}" "${icons_files[@]}"; do
  dest="$TARGET_DEP11_DIR/$(basename "$src")"
  run install -m 0644 "$src" "$dest"
done

# -----------------------------
# 3) Regenerate Release/InRelease with DEP-11 checksums
# -----------------------------
log "Running aptly publish update to refresh Release/InRelease checksums"
run aptly publish update "$SUITE" "$PUBLISH_ENDPOINT"

log "DEP-11 integration completed successfully"
