#!/usr/bin/env bash
# Build a portable Audacity 4 AppImage using the Fedora 44 Podman image.
#
# Usage:
#   ./package-appimage.sh              # configure + build + package
#   ./package-appimage.sh --configure  # configure portable build only
#   ./package-appimage.sh --build      # build + install AppDir only
#   ./package-appimage.sh --package    # package existing AppDir into AppImage
#
# Output (host):
#   ${SRC_DIR}/dist/<artifact>.AppImage
#
# Env overrides:
#   SRC_DIR, IMAGE_NAME, JOBS, CMAKE_BUILD_TYPE, EXTRA_CMAKE_ARGS
#   APPIMAGE_BUILD_DIR_NAME   (default: build-appimage)
#   APPIMAGE_INSTALL_NAME     (default: Audacity.AppDir under dist/)
#   APPIMAGE_NAME             (default: audacity-linux-4.0.2-drt-N.AppImage)
#   APPIMAGE_SOURCE_VERSION   (default: 4.0.2 — source tree tag, not version.cmake)
#   APPIMAGE_BUILD_TAG        (default: drt — local identifier)
#   APPIMAGE_BUILD_NUMBER     (default: read/increment drt-build/.appimage-build-number)
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

DO_CONFIGURE=1
DO_BUILD=1
DO_PACKAGE=1
JOBS=${JOBS:-$(nproc)}
CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE:-RelWithDebInfo}
EXTRA_CMAKE_ARGS=${EXTRA_CMAKE_ARGS:-}
APPIMAGE_BUILD_DIR_NAME=${APPIMAGE_BUILD_DIR_NAME:-build-appimage}
APPIMAGE_INSTALL_NAME=${APPIMAGE_INSTALL_NAME:-Audacity.AppDir}
DIST_DIR_NAME=${DIST_DIR_NAME:-dist}
PACKARCH=${PACKARCH:-$(uname -m)}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --configure) DO_CONFIGURE=1; DO_BUILD=0; DO_PACKAGE=0 ;;
    --build)     DO_CONFIGURE=0; DO_BUILD=1; DO_PACKAGE=0 ;;
    --package)   DO_CONFIGURE=0; DO_BUILD=0; DO_PACKAGE=1 ;;
    -j|--jobs)   JOBS="$2"; shift ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *) die "unknown argument: $1" ;;
  esac
  shift
done

require_image
require_src

# Artifact name: audacity-linux-<source>-<tag>-<N>.AppImage
# Example: audacity-linux-4.0.2-drt-2.AppImage
APPIMAGE_SOURCE_VERSION=${APPIMAGE_SOURCE_VERSION:-4.0.2}
APPIMAGE_BUILD_TAG=${APPIMAGE_BUILD_TAG:-drt}
BUILD_NUMBER_FILE=${BUILD_NUMBER_FILE:-"${SCRIPT_DIR}/.appimage-build-number"}

if [[ -z "${APPIMAGE_BUILD_NUMBER:-}" ]]; then
  if [[ -f "${BUILD_NUMBER_FILE}" ]]; then
    APPIMAGE_BUILD_NUMBER=$(tr -d '[:space:]' < "${BUILD_NUMBER_FILE}")
  else
    APPIMAGE_BUILD_NUMBER=2
  fi
fi
if ! [[ "${APPIMAGE_BUILD_NUMBER}" =~ ^[0-9]+$ ]]; then
  die "APPIMAGE_BUILD_NUMBER must be an integer (got: ${APPIMAGE_BUILD_NUMBER})"
fi

if [[ -z "${APPIMAGE_NAME:-}" ]]; then
  APPIMAGE_NAME="audacity-linux-${APPIMAGE_SOURCE_VERSION}-${APPIMAGE_BUILD_TAG}-${APPIMAGE_BUILD_NUMBER}.AppImage"
fi

BUILD_DIR="/src/${APPIMAGE_BUILD_DIR_NAME}"
DIST_DIR="/src/${DIST_DIR_NAME}"
INSTALL_DIR="${DIST_DIR}/${APPIMAGE_INSTALL_NAME}"
HOST_DIST="${SRC_DIR}/${DIST_DIR_NAME}"
HOST_APPIMAGE="${HOST_DIST}/${APPIMAGE_NAME}"

remote_script=$(cat <<EOF
set -euo pipefail
export PATH="/usr/lib64/ccache:\${PATH}"

BUILD_DIR="${BUILD_DIR}"
DIST_DIR="${DIST_DIR}"
INSTALL_DIR="${INSTALL_DIR}"
APPIMAGE_NAME="${APPIMAGE_NAME}"
PACKARCH="${PACKARCH}"
JOBS="${JOBS}"
CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE}"

echo "compiler: \$(c++ --version | head -1)"
echo "cmake:    \$(cmake --version | head -1)"
echo "qt:       \$(rpm -q qt6-qtbase)"
echo "artifact: \${APPIMAGE_NAME}"

if [[ "${DO_CONFIGURE}" == "1" ]]; then
  echo "==> Configuring portable AppImage build"
  cmake -S /src -B "\${BUILD_DIR}" -GNinja \\
    -DCMAKE_BUILD_TYPE=\${CMAKE_BUILD_TYPE} \\
    -DCMAKE_INSTALL_PREFIX="\${INSTALL_DIR}" \\
    -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \\
    -DCMAKE_C_COMPILER_LAUNCHER=ccache \\
    -DAU4_BUILD_CONFIGURATION=app-portable \\
    -DAU4_BUILD_MODE=dev \\
    -DMUSE_APP_INSTALL_SUFFIX=4portable \\
    -DCMAKE_SKIP_RPATH=ON \\
    -DMUSE_ENABLE_UNIT_TESTS=OFF \\
    ${EXTRA_CMAKE_ARGS}
fi

if [[ "${DO_BUILD}" == "1" ]]; then
  echo "==> Building portable AppDir (-j\${JOBS})"
  cmake --build "\${BUILD_DIR}" -j "\${JOBS}"

  echo "==> Installing into \${INSTALL_DIR}"
  rm -rf "\${INSTALL_DIR}"
  mkdir -p "\${DIST_DIR}"
  cmake --install "\${BUILD_DIR}" --prefix "\${INSTALL_DIR}" --strip

  # Match CI portable post-install steps from ci_build.cmake (APPIMAGE).
  ln -sfn . "\${INSTALL_DIR}/usr"

  if [[ -f "\${BUILD_DIR}/install_manifest.txt" ]]; then
    python3 - "\${BUILD_DIR}/install_manifest.txt" "\${INSTALL_DIR}" <<'PY'
from pathlib import Path
import re
import sys
manifest = Path(sys.argv[1])
install_dir = Path(sys.argv[2])
keep = []
for line in manifest.read_text().splitlines():
    m = re.search(r"/(share/(applications|icons|man|metainfo|mime)/.*)$", line)
    if m:
        keep.append(m.group(1))
text = "\n".join(keep)
if text:
    text += "\n"
install_dir.joinpath("install_manifest.txt").write_text(text)
PY
  fi

  desktop_src=\$(ls "\${BUILD_DIR}"/org.audacityteam.Audacity*.desktop 2>/dev/null | head -1 || true)
  if [[ -n "\${desktop_src}" ]]; then
    cp -f "\${desktop_src}" "\${INSTALL_DIR}/"
  fi
  if [[ -f /src/buildscripts/packaging/Linux+BSD/aup4.svg ]]; then
    cp -f /src/buildscripts/packaging/Linux+BSD/aup4.svg "\${INSTALL_DIR}/"
  fi

  # PREFIX.txt is written at configure-time; refresh it to the real AppDir.
  echo "\${INSTALL_DIR}" > "\${BUILD_DIR}/PREFIX.txt"
fi

if [[ "${DO_PACKAGE}" == "1" ]]; then
  [[ -d "\${INSTALL_DIR}" ]] || { echo "error: AppDir missing: \${INSTALL_DIR}"; exit 1; }
  [[ -x "\${INSTALL_DIR}/AppRun" || -x "\${INSTALL_DIR}/bin/audacity4portable" ]] || {
    echo "error: AppDir does not look complete: \${INSTALL_DIR}"
    ls -la "\${INSTALL_DIR}"
    exit 1
  }

  echo "==> Fetching AppImage tools"
  cmake \\
    -DSRC_ROOT=/src \\
    -DTOOLS_ROOT="\${BUILD_DIR}/_appimage_tools" \\
    -DENV_OUT="\${BUILD_DIR}/appimage-tools-env.sh" \\
    -P /build-env/cmake/fetch_appimage_tools.cmake

  # Writable Qt root overlay so make_appimage.sh can move SQL plugins and
  # copy extra Qt components. Fedora often ships only the SQLite driver.
  QT_ROOT_DIR=/tmp/qt6-appimage-root
  rm -rf "\${QT_ROOT_DIR}"
  mkdir -p "\${QT_ROOT_DIR}"
  cp -a /usr/lib64/qt6/plugins "\${QT_ROOT_DIR}/plugins"
  if [[ -d /usr/lib64/qt6/qml ]]; then
    ln -sfn /usr/lib64/qt6/qml "\${QT_ROOT_DIR}/qml"
  fi
  mkdir -p "\${QT_ROOT_DIR}/plugins/sqldrivers"
  for stub in libqsqlmysql.so libqsqlpsql.so; do
    if [[ ! -e "\${QT_ROOT_DIR}/plugins/sqldrivers/\${stub}" ]]; then
      # Empty placeholder so make_appimage.sh's unconditional mv succeeds.
      : > "\${QT_ROOT_DIR}/plugins/sqldrivers/\${stub}"
    fi
  done

  QMAKE_PATH=\$(command -v qmake6 || true)
  [[ -n "\${QMAKE_PATH}" ]] || { echo "error: qmake6 not found in image"; exit 1; }

  # shellcheck disable=SC1090
  source "\${BUILD_DIR}/appimage-tools-env.sh"
  export QT_ROOT_DIR="\${QT_ROOT_DIR}"
  export QMAKE="\${QMAKE_PATH}"
  export APPIMAGE_EXTRACT_AND_RUN=1
  export PATH="\$(dirname "\${QMAKE_PATH}"):\$PATH"

  # make_appimage.sh bootstraps tools into \$HOME/build_tools by copying from
  # PATH and extracting AppImages. Pre-seed that layout from muse_deps tools so
  # its install_appimage_tool step is a no-op / reliable inside Podman.
  export HOME="\${BUILD_DIR}/home"
  BUILD_TOOLS="\${HOME}/build_tools"
  mkdir -p "\${BUILD_TOOLS}"

  seed_tool() {
    # Usage: seed_tool <binary-name> <dest-dir>
    # linuxdeploy discovers linuxdeploy-plugin-qt in the same directory.
    # NOTE: This function body lives inside an unquoted host heredoc, so every
    # \$ must be escaped and "$@" must be written as "\$@" or the host shell
    # expands it while constructing the remote script.
    local name="\$1"
    local dest="\$2"
    local src
    src=\$(command -v "\${name}") || { echo "error: \${name} not on PATH"; exit 1; }
    mkdir -p "\${dest}"
    # Always rewrite the wrapper; a previous host-heredoc bug baked in a
    # literal empty argument ("") which breaks CLI parsing.
    if [[ ! -d "\${dest}/\${name}.AppDir" ]]; then
      echo "    seeding \${name} into \${dest}"
      (
        cd "\${dest}"
        cp "\${src}" "./\${name}-\${PACKARCH}.AppImage"
        chmod +x "./\${name}-\${PACKARCH}.AppImage"
        "./\${name}-\${PACKARCH}.AppImage" --appimage-extract >/dev/null
        mv squashfs-root "\${name}.AppDir"
        rm -f "./\${name}-\${PACKARCH}.AppImage"
      )
    else
      echo "    refreshing \${name} wrapper in \${dest}"
    fi
    printf '#!/bin/sh\nexec "%s/AppRun" "\$@"\n' "\$(readlink -f "\${dest}/\${name}.AppDir")" > "\${dest}/\${name}"
    chmod +x "\${dest}/\${name}"
  }

  seed_tool appimagetool "\${BUILD_TOOLS}/appimagetool"
  seed_tool linuxdeploy "\${BUILD_TOOLS}/linuxdeploy"
  seed_tool linuxdeploy-plugin-qt "\${BUILD_TOOLS}/linuxdeploy"
  # make_appimage.sh installs appimageupdatetool whenever this directory is
  # missing; create it empty so that step is skipped (updates disabled).
  mkdir -p "\${BUILD_TOOLS}/appimageupdatetool"

  # linuxdeploy ships patchelf 0.15 which corrupts Fedora ELF RELR binaries
  # (dlopen SIGSEGV in constructors). Replace with the image's patchelf 0.18+.
  SYSTEM_PATCHELF=\$(command -v patchelf || true)
  if [[ -z "\${SYSTEM_PATCHELF}" ]]; then
    echo "error: system patchelf not found (need >= 0.18 for RELR)"
    exit 1
  fi
  echo "    replacing bundled patchelf with \${SYSTEM_PATCHELF} (\$("\${SYSTEM_PATCHELF}" --version))"
  while IFS= read -r -d '' bundled; do
    cp -f "\${SYSTEM_PATCHELF}" "\${bundled}"
    chmod +x "\${bundled}"
  done < <(find "\${BUILD_TOOLS}" -type f -name patchelf -print0)

  export PATH="\${BUILD_TOOLS}/appimagetool:\${BUILD_TOOLS}/linuxdeploy:\$PATH"

  ENV_FILE=/tmp/audacity-appimage-environment.sh
  cat > "\${ENV_FILE}" <<ENV
export PATH="/usr/bin:\${BUILD_TOOLS}/appimagetool:\${BUILD_TOOLS}/linuxdeploy:\$(dirname "\${QMAKE_PATH}"):\$PATH"
export QT_ROOT_DIR="\${QT_ROOT_DIR}"
export QMAKE="\${QMAKE_PATH}"
export APPIMAGE_EXTRACT_AND_RUN=1
export NO_STRIP=1
ENV

  # Fedora installs to lib64; make_appimage.sh / linuxdeploy expect lib/.
  if [[ -d "\${INSTALL_DIR}/lib64" && ! -e "\${INSTALL_DIR}/lib" ]]; then
    ln -sfn lib64 "\${INSTALL_DIR}/lib"
  fi

  # appimagetool requires the desktop Icon= name at AppDir root.
  icon_src=\$(find "\${INSTALL_DIR}/share/icons" -type f -name 'audacity4portable.png' 2>/dev/null | sort | tail -1 || true)
  if [[ -n "\${icon_src}" ]]; then
    cp -f "\${icon_src}" "\${INSTALL_DIR}/audacity4portable.png"
  elif [[ -f "\${INSTALL_DIR}/aup4.svg" ]]; then
    cp -f "\${INSTALL_DIR}/aup4.svg" "\${INSTALL_DIR}/audacity4portable.svg"
  fi

  # Bundled linuxdeploy strip is too old for Fedora's RELR ELF sections.
  export NO_STRIP=1
  # Prefer the image's strip (binutils 2.4x) over whatever is on PATH first.
  export PATH="/usr/bin:\${PATH}"

  # Debian/Ubuntu keep NSS helpers under lib/nss/; Fedora keeps them flat in
  # lib64/. Stage a local nss/ tree and point the copy at it via a patched
  # make_appimage.sh (upstream cp is hard-coded to the Debian layout).
  NSS_STAGE=/tmp/au4-nss-stage
  rm -rf "\${NSS_STAGE}"
  mkdir -p "\${NSS_STAGE}/nss"
  for lib in libnss3.so libnssutil3.so libsmime3.so libssl3.so; do
    src=\$(find /usr/lib64 /lib64 -maxdepth 1 -name "\${lib}" 2>/dev/null | head -1 || true)
    [[ -n "\${src}" ]] && cp -L "\${src}" "\${NSS_STAGE}/"
  done
  for lib in libfreebl3.chk libfreebl3.so libfreeblpriv3.chk libfreeblpriv3.so \\
             libnssckbi.so libnssdbm3.chk libnssdbm3.so libsoftokn3.chk libsoftokn3.so; do
    src=\$(find /usr/lib64 /lib64 -name "\${lib}" 2>/dev/null | head -1 || true)
    [[ -n "\${src}" ]] && cp -L "\${src}" "\${NSS_STAGE}/nss/"
  done

  MAKE_APPIMAGE=/tmp/make_appimage.sh
  cp -f /src/buildscripts/ci/linux/make_appimage.sh "\${MAKE_APPIMAGE}"
  # Prefer staged NSS tree when present; never abort the bundle on a missing helper.
  # Use python to avoid sed delimiter clashes with || and paths.
  # All \${...} escapes are for the host unquoted heredoc that embeds this script.
  python3 - "\${MAKE_APPIMAGE}" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text()
old_cp = 'cp -L "\${libnss3_system_path}/\${file}" "\${libnss3_appdir_path}/\${file}"'
new_cp = (
    'cp -L "\${libnss3_system_path}/\${file}" "\${libnss3_appdir_path}/\${file}" 2>/dev/null '
    '|| cp -L "/tmp/au4-nss-stage/\${file}" "\${libnss3_appdir_path}/\${file}" 2>/dev/null '
    '|| echo "warning: missing NSS file: \${file}"'
)
if old_cp not in text:
    raise SystemExit("error: expected NSS cp line not found in make_appimage.sh")
text = text.replace(old_cp, new_cp, 1)
old_ai = 'appimagetool "\${appimagetool_args[@]}" "\${appdir}" "\${appimage}"'
new_ai = old_ai + " || exit 1"
if old_ai not in text:
    raise SystemExit("error: expected appimagetool line not found in make_appimage.sh")
text = text.replace(old_ai, new_ai, 1)
# Fedora's ELF RELR sections are mishandled by a blanket strip pass: libraries
# that "strip" successfully then SIGSEGV in their constructors at load time.
# Skip stripping entirely; NO_STRIP=1 already covers linuxdeploy.
old_strip_loop = '''while IFS= read -r -d '' file_path; do
  if file -b "\${file_path}" | grep -q '^ELF '; then
    strip --strip-unneeded "\${file_path}"
  fi
done < <(find "\${appdir}" -type f -print0)'''
new_strip_loop = '''echo "Skipping AppDir strip (Fedora RELR / binutils incompat)"'''
if old_strip_loop not in text:
    raise SystemExit("error: expected strip loop not found in make_appimage.sh")
text = text.replace(old_strip_loop, new_strip_loop, 1)
# AppDir on LD_LIBRARY_PATH breaks system qmake/coreutils once bundled libs
# are present (Fedora). Limit it to the initial linuxdeploy pass only.
old_ld = '''export LD_LIBRARY_PATH=\${appdir}/lib:\$LD_LIBRARY_PATH
linuxdeploy --appdir "\${appdir}" # adds all shared library dependencies
echo "end linuxdeploy: \$?"
linuxdeploy-plugin-qt --appdir "\${appdir}" # adds all Qt dependencies
echo "end linuxdeploy-plugin-qt: \$?"'''
new_ld = '''export LD_LIBRARY_PATH=\${appdir}/lib:\$LD_LIBRARY_PATH
linuxdeploy --appdir "\${appdir}" # adds all shared library dependencies
echo "end linuxdeploy: \$?"
# Drop AppDir from LD_LIBRARY_PATH so qmake and later coreutils keep working.
export LD_LIBRARY_PATH="\$(printf '%s' "\$LD_LIBRARY_PATH" | tr ':' '\\n' | grep -vF "\${appdir}" | paste -sd:)"
linuxdeploy-plugin-qt --appdir "\${appdir}" # adds all Qt dependencies
_qt_rc=\$?
echo "end linuxdeploy-plugin-qt: \$_qt_rc"
if [[ "\$_qt_rc" -ne 0 ]]; then
  echo "error: linuxdeploy-plugin-qt failed"
  exit "\$_qt_rc"
fi'''
if old_ld not in text:
    raise SystemExit("error: expected linuxdeploy LD_LIBRARY_PATH block not found")
text = text.replace(old_ld, new_ld, 1)
path.write_text(text)
PY

  echo "==> Bundling AppImage"
  echo "    QMAKE=\${QMAKE_PATH}"
  echo "    appimagetool=\$(command -v appimagetool)"
  echo "    linuxdeploy=\$(command -v linuxdeploy)"
  # Verify wrappers forward args (guards against host-heredoc "\$@" bugs).
  if grep -q 'AppRun" ""$' "\${BUILD_TOOLS}/appimagetool/appimagetool" \\
       "\${BUILD_TOOLS}/linuxdeploy/linuxdeploy" 2>/dev/null; then
    echo "error: AppImage tool wrappers still contain a baked-in empty argument"
    exit 1
  fi
  # make_appimage.sh creates the artifact as a sibling of the AppDir.
  bash "\${MAKE_APPIMAGE}" \\
    "\${INSTALL_DIR}" \\
    "\${APPIMAGE_NAME}" \\
    "\${PACKARCH}" \\
    "\${ENV_FILE}"

  mkdir -p "\${DIST_DIR}"
  if [[ -f "\${DIST_DIR}/\${APPIMAGE_NAME}" ]]; then
    echo "AppImage already in dist/: \${DIST_DIR}/\${APPIMAGE_NAME}"
  elif [[ -f "\${DIST_DIR}/../\${APPIMAGE_NAME}" ]]; then
    mv -f "\${DIST_DIR}/../\${APPIMAGE_NAME}" "\${DIST_DIR}/"
  elif [[ -f "/src/\${APPIMAGE_NAME}" ]]; then
    mv -f "/src/\${APPIMAGE_NAME}" "\${DIST_DIR}/"
  else
    # Fallback: search near the AppDir parent.
    found=\$(find "\${DIST_DIR}" /src -maxdepth 2 -type f -name "\${APPIMAGE_NAME}" 2>/dev/null | head -1 || true)
    [[ -n "\${found}" ]] || { echo "error: AppImage not produced"; exit 1; }
    mv -f "\${found}" "\${DIST_DIR}/"
  fi

  chmod +x "\${DIST_DIR}/\${APPIMAGE_NAME}"
  echo
  echo "AppImage ready: \${DIST_DIR}/\${APPIMAGE_NAME}"
  ls -lh "\${DIST_DIR}/\${APPIMAGE_NAME}"
fi

echo "Done."
EOF
)

# Mount build-env scripts/cmake into the container at /build-env.
podman_run_base \
  -v "${SCRIPT_DIR}:/build-env:Z,ro" \
  "${IMAGE_NAME}" /bin/bash -lc "${remote_script}"

if [[ "${DO_PACKAGE}" == "1" ]]; then
  echo
  echo "Host artifact: ${HOST_APPIMAGE}"
  # Advance the local build counter for the next packaging run (unless the
  # caller pinned APPIMAGE_BUILD_NUMBER explicitly via the environment before
  # we defaulted it — always bump the file so re-runs stay unique).
  echo "$((APPIMAGE_BUILD_NUMBER + 1))" > "${BUILD_NUMBER_FILE}"
  echo "Next APPIMAGE_BUILD_NUMBER will default to $((APPIMAGE_BUILD_NUMBER + 1))"
fi
