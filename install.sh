#!/usr/bin/env bash
# ==============================================================================
# Desktop Goose (CppGoose) - Zero-Sudo User Installer
# ==============================================================================
# Installs CppGoose completely inside the user's home directory (~/.local).
# Requires NO root / sudo privileges.
# ==============================================================================

set -euo pipefail

# Text formatting
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    BOLD="\033[1m"
    GREEN="\033[32m"
    YELLOW="\033[33m"
    CYAN="\033[36m"
    RED="\033[31m"
    RESET="\033[0m"
else
    BOLD=""
    GREEN=""
    YELLOW=""
    CYAN=""
    RED=""
    RESET=""
fi

log_info()    { echo -e "${CYAN}[*]${RESET} $*"; }
log_ok()      { echo -e "${GREEN}[✓]${RESET} ${BOLD}$*${RESET}"; }
log_warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
log_error()   { echo -e "${RED}[✗]${RESET} $*" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default settings
DEFAULT_PREFIX="${HOME}/.local"
PREFIX="${DEFAULT_PREFIX}"
XDG_DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"
CUSTOM_BINARY=""
FORCE_BUILD_NIX=0
FORCE_BUILD_CMAKE=0
UNINSTALL_MODE=0

show_help() {
    cat <<EOF
Desktop Goose (CppGoose) - User Space Installer (No Sudo Required)

Usage:
  ./install.sh [options]

Options:
  -p, --prefix <dir>     Install prefix (default: ~/.local)
  -b, --binary <file>    Path to pre-compiled CppGoose binary
  --build-nix            Force building with Nix (no sudo required)
  --build-cmake          Force building with CMake (no sudo required)
  -u, --uninstall        Remove installed CppGoose files and desktop entry
  -h, --help             Show this help message

What this script installs (under ~/.local):
  - Binary:         <prefix>/bin/CppGoose
  - Assets:         <prefix>/share/CppGoose/Assets
  - Desktop Entry:  ~/.local/share/applications/CppGoose.desktop
  - Application Icon: ~/.local/share/icons/hicolor/scalable/apps/cppgoose.svg

No root permissions or sudo required at any step.
EOF
}

# Parse CLI options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--prefix)
            PREFIX="$2"
            shift 2
            ;;
        -b|--binary)
            CUSTOM_BINARY="$2"
            shift 2
            ;;
        --build-nix)
            FORCE_BUILD_NIX=1
            shift
            ;;
        --build-cmake)
            FORCE_BUILD_CMAKE=1
            shift
            ;;
        -u|--uninstall)
            UNINSTALL_MODE=1
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check if running as root
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    log_warn "Notice: You are running this script as root / sudo."
    log_warn "This installer is specifically designed to install for your regular user account without sudo."
    echo ""
fi

BIN_DIR="${PREFIX}/bin"
SHARE_DIR="${PREFIX}/share/CppGoose"
ASSETS_DIR="${SHARE_DIR}/Assets"
APPS_DIR="${XDG_DATA_HOME}/applications"
ICONS_DIR="${XDG_DATA_HOME}/icons/hicolor/scalable/apps"

# ------------------------------------------------------------------------------
# Uninstall Mode
# ------------------------------------------------------------------------------
if [[ "${UNINSTALL_MODE}" -eq 1 ]]; then
    log_info "Uninstalling Desktop Goose from ${PREFIX}..."

    # Kill any running instance
    if pgrep -x CppGoose >/dev/null 2>&1; then
        log_info "Stopping running CppGoose processes..."
        pkill -x CppGoose 2>/dev/null || true
    fi

    rm -f "${BIN_DIR}/CppGoose"
    rm -rf "${SHARE_DIR}"
    rm -f "${APPS_DIR}/CppGoose.desktop"
    rm -f "${ICONS_DIR}/cppgoose.svg"

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "${APPS_DIR}" 2>/dev/null || true
    fi

    log_ok "Desktop Goose has been completely uninstalled."
    exit 0
fi

echo -e "${BOLD}======================================================${RESET}"
echo -e "${BOLD}       Desktop Goose (CppGoose) - User Installer      ${RESET}"
echo -e "${BOLD}======================================================${RESET}"
log_info "Target prefix: ${PREFIX}"
log_info "Binary path:   ${BIN_DIR}/CppGoose"
log_info "Assets path:   ${ASSETS_DIR}"
echo ""

# ------------------------------------------------------------------------------
# Locate or build binary
# ------------------------------------------------------------------------------
RESOLVED_BIN=""

if [[ -n "${CUSTOM_BINARY}" ]]; then
    if [[ -f "${CUSTOM_BINARY}" ]]; then
        RESOLVED_BIN="${CUSTOM_BINARY}"
        log_info "Using specified binary: ${RESOLVED_BIN}"
    else
        log_error "Specified binary '${CUSTOM_BINARY}' does not exist!"
        exit 1
    fi
elif [[ "${FORCE_BUILD_NIX}" -eq 1 ]]; then
    log_info "Building with Nix as requested..."
    (cd "${SCRIPT_DIR}" && nix --extra-experimental-features "nix-command flakes" build .#i3)
    RESOLVED_BIN="${SCRIPT_DIR}/result/bin/CppGoose"
elif [[ "${FORCE_BUILD_CMAKE}" -eq 1 ]]; then
    log_info "Building with CMake as requested..."
    cmake -B "${SCRIPT_DIR}/build" -S "${SCRIPT_DIR}" \
        -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DENABLE_WAYLAND=OFF \
        -DENABLE_LAYER_SHELL=OFF
    cmake --build "${SCRIPT_DIR}/build" -j"$(nproc 2>/dev/null || echo 2)"
    RESOLVED_BIN="${SCRIPT_DIR}/build/CppGoose"
else
    # Auto-detection:
    # 1. Existing local builds or prebuilt bundle
    CANDIDATES=(
        "${SCRIPT_DIR}/result/bin/CppGoose"
        "${SCRIPT_DIR}/build/CppGoose"
        "${SCRIPT_DIR}/bin/CppGoose"
        "${SCRIPT_DIR}/CppGoose"
    )

    for cand in "${CANDIDATES[@]}"; do
        if [[ -x "${cand}" ]]; then
            RESOLVED_BIN="${cand}"
            log_info "Found pre-built binary: ${RESOLVED_BIN}"
            break
        fi
    done

    # 2. If no binary found, check if Nix is available
    if [[ -z "${RESOLVED_BIN}" ]] && command -v nix >/dev/null 2>&1; then
        log_info "No binary found, but Nix was detected."
        log_info "Compiling CppGoose via Nix (unprivileged build)..."
        (cd "${SCRIPT_DIR}" && nix --extra-experimental-features "nix-command flakes" build .#i3)
        RESOLVED_BIN="${SCRIPT_DIR}/result/bin/CppGoose"
    fi

    # 3. If still no binary, check if CMake and g++/clang++ are available
    if [[ -z "${RESOLVED_BIN}" ]] && command -v cmake >/dev/null 2>&1 && (command -v g++ >/dev/null 2>&1 || command -v clang++ >/dev/null 2>&1); then
        log_info "No binary found, but CMake and C++ compiler were detected."
        log_info "Building CppGoose via CMake..."
        cmake -B "${SCRIPT_DIR}/build" -S "${SCRIPT_DIR}" \
            -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
            -DCMAKE_BUILD_TYPE=Release \
            -DENABLE_WAYLAND=OFF \
            -DENABLE_LAYER_SHELL=OFF
        cmake --build "${SCRIPT_DIR}/build" -j"$(nproc 2>/dev/null || echo 2)"
        RESOLVED_BIN="${SCRIPT_DIR}/build/CppGoose"
    fi
fi

if [[ -z "${RESOLVED_BIN}" || ! -f "${RESOLVED_BIN}" ]]; then
    log_error "Could not find or build the CppGoose binary!"
    echo ""
    echo "Options to resolve:"
    echo "  1. If you are packaging for another computer, run ./package-portable.sh first"
    echo "     on a machine with build tools, then transfer the tarball."
    echo "  2. Pass an existing binary with: ./install.sh --binary /path/to/CppGoose"
    echo "  3. If building from source, ensure either Nix or (CMake + C++ compiler + GTK4) is installed."
    exit 1
fi

# ------------------------------------------------------------------------------
# Locate Assets directory
# ------------------------------------------------------------------------------
SRC_ASSETS=""
for a_cand in "${SCRIPT_DIR}/Assets" "${SCRIPT_DIR}/../Assets" "${SCRIPT_DIR}/share/CppGoose/Assets"; do
    if [[ -d "${a_cand}" ]]; then
        SRC_ASSETS="${a_cand}"
        break
    fi
done

if [[ -z "${SRC_ASSETS}" ]]; then
    log_error "Assets directory not found!"
    exit 1
fi

# ------------------------------------------------------------------------------
# Installation
# ------------------------------------------------------------------------------
log_info "Creating destination directories..."
mkdir -p "${BIN_DIR}"
mkdir -p "${SHARE_DIR}"
mkdir -p "${APPS_DIR}"
mkdir -p "${ICONS_DIR}"

log_info "Installing CppGoose binary to ${BIN_DIR}/CppGoose..."
# If source and dest are the same file, avoid cp error
if [[ "$(readlink -f "${RESOLVED_BIN}")" != "$(readlink -f "${BIN_DIR}/CppGoose" 2>/dev/null || true)" ]]; then
    rm -f "${BIN_DIR}/CppGoose"
    cp -f "${RESOLVED_BIN}" "${BIN_DIR}/CppGoose"
fi
chmod 755 "${BIN_DIR}/CppGoose"

log_info "Installing Assets to ${ASSETS_DIR}..."
mkdir -p "${ASSETS_DIR}"
# Copy assets cleanly (excluding build artifacts and raw headers)
cp -r "${SRC_ASSETS}/Images" "${ASSETS_DIR}/"
cp -r "${SRC_ASSETS}/Sound"  "${ASSETS_DIR}/"
cp -r "${SRC_ASSETS}/Text"   "${ASSETS_DIR}/"
if [[ -d "${SRC_ASSETS}/Mods" ]]; then
    cp -r "${SRC_ASSETS}/Mods" "${ASSETS_DIR}/"
fi
chmod -R u+rwX "${ASSETS_DIR}"

# Install SVG Icon
SRC_ICON="${SCRIPT_DIR}/icons/cppgoose.svg"
if [[ -f "${SRC_ICON}" ]]; then
    log_info "Installing application icon to ${ICONS_DIR}/cppgoose.svg..."
    cp -f "${SRC_ICON}" "${ICONS_DIR}/cppgoose.svg"
fi

# Install Desktop Entry
log_info "Creating desktop entry at ${APPS_DIR}/CppGoose.desktop..."
cat > "${APPS_DIR}/CppGoose.desktop" <<EOF
[Desktop Entry]
Name=Desktop Goose
Comment=An annoying desktop goose companion for Linux
Exec=${BIN_DIR}/CppGoose
Icon=cppgoose
Terminal=false
Type=Application
Categories=Game;Amusement;Utility;
StartupNotify=false
EOF
chmod +x "${APPS_DIR}/CppGoose.desktop"

# Refresh desktop database if tool is available
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${APPS_DIR}" 2>/dev/null || true
fi

echo ""
log_ok "Desktop Goose has been successfully installed!"
echo ""

# ------------------------------------------------------------------------------
# Post-installation Checks & Diagnostics
# ------------------------------------------------------------------------------

# 1. PATH Check
IN_PATH=0
IFS=':' read -ra PATH_DIRS <<< "${PATH}"
for dir in "${PATH_DIRS[@]}"; do
    if [[ "${dir}" == "${BIN_DIR}" || "${dir}" == "${HOME}/.local/bin" ]]; then
        IN_PATH=1
        break
    fi
done

if [[ "${IN_PATH}" -eq 0 ]]; then
    log_warn "${BIN_DIR} is not currently in your PATH!"
    echo "  To run 'CppGoose' from anywhere in your terminal, add this to your ~/.bashrc or ~/.zshrc:"
    echo "    export PATH=\"${BIN_DIR}:\$PATH\""
    echo ""
fi

# 2. Shared Library (ldd) Verification
if command -v ldd >/dev/null 2>&1; then
    MISSING_LIBS=$(ldd "${BIN_DIR}/CppGoose" 2>/dev/null | grep "not found" || true)
    if [[ -n "${MISSING_LIBS}" ]]; then
        log_warn "Some shared libraries required by CppGoose appear to be missing:"
        echo "${MISSING_LIBS}"
        echo ""
        echo "If CppGoose fails to launch, please ask your administrator or install the runtime libraries:"
        echo "  - Debian / Ubuntu / Mint:  apt install libgtk-4-1 libsdl2-mixer-2.0-0"
        echo "  - Arch Linux:             pacman -S gtk4 sdl2_mixer"
        echo "  - Fedora:                 dnf install gtk4 SDL2_mixer"
        echo "  - Alpine:                 apk add gtk4.0 sdl2_mixer"
        echo ""
    fi
fi

# 3. Window Manager & Compositor Checks
WM_NAME=""
if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
    WM_NAME="${XDG_CURRENT_DESKTOP}"
elif [[ -n "${DESKTOP_SESSION:-}" ]]; then
    WM_NAME="${DESKTOP_SESSION}"
fi

if [[ "${WM_NAME}" =~ [iI]3 ]] || pgrep -x i3 >/dev/null 2>&1; then
    echo -e "${BOLD}Tip for i3wm users:${RESET}"
    if ! pgrep -x picom >/dev/null 2>&1 && ! pgrep -x compton >/dev/null 2>&1; then
        log_warn "No X11 compositor (picom) is currently running!"
        echo "  Desktop Goose requires a compositor for transparent window overlay on i3."
        echo "  Start picom with:   picom -b"
        echo "  To autostart in i3, add this to ~/.config/i3/config:"
        echo "    exec --no-startup-id picom -b"
        echo "    exec --no-startup-id CppGoose"
        echo ""
    else
        log_ok "Compositor (picom/compton) detected and running."
        echo ""
    fi
fi

echo -e "${BOLD}How to run:${RESET}"
echo "  Launch goose:       CppGoose"
echo "  Check status:       CppGoose status"
echo "  Interactive shell:  CppGoose shell"
echo "  Dismiss / Quit:     CppGoose quit   (or hold ESC for 3 seconds)"
echo "  To uninstall:       ./install.sh --uninstall"
echo ""
