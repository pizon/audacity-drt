#!/usr/bin/env bash
# Open an interactive shell in the Audacity 4 Fedora 44 build container.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_image
require_src

echo "Source: ${SRC_DIR}  ->  /src"
echo "Image:  ${IMAGE_NAME}"
echo "Install tree: ${INSTALL_DIR_NAME}/  (binary: ${INSTALL_DIR_NAME}/bin/audacity)"
echo "Build tip: ${SCRIPT_DIR}/configure-build.sh"
echo

podman_run_base -it "${IMAGE_NAME}" /bin/bash
