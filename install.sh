#!/bin/bash
# espvm installer - curl -fsSL <url>/install.sh | bash

set -e

ESPVM_INSTALL_DIR="${ESPVM_INSTALL_DIR:-$HOME/.local/bin}"
ESPVM_SCRIPT_URL="${ESPVM_SCRIPT_URL:-https://raw.githubusercontent.com/matterizelabs/espvm/refs/heads/main/espvm}"
ESPVM_SHA256_URL="${ESPVM_SHA256_URL:-${ESPVM_SCRIPT_URL}.sha256}"
# Set to a known SHA-256 hash to verify the download. Empty skips verification.
ESPVM_SHA256_EXPECTED="${ESPVM_SHA256_EXPECTED:-}"
# Set to a GPG key fingerprint to verify the download signature. Empty skips GPG verification.
ESPVM_GPG_KEY="${ESPVM_GPG_KEY:-}"
# Pin to a specific commit hash instead of using a branch ref for reproducibility.
# When set, the URL is rewritten to use this commit instead of refs/heads/main.
ESPVM_COMMIT_REF="${ESPVM_COMMIT_REF:-}"

# Colors
red() { echo -e "\033[0;31m$1\033[0m"; }
green() { echo -e "\033[0;32m$1\033[0m"; }
yellow() { echo -e "\033[0;33m$1\033[0m"; }

echo "Installing espvm - ESP SDK Version Manager"
echo ""

# Validate that script URL uses HTTPS (prevent MITM)
if [[ "$ESPVM_SCRIPT_URL" != https://* ]]; then
    red "Error: ESPVM_SCRIPT_URL must use HTTPS: $ESPVM_SCRIPT_URL"
    red "Refusing to download over insecure connection."
    exit 1
fi

# If a specific commit ref is pinned, rewrite the URL for reproducibility.
# This prevents supply-chain attacks from compromised branch refs.
if [[ -n "$ESPVM_COMMIT_REF" ]]; then
    # Replace refs/heads/<branch> or refs/tags/<tag> with the pinned commit
    ESPVM_SCRIPT_URL=$(echo "$ESPVM_SCRIPT_URL" | sed -E "s|/refs/(heads|tags)/[^/]+|/$ESPVM_COMMIT_REF|")
    ESPVM_SHA256_URL="${ESPVM_SCRIPT_URL}.sha256"
    echo "Pinned to commit: $ESPVM_COMMIT_REF"
fi

# Check for required tools
if ! command -v git &> /dev/null; then
    red "Error: git is required but not installed"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    red "Error: python3 is required but not installed"
    exit 1
fi

# Create install directory
mkdir -p "$ESPVM_INSTALL_DIR"

# Download espvm script
echo "Downloading espvm..."
if command -v curl &> /dev/null; then
    curl -fsSL "$ESPVM_SCRIPT_URL" -o "$ESPVM_INSTALL_DIR/espvm"
elif command -v wget &> /dev/null; then
    wget -qO "$ESPVM_INSTALL_DIR/espvm" "$ESPVM_SCRIPT_URL"
else
    red "Error: curl or wget is required"
    exit 1
fi

# Verify download integrity via SHA-256 checksum
_espvm_sha256() {
    if command -v sha256sum &> /dev/null; then
        sha256sum "$1" | cut -d' ' -f1
    elif command -v shasum &> /dev/null; then
        shasum -a 256 "$1" | cut -d' ' -f1
    elif command -v openssl &> /dev/null; then
        openssl dgst -sha256 "$1" | cut -d' ' -f"${#2}"
    else
        echo ""
    fi
}

# Try to verify with expected hash (if set via env)
if [[ -n "$ESPVM_SHA256_EXPECTED" ]]; then
    actual_hash=$(_espvm_sha256 "$ESPVM_INSTALL_DIR/espvm")
    if [[ -z "$actual_hash" ]]; then
        red "Error: No SHA-256 tool available (sha256sum, shasum, openssl) for verification"
        rm -f "$ESPVM_INSTALL_DIR/espvm"
        exit 1
    fi
    if [[ "$actual_hash" != "$ESPVM_SHA256_EXPECTED" ]]; then
        red "Error: SHA-256 checksum mismatch!"
        red "  Expected: $ESPVM_SHA256_EXPECTED"
        red "  Actual:   $actual_hash"
        red "The downloaded file may have been tampered with."
        rm -f "$ESPVM_INSTALL_DIR/espvm"
        exit 1
    fi
    green "SHA-256 checksum verified"
else
    # Try to download and verify against remote .sha256 file
    sha256_file="${TMPDIR:-/tmp}/espvm-sha256"
    if command -v curl &> /dev/null; then
        if curl -fsSL "$ESPVM_SHA256_URL" -o "$sha256_file" 2>/dev/null; then
            remote_hash=$(cut -d' ' -f1 "$sha256_file" 2>/dev/null || echo "")
            actual_hash=$(_espvm_sha256 "$ESPVM_INSTALL_DIR/espvm")
            if [[ -n "$remote_hash" && -n "$actual_hash" && "$remote_hash" != "$actual_hash" ]]; then
                yellow "Warning: SHA-256 checksum mismatch with remote .sha256 file"
                yellow "  Remote: $remote_hash"
                yellow "  Actual: $actual_hash"
                yellow "This may indicate a network issue or tampering. Proceed with caution."
                answer=""
                read -rp "Continue anyway? [y/N]: " answer
                if [[ ! "$answer" =~ ^[Yy]$ ]]; then
                    rm -f "$ESPVM_INSTALL_DIR/espvm" "$sha256_file"
                    exit 1
                fi
            elif [[ -n "$remote_hash" && -n "$actual_hash" ]]; then
                green "SHA-256 checksum verified against remote"
            fi
            rm -f "$sha256_file"
        else
            yellow "Warning: Could not download SHA-256 checksum file for verification"
            yellow "Download integrity could not be verified."
        fi
    fi
fi

# Verify GPG signature if a signing key is specified
if [[ -n "$ESPVM_GPG_KEY" ]]; then
    sig_url="${ESPVM_SCRIPT_URL}.sig"
    sig_file="${TMPDIR:-/tmp}/espvm.sig"
    if command -v gpg &>/dev/null; then
        echo "Verifying GPG signature..."
        if curl -fsSL "$sig_url" -o "$sig_file" 2>/dev/null; then
            if gpg --verify "$sig_file" "$ESPVM_INSTALL_DIR/espvm" 2>/dev/null; then
                green "GPG signature verified"
            else
                red "Error: GPG signature verification failed!"
                red "The download may have been tampered with."
                rm -f "$ESPVM_INSTALL_DIR/espvm" "$sig_file"
                exit 1
            fi
        else
            yellow "Warning: Could not download GPG signature file"
            yellow "Setting ESPVM_GPG_KEY but no .sig file available at: $sig_url"
        fi
        rm -f "$sig_file"
    else
        yellow "Warning: ESPVM_GPG_KEY is set but gpg is not installed. Skipping signature verification."
    fi
fi

# Make executable
chmod +x "$ESPVM_INSTALL_DIR/espvm"

green "espvm installed to $ESPVM_INSTALL_DIR/espvm"
echo ""

# Detect shell and config file
SHELL_NAME=$(basename "$SHELL")
SHELL_RC=""

case "$SHELL_NAME" in
    bash)
        SHELL_RC="$HOME/.bashrc"
        ;;
    zsh)
        SHELL_RC="$HOME/.zshrc"
        ;;
    *)
        yellow "Unknown shell: $SHELL_NAME"
        SHELL_RC="$HOME/.bashrc"
        ;;
esac

# Add source line if not already present (use printf %q to prevent injection)
safe_install_dir=$(printf '%q' "$ESPVM_INSTALL_DIR")
SOURCE_LINE="source ${safe_install_dir}/espvm"

if [[ -f "$SHELL_RC" ]] && grep -qF "espvm" "$SHELL_RC"; then
    yellow "espvm already configured in $SHELL_RC"
else
    # Create a backup of the shell RC file before modifying it
    if [[ -f "$SHELL_RC" ]]; then
        cp "$SHELL_RC" "${SHELL_RC}.espvm.bak"
        green "Backup of $SHELL_RC saved to ${SHELL_RC}.espvm.bak"
    fi
    echo "" >> "$SHELL_RC"
    echo "# espvm - ESP SDK Version Manager" >> "$SHELL_RC"
    echo "$SOURCE_LINE" >> "$SHELL_RC"
    green "Added espvm to $SHELL_RC"
fi

echo ""
green "Installation complete!"
echo ""
echo "To start using espvm, either:"
echo "  1. Restart your terminal, or"
echo "  2. Run: source $SHELL_RC"
echo ""
echo "Quick start:"
echo "  espvm help        Show available commands"
echo "  espvm remote      List available ESP-IDF versions"
echo "  espvm i 5.4.1     Install ESP-IDF v5.4.1"
echo "  espvm 5.4.1       Activate ESP-IDF v5.4.1"
echo "  espvm ls          List installed versions"
echo "  espvm status      Show active SDKs"
echo ""
echo "ESP-Matter (requires IDF active first):"
echo "  espvm -m i 1.4    Install ESP-Matter v1.4"
echo "  espvm -m 1.4      Activate ESP-Matter v1.4"
echo ""
echo "Tab completion is enabled automatically."