#!/usr/bin/env bash
#
# Resolve the latest patch release of every versioned dependency used by the
# Dockerfiles, and print `export KEY=VALUE` lines on stdout.
#
# Usage (CircleCI):
#   bash .circleci/resolve-versions.sh >> "$BASH_ENV"
#
# Only the patch component is resolved automatically. The minor versions below
# are pinned on purpose: bump them here when moving to a new minor release.
#
#   RUBY_MINOR    -> Dockerfile ARG RUBY_VERSION
#   NODE_MAJOR    -> Dockerfile / streaming/Dockerfile ARG NODE_MAJOR_VERSION
#   VIPS_MINOR    -> Dockerfile ARG VIPS_VERSION
#   FFMPEG_MINOR  -> Dockerfile ARG FFMPEG_VERSION
#   DEBIAN_VERSION -> Dockerfile / streaming/Dockerfile ARG DEBIAN_VERSION

set -euo pipefail

RUBY_MINOR="${RUBY_MINOR:-4.0}"
NODE_MAJOR="${NODE_MAJOR:-24}"
DEBIAN_VERSION="${DEBIAN_VERSION:-trixie}"
VIPS_MINOR="${VIPS_MINOR:-8.18}"
FFMPEG_MINOR="${FFMPEG_MINOR:-9.0}"

log() { printf '%s\n' "$*" >&2; }

# List tag names of an official Docker Hub image matching a name filter.
# Docker Hub answers 404 once the requested page is past the last one, so a
# failed request simply ends the pagination.
docker_hub_tags() {
  local repo="$1" filter="$2" page=1 body tags
  while [ "$page" -le 10 ]; do
    if ! body="$(curl -fsSL --retry 3 --retry-delay 2 --retry-all-errors \
      "https://hub.docker.com/v2/repositories/library/${repo}/tags?page_size=100&page=${page}&name=${filter}" \
      2>/dev/null)"; then
      break
    fi
    tags="$(printf '%s' "$body" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 || true)"
    [ -z "$tags" ] && break
    printf '%s\n' "$tags"
    page=$((page + 1))
  done
}

# List tag names of a GitHub repository matching a ref pattern.
github_tags() {
  git ls-remote --tags --refs "$1" "$2" | sed 's#.*refs/tags/##'
}

# Pick the highest version from stdin using version-aware sorting.
latest_patch() {
  sort -V | tail -n 1
}

# Emit an export line. When resolution failed (network hiccup, API change, ...)
# fall back to the value pinned in the Dockerfile so the build still runs.
resolve() {
  local name="$1" value="$2" fallback="$3"
  if [ -z "$value" ]; then
    log "WARNING: could not resolve the latest ${name}, falling back to ${fallback}"
    value="$fallback"
  else
    log "Resolved ${name}=${value}"
  fi
  printf 'export %s=%s\n' "$name" "$value"
}

ruby_version="$(
  { docker_hub_tags ruby "${RUBY_MINOR}." || true; } \
    | grep -E "^${RUBY_MINOR//./\\.}\.[0-9]+-slim-${DEBIAN_VERSION}$" \
    | sed -E "s/-slim-${DEBIAN_VERSION}$//" \
    | latest_patch || true
)"

node_version="$(
  { docker_hub_tags node "${NODE_MAJOR}." || true; } \
    | grep -E "^${NODE_MAJOR}\.[0-9]+\.[0-9]+-${DEBIAN_VERSION}-slim$" \
    | sed -E "s/-${DEBIAN_VERSION}-slim$//" \
    | latest_patch || true
)"

vips_version="$(
  { github_tags https://github.com/libvips/libvips.git "v${VIPS_MINOR}.*" || true; } \
    | sed 's/^v//' \
    | grep -E "^${VIPS_MINOR//./\\.}\.[0-9]+$" \
    | latest_patch || true
)"

ffmpeg_version="$(
  { github_tags https://github.com/FFmpeg/FFmpeg.git "n${FFMPEG_MINOR}.*" || true; } \
    | sed 's/^n//' \
    | grep -E "^${FFMPEG_MINOR//./\\.}\.[0-9]+$" \
    | latest_patch || true
)"

# Fallbacks mirror the ARG defaults in the Dockerfiles.
resolve RUBY_VERSION "$ruby_version" "4.0.6"
resolve NODE_MAJOR_VERSION "$node_version" "24"
resolve VIPS_VERSION "$vips_version" "8.18.5"
resolve FFMPEG_VERSION "$ffmpeg_version" "9.0.2"
printf 'export DEBIAN_VERSION=%s\n' "$DEBIAN_VERSION"
