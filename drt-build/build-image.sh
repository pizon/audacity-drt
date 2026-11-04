#!/usr/bin/env bash
# Build the Fedora 44 DRT Audacity build-environment image with Podman.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
IMAGE_NAME=${IMAGE_NAME:-localhost/audacity-drt-build:fedora44}

cd "$SCRIPT_DIR"
echo "Building ${IMAGE_NAME} from ${SCRIPT_DIR}/Containerfile ..."
podman build \
  --tag "${IMAGE_NAME}" \
  --file Containerfile \
  .

echo
echo "Image ready: ${IMAGE_NAME}"
echo "Next:  ./shell.sh              # interactive shell with this fork mounted"
echo "       ./configure-build.sh    # cmake configure + build + install to ../build"
echo "       ./package-appimage.sh   # portable AppImage → ../dist/"
