#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

export ZEPHYR_SDK_INSTALL_DIR="${ZEPHYR_SDK_INSTALL_DIR:-$HOME/.local/share/zephyr-sdk-0.16.3}"
export PYENV_VERSION="${PYENV_VERSION:-west}"

eval "$(pyenv init -)" 2>/dev/null || true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Prerequisites ────────────────────────────────────────────────
command -v west >/dev/null 2>&1 || error "west not found. Install it: pip install west"
command -v cmake >/dev/null 2>&1 || error "cmake not found"
command -v ninja >/dev/null 2>&1 || error "ninja not found"

if [ ! -d "$ZEPHYR_SDK_INSTALL_DIR" ]; then
    error "Zephyr SDK not found at $ZEPHYR_SDK_INSTALL_DIR"
fi

# ── Clean old build ──────────────────────────────────────────────
info "Removing stale build directory..."
rm -rf build/

# ── West update ──────────────────────────────────────────────────
info "Running west update..."
west update

info "Exporting Zephyr CMake package..."
west zephyr-export

# ── Build targets ────────────────────────────────────────────────
# Matches build.yaml definitions
build_target() {
    local board="$1"
    local shield="$2"
    local label="$3"
    local extra_args=("${@:4}")

    info "Building ${label}: board=${board} shield=${shield}"
    west build -s zmk/app -b "$board" -d "build/${label}" -- \
        -DSHIELD="${shield}" \
        -DZMK_CONFIG="${SCRIPT_DIR}/config" \
        "${extra_args[@]}"

    local firmware="build/${label}/zephyr/zmk.uf2"
    if [ ! -f "$firmware" ]; then
        firmware="build/${label}/zephyr/zmk.bin"
    fi

    if [ -f "$firmware" ]; then
        info "${label} firmware: ${firmware}"
    else
        error "${label}: no firmware output found!"
    fi
}

# Left half
build_target eyelash_corne_left nice_view left

# Right half
build_target eyelash_corne_right nice_view right

# Settings reset (no shield)
info "Building settings_reset: board=eyelash_corne_left shield=settings_reset"
west build -s zmk/app -b eyelash_corne_left -d build/settings_reset -- \
    -DSHIELD="settings_reset" \
    -DZMK_CONFIG="${SCRIPT_DIR}/config"

if [ -f "build/settings_reset/zephyr/zmk.uf2" ]; then
    info "settings_reset firmware: build/settings_reset/zephyr/zmk.uf2"
elif [ -f "build/settings_reset/zephyr/zmk.bin" ]; then
    info "settings_reset firmware: build/settings_reset/zephyr/zmk.bin"
else
    warn "settings_reset: no firmware output found"
fi

# ── Summary ──────────────────────────────────────────────────────
echo ""
info "=== Build complete ==="
echo ""
info "Firmware files:"
for d in build/left build/right build/settings_reset; do
    for ext in uf2 bin; do
        f="${d}/zephyr/zmk.${ext}"
        if [ -f "$f" ]; then
            size=$(du -h "$f" | cut -f1)
            echo "  ${f}  (${size})"
        fi
    done
done
