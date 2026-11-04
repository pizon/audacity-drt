#!/usr/bin/env bash
# Run the installed Audacity binary inside the build container.
# Useful when host Qt packages are incomplete. Forwards DISPLAY for GUI use.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_image
require_src

INSTALL_ROOT="/src/${INSTALL_DIR_NAME}"
BIN="${INSTALL_ROOT}/bin/audacity"
HOST_BIN="${SRC_DIR}/${INSTALL_DIR_NAME}/bin/audacity"
[[ -x "${HOST_BIN}" ]] || die "binary not found: ${HOST_BIN} (run ./configure-build.sh first)"

# Ensure lib -> lib64 exists for RUNPATH.
if [[ -d "${SRC_DIR}/${INSTALL_DIR_NAME}/lib64" && ! -e "${SRC_DIR}/${INSTALL_DIR_NAME}/lib" ]]; then
  ln -sfn lib64 "${SRC_DIR}/${INSTALL_DIR_NAME}/lib"
fi

extra_args=()
if [[ -n "${DISPLAY:-}" ]]; then
  extra_args+=(-e "DISPLAY=${DISPLAY}")
  if [[ -d /tmp/.X11-unix ]]; then
    extra_args+=(-v /tmp/.X11-unix:/tmp/.X11-unix:rw)
  fi
  # Allow container to talk to host X if xhost is available.
  if command -v xhost >/dev/null 2>&1; then
    xhost +local: >/dev/null 2>&1 || true
  fi
fi
if [[ -n "${XAUTHORITY:-}" && -f "${XAUTHORITY}" ]]; then
  extra_args+=(-e "XAUTHORITY=${XAUTHORITY}" -v "${XAUTHORITY}:${XAUTHORITY}:ro")
fi
if [[ -n "${WAYLAND_DISPLAY:-}" && -n "${XDG_RUNTIME_DIR:-}" ]]; then
  extra_args+=(-e "WAYLAND_DISPLAY=${WAYLAND_DISPLAY}" -e "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}")
  extra_args+=(-v "${XDG_RUNTIME_DIR}:${XDG_RUNTIME_DIR}")
fi

# Quote remaining args for remote shell.
remote_args=
for a in "$@"; do
  remote_args+=$(printf ' %q' "$a")
done

podman_run_base "${extra_args[@]}" "${IMAGE_NAME}" \
  /bin/bash -lc "exec ${BIN}${remote_args}"
