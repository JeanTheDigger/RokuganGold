#!/usr/bin/env bash
# Ensure Godot 4.6.2-stable is installed so parse-checks / headless test drivers can run.
# Idempotent — exits fast if godot is already on PATH. The web-session container is
# ephemeral, so this re-installs the engine on a fresh session. Safe to run manually:
#   bash .claude/hooks/setup_godot.sh
# It is ONLY auto-run if registered as a SessionStart hook in .claude/settings.json
# (not wired by default — see the note in that direction).
set -uo pipefail

GODOT_VERSION="4.6.2-stable"
GODOT_DEST="/usr/local/bin/godot"
ZIP_NAME="Godot_v${GODOT_VERSION}_linux.x86_64.zip"
BIN_NAME="Godot_v${GODOT_VERSION}_linux.x86_64"
URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${ZIP_NAME}"

if command -v godot >/dev/null 2>&1; then
    echo "Godot already present: $(godot --version 2>/dev/null | head -1)"
    exit 0
fi

echo "Installing Godot ${GODOT_VERSION} (headless) ..."
tmp="$(mktemp -d)"
if ! curl -fsSL -o "${tmp}/godot.zip" "${URL}"; then
    echo "WARN: could not download Godot (network policy?). Parse-checks/tests unavailable." >&2
    rm -rf "${tmp}"; exit 0
fi
unzip -oq "${tmp}/godot.zip" -d "${tmp}"
install -m 0755 "${tmp}/${BIN_NAME}" "${GODOT_DEST}"
rm -rf "${tmp}"
echo "Godot installed: $(godot --version 2>/dev/null | head -1)"
exit 0
