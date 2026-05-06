#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

OUTPUT_DIR="${OUTPUT_DIR:-$HOME/Downloads}"
mkdir -p "$OUTPUT_DIR"

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

# ── Copy artifacts to OUTPUT_DIR ─────────────────────────────────
info "Copying firmware to ${OUTPUT_DIR}..."
copy_artifact() {
    local label="$1"
    local out_name="$2"
    local src=""
    for ext in uf2 bin; do
        local candidate="build/${label}/zephyr/zmk.${ext}"
        if [ -f "$candidate" ]; then
            src="$candidate"
            local dest="${OUTPUT_DIR}/${out_name}.${ext}"
            cp -f "$src" "$dest"
            info "  ${dest}"
            return 0
        fi
    done
    warn "${label}: no firmware artifact to copy"
    return 1
}

copy_artifact left            eyelash_corne_left
copy_artifact right           eyelash_corne_right
copy_artifact settings_reset  eyelash_corne_settings_reset

# ── Summary ──────────────────────────────────────────────────────
echo ""
info "=== Build complete ==="
echo ""
info "Firmware files (build tree):"
for d in build/left build/right build/settings_reset; do
    for ext in uf2 bin; do
        f="${d}/zephyr/zmk.${ext}"
        if [ -f "$f" ]; then
            size=$(du -h "$f" | cut -f1)
            echo "  ${f}  (${size})"
        fi
    done
done

echo ""
info "Firmware files (${OUTPUT_DIR}):"
for name in eyelash_corne_left eyelash_corne_right eyelash_corne_settings_reset; do
    for ext in uf2 bin; do
        f="${OUTPUT_DIR}/${name}.${ext}"
        if [ -f "$f" ]; then
            size=$(du -h "$f" | cut -f1)
            echo "  ${f}  (${size})"
        fi
    done
done
