#!/usr/bin/env bash
# Run the installed Audacity binary from the host install tree.
#
# Default path: ${SRC_DIR}/${INSTALL_DIR_NAME}/bin/audacity
# (../build/bin/audacity — fork root)
#
# Requires host Qt 6.11 packages matching the build (at least
# qt6-qtbase, qt6-qtdeclarative, qt6-qt5compat, and related modules).
# If those are missing, use ./run-podman.sh instead.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

INSTALL_ROOT="${SRC_DIR}/${INSTALL_DIR_NAME}"
BIN="${INSTALL_ROOT}/bin/audacity"
[[ -x "${BIN}" ]] || die "binary not found: ${BIN} (run ./configure-build.sh first)"

# Keep Fedora's lib64 layout working with the binary's \$ORIGIN/../lib RUNPATH.
if [[ -d "${INSTALL_ROOT}/lib64" && ! -e "${INSTALL_ROOT}/lib" ]]; then
  ln -sfn lib64 "${INSTALL_ROOT}/lib"
fi

LIB_DIRS=()
[[ -d "${INSTALL_ROOT}/lib64" ]] && LIB_DIRS+=("${INSTALL_ROOT}/lib64")
[[ -d "${INSTALL_ROOT}/lib" ]] && LIB_DIRS+=("${INSTALL_ROOT}/lib")
[[ -d "${INSTALL_ROOT}/bin" ]] && LIB_DIRS+=("${INSTALL_ROOT}/bin")

export LD_LIBRARY_PATH="$(IFS=:; echo "${LIB_DIRS[*]}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}")"

exec "${BIN}" "$@"
