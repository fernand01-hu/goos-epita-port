#!/usr/bin/env bash
# ==============================================================================
# Desktop Goose - Portable Package Builder
# ==============================================================================
# Packages Desktop Goose into a self-contained tarball that can be transferred
# to ANY Linux computer and installed without root/sudo privileges.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_NAME="cppgoose-portable"
STAGE_DIR="${SCRIPT_DIR}/${PACKAGE_NAME}"
ARCHIVE_NAME="${PACKAGE_NAME}.tar.gz"

echo "Packaging Desktop Goose for portable non-root installation..."

# 1. Locate or build binary
BIN_SRC=""
if [[ -x "${SCRIPT_DIR}/result/bin/CppGoose" ]]; then
    BIN_SRC="${SCRIPT_DIR}/result/bin/CppGoose"
elif [[ -x "${SCRIPT_DIR}/build/CppGoose" ]]; then
    BIN_SRC="${SCRIPT_DIR}/build/CppGoose"
elif command -v nix >/dev/null 2>&1; then
    echo "Building binary with Nix..."
    (cd "${SCRIPT_DIR}" && nix --extra-experimental-features "nix-command flakes" build .#i3)
    BIN_SRC="${SCRIPT_DIR}/result/bin/CppGoose"
elif command -v cmake >/dev/null 2>&1; then
    echo "Building binary with CMake..."
    cmake -B "${SCRIPT_DIR}/build" -S "${SCRIPT_DIR}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DENABLE_WAYLAND=OFF \
        -DENABLE_LAYER_SHELL=OFF
    cmake --build "${SCRIPT_DIR}/build" -j"$(nproc 2>/dev/null || echo 2)"
    BIN_SRC="${SCRIPT_DIR}/build/CppGoose"
else
    echo "Error: No compiled CppGoose found and no build tool (nix/cmake) available." >&2
    exit 1
fi

# 2. Stage files
rm -rf "${STAGE_DIR}"
mkdir -p "${STAGE_DIR}/bin"
mkdir -p "${STAGE_DIR}/Assets"
mkdir -p "${STAGE_DIR}/icons"

echo "Copying binary..."
cp -f "${BIN_SRC}" "${STAGE_DIR}/bin/CppGoose"
chmod +x "${STAGE_DIR}/bin/CppGoose"

echo "Copying assets..."
cp -r "${SCRIPT_DIR}/Assets/Images" "${STAGE_DIR}/Assets/"
cp -r "${SCRIPT_DIR}/Assets/Sound"  "${STAGE_DIR}/Assets/"
cp -r "${SCRIPT_DIR}/Assets/Text"   "${STAGE_DIR}/Assets/"
if [[ -d "${SCRIPT_DIR}/Assets/Mods" ]]; then
    cp -r "${SCRIPT_DIR}/Assets/Mods" "${STAGE_DIR}/Assets/"
fi

echo "Copying icon and installer..."
cp -f "${SCRIPT_DIR}/icons/cppgoose.svg" "${STAGE_DIR}/icons/"
cp -f "${SCRIPT_DIR}/install.sh" "${STAGE_DIR}/install.sh"
chmod +x "${STAGE_DIR}/install.sh"

cat > "${STAGE_DIR}/README.txt" << 'EOF'
======================================================
Desktop Goose (CppGoose) - Portable Non-Root Edition
======================================================

To install on this computer without sudo/root privileges:

  ./install.sh

This will install:
  - CppGoose executable -> ~/.local/bin/CppGoose
  - Assets               -> ~/.local/share/CppGoose/Assets
  - Desktop Launcher     -> ~/.local/share/applications/CppGoose.desktop
  - Icon                 -> ~/.local/share/icons/hicolor/scalable/apps/cppgoose.svg

To run Desktop Goose:
  CppGoose

To check status:
  CppGoose status

To dismiss or quit:
  CppGoose quit
  (or hold the ESC key for 3 seconds)

To uninstall at any time:
  ./install.sh --uninstall
EOF

# 3. Create compressed archive
echo "Creating ${ARCHIVE_NAME}..."
tar -czf "${SCRIPT_DIR}/${ARCHIVE_NAME}" -C "${SCRIPT_DIR}" "${PACKAGE_NAME}"
rm -rf "${STAGE_DIR}"

echo ""
echo "Successfully generated: ${SCRIPT_DIR}/${ARCHIVE_NAME}"
echo "You can now copy this tarball to any Linux computer and run:"
echo "  tar -xzf ${ARCHIVE_NAME} && cd ${PACKAGE_NAME} && ./install.sh"
echo "Zero sudo privileges required!"
