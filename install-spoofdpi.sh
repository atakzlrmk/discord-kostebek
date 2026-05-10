#!/bin/bash

set -euo pipefail

INSTALL_DIR="${1:-/usr/local/bin}"
INSTALL_BIN="$INSTALL_DIR/spoofdpi"

if [ -x "$INSTALL_BIN" ]; then
    echo "[*] SpoofDPI already installed at $INSTALL_BIN"
    exit 0
fi

case "$(uname -s)" in
    Darwin) OS_NAME="darwin" ;;
    Linux) OS_NAME="linux" ;;
    *)
        echo "[-] Unsupported OS: $(uname -s)"
        exit 1
        ;;
esac

case "$(uname -m)" in
    arm64|aarch64) ARCH_PATTERN="arm64|aarch64" ;;
    x86_64|amd64) ARCH_PATTERN="x86_64|amd64" ;;
    *)
        echo "[-] Unsupported architecture: $(uname -m)"
        exit 1
        ;;
esac

TMP_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "Resolving latest version..."
RELEASE_JSON="$(curl -fsSL https://api.github.com/repos/xvzc/SpoofDPI/releases/latest)"
DOWNLOAD_URL="$(
    printf '%s\n' "$RELEASE_JSON" \
        | grep '"browser_download_url"' \
        | grep -Ei "$OS_NAME" \
        | grep -Ei "$ARCH_PATTERN" \
        | grep -Ei '\.tar\.gz"' \
        | head -n 1 \
        | sed -E 's/.*"([^"]+)".*/\1/'
)"

if [ -z "$DOWNLOAD_URL" ]; then
    echo "[-] Could not find a SpoofDPI release for ${OS_NAME}/$(uname -m)."
    exit 1
fi

ARCHIVE="$TMP_DIR/spoofdpi.tar.gz"
echo "Downloading $(basename "$DOWNLOAD_URL")..."
curl -fL "$DOWNLOAD_URL" -o "$ARCHIVE"

echo "Extracting..."
tar -xzf "$ARCHIVE" -C "$TMP_DIR"

SPOOFDPI_EXTRACTED="$(find "$TMP_DIR" -type f -name spoofdpi -print | head -n 1)"
if [ -z "$SPOOFDPI_EXTRACTED" ]; then
    echo "[-] Downloaded archive did not contain a spoofdpi binary."
    exit 1
fi

echo "Installing to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
install -m 0755 "$SPOOFDPI_EXTRACTED" "$INSTALL_BIN"

echo "[+] SpoofDPI installed to $INSTALL_BIN"
