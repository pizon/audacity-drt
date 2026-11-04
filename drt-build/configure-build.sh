#!/usr/bin/env bash
# Configure, build, and install Audacity 4 inside the Podman Fedora 44 environment.
#
# Usage:
#   ./configure-build.sh              # configure + build + install to ./build
#   ./configure-build.sh --configure  # configure only
#   ./configure-build.sh --build      # build only
#   ./configure-build.sh --install    # install only (into INSTALL_DIR_NAME)
#   ./configure-build.sh --test       # also run trackedit unit tests
#
# After a successful install, the runnable binary is:
#   ${SRC_DIR}/${INSTALL_DIR_NAME}/bin/audacity
# (default: ../build/bin/audacity — fork root)
#
# Env overrides:
#   SRC_DIR, IMAGE_NAME, BUILD_DIR_NAME, INSTALL_DIR_NAME, CMAKE_BUILD_TYPE
#   EXTRA_CMAKE_ARGS  — extra args passed to cmake configure
#   JOBS
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

DO_CONFIGURE=1
DO_BUILD=1
DO_INSTALL=1
DO_TEST=0
JOBS=${JOBS:-$(nproc)}
CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE:-RelWithDebInfo}
EXTRA_CMAKE_ARGS=${EXTRA_CMAKE_ARGS:-}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --configure) DO_CONFIGURE=1; DO_BUILD=0; DO_INSTALL=0; DO_TEST=0 ;;
    --build)     DO_CONFIGURE=0; DO_BUILD=1; DO_INSTALL=0; DO_TEST=0 ;;
    --install)   DO_CONFIGURE=0; DO_BUILD=0; DO_INSTALL=1; DO_TEST=0 ;;
    --test)      DO_TEST=1 ;;
    -j|--jobs)   JOBS="$2"; shift ;;
    -h|--help)
      sed -n '2,18p' "$0"
      exit 0
      ;;
    *) die "unknown argument: $1" ;;
  esac
  shift
done

require_image
require_src

BUILD_DIR="/src/${BUILD_DIR_NAME}"
INSTALL_DIR="/src/${INSTALL_DIR_NAME}"
HOST_BIN="${SRC_DIR}/${INSTALL_DIR_NAME}/bin/audacity"

remote_script=$(cat <<EOF
set -euo pipefail
export PATH="/usr/lib64/ccache:\${PATH}"
echo "compiler: \$(c++ --version | head -1)"
echo "cmake:    \$(cmake --version | head -1)"
echo "qt:       \$(rpm -q qt6-qtbase)"

if [[ "${DO_CONFIGURE}" == "1" ]]; then
  echo "==> Configuring (${CMAKE_BUILD_TYPE})"
  echo "    build tree:   ${BUILD_DIR_NAME}/"
  echo "    install tree: ${INSTALL_DIR_NAME}/"
  cmake -S /src -B "${BUILD_DIR}" -GNinja \\
    -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} \\
    -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \\
    -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \\
    -DCMAKE_C_COMPILER_LAUNCHER=ccache \\
    -DMUSE_ENABLE_UNIT_TESTS=ON \\
    ${EXTRA_CMAKE_ARGS}
fi

if [[ "${DO_BUILD}" == "1" ]]; then
  echo "==> Building (-j${JOBS})"
  cmake --build "${BUILD_DIR}" -j "${JOBS}"
fi

if [[ "${DO_TEST}" == "1" ]]; then
  echo "==> Running trackedit_tests"
  ctest --test-dir "${BUILD_DIR}" -R 'trackedit_tests' --output-on-failure
fi

if [[ "${DO_INSTALL}" == "1" ]]; then
  echo "==> Installing to ${INSTALL_DIR_NAME}/"
  rm -rf "${INSTALL_DIR}"
  cmake --install "${BUILD_DIR}" --prefix "${INSTALL_DIR}"
  # Fedora uses lib64; the binary RUNPATH expects \$ORIGIN/../lib.
  if [[ -d "${INSTALL_DIR}/lib64" && ! -e "${INSTALL_DIR}/lib" ]]; then
    ln -sfn lib64 "${INSTALL_DIR}/lib"
  fi
  echo
  echo "Installed binary: ${INSTALL_DIR}/bin/audacity"
  echo "On the host:      ${HOST_BIN}"
  echo "Run with:         ${SCRIPT_DIR}/run.sh"
fi

echo "Done."
EOF
)

podman_run_base "${IMAGE_NAME}" /bin/bash -lc "${remote_script}"
