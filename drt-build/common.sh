#!/usr/bin/env bash
# Shared helpers for Podman DRT build scripts.
# shellcheck disable=SC2034

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# Fork root (parent of drt-build/). Build tooling lives inside the fork but
# stays out of Audacity's own src/ layout.
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
DEFAULT_SRC="${REPO_ROOT}"
IMAGE_NAME=${IMAGE_NAME:-localhost/audacity-drt-build:fedora44}
SRC_DIR=${SRC_DIR:-${DEFAULT_SRC}}
# CMake object/intermediate tree (can be large).
BUILD_DIR_NAME=${BUILD_DIR_NAME:-build-podman}
# Install/run tree on the host (binaries + shared libs for local testing).
INSTALL_DIR_NAME=${INSTALL_DIR_NAME:-build}
CCACHE_DIR_HOST=${CCACHE_DIR_HOST:-${HOME}/.ccache}

die() {
  echo "error: $*" >&2
  exit 1
}

require_image() {
  if ! podman image exists "${IMAGE_NAME}"; then
    die "image '${IMAGE_NAME}' not found. Run: ${SCRIPT_DIR}/build-image.sh"
  fi
}

require_src() {
  [[ -d "${SRC_DIR}" ]] || die "source directory not found: ${SRC_DIR}"
  [[ -f "${SRC_DIR}/CMakeLists.txt" ]] || die "not an Audacity source tree: ${SRC_DIR}"
  if [[ ! -f "${SRC_DIR}/muse/CMakeLists.txt" ]]; then
    cat >&2 <<EOF
error: muse submodule is missing under ${SRC_DIR}/muse
Initialize with:
  git -C '${SRC_DIR}' submodule update --init --recursive
EOF
    exit 1
  fi
}

# Common podman run flags: keep host UID, mount source + ccache.
podman_run_base() {
  local -a args=(
    --rm
    --userns=keep-id
    --security-opt label=disable
    -v "${SRC_DIR}:/src:Z"
    -w /src
    -e CCACHE_DIR=/ccache
  )

  mkdir -p "${CCACHE_DIR_HOST}"
  args+=(-v "${CCACHE_DIR_HOST}:/ccache:Z")

  # Forward useful overrides if set on the host.
  [[ -n "${CMAKE_BUILD_TYPE:-}" ]] && args+=(-e "CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}")
  [[ -n "${CMAKE_PREFIX_PATH:-}" ]] && args+=(-e "CMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH}")

  podman run "${args[@]}" "$@"
}
