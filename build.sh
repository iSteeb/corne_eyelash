#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

OUTDIR="$HOME/Downloads"
mkdir -p "$OUTDIR"

PYENV_VERSION=west west build -s zmk/app -b eyelash_corne_left -d build/left -- -DSHIELD=nice_view
PYENV_VERSION=west west build -s zmk/app -b eyelash_corne_right -d build/right -- -DSHIELD=nice_view

cp build/left/zephyr/zmk.uf2 "$OUTDIR/eyelash_corne_left.uf2"
cp build/right/zephyr/zmk.uf2 "$OUTDIR/eyelash_corne_right.uf2"

echo ""
echo "Firmware copied to $OUTDIR:"
echo "  eyelash_corne_left.uf2"
echo "  eyelash_corne_right.uf2"
