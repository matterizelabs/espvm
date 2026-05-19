#!/bin/bash
set -euo pipefail

ESPVM_INSTALL_DIR="${ESPVM_INSTALL_DIR:-$HOME/.local/bin}"
ESPVM_SCRIPT_URL="${ESPVM_SCRIPT_URL:-https://raw.githubusercontent.com/matterizelabs/espvm/refs/heads/main/espvm}"
ESPVM_SHA256_URL="${ESPVM_SHA256_URL:-${ESPVM_SCRIPT_URL}.sha256}"
ESPVM_SHA256_EXPECTED="${ESPVM_SHA256_EXPECTED:-}"
ESPVM_GPG_KEY="${ESPVM_GPG_KEY:-}"
ESPVM_COMMIT_REF="${ESPVM_COMMIT_REF:-}"

red()   { echo -e "\033[0;31m$1\033[0m"; }
green() { echo -e "\033[0;32m$1\033[0m"; }
yellow(){ echo -e "\033[0;33m$1\033[0m"; }

die()   { red "$1"; exit 1; }

_espvm_sha256() {
    if command -v sha256sum &>/dev/null; then sha256sum "$1" | cut -d' ' -f1
    elif command -v shasum &>/dev/null; then shasum -a 256 "$1" | cut -d' ' -f1
    elif command -v openssl &>/dev/null; then openssl dgst -sha256 "$1" | awk '{print $NF}'
    else echo ""
    fi
}

# ── Validate ──

[[ "$ESPVM_SCRIPT_URL" == https://* ]] || die "Error: ESPVM_SCRIPT_URL must use HTTPS: $ESPVM_SCRIPT_URL"
command -v git &>/dev/null || die "Error: git is required"
command -v python3 &>/dev/null || die "Error: python3 is required"

# ── Pin to commit if requested ──

if [[ -n "$ESPVM_COMMIT_REF" ]]; then
    ESPVM_SCRIPT_URL=$(echo "$ESPVM_SCRIPT_URL" | sed -E "s|/refs/(heads|tags)/[^/]+|/$ESPVM_COMMIT_REF|")
    ESPVM_SHA256_URL="${ESPVM_SCRIPT_URL}.sha256"
    echo "Pinned to commit: $ESPVM_COMMIT_REF"
fi

# ── Download ──

mkdir -p "$ESPVM_INSTALL_DIR"
echo "Downloading espvm..."
if command -v curl &>/dev/null; then
    curl -fsSL "$ESPVM_SCRIPT_URL" -o "$ESPVM_INSTALL_DIR/espvm"
elif command -v wget &>/dev/null; then
    wget -qO "$ESPVM_INSTALL_DIR/espvm" "$ESPVM_SCRIPT_URL"
else
    die "Error: curl or wget is required"
fi

# ── Verify integrity ──

if [[ -n "$ESPVM_SHA256_EXPECTED" ]]; then
    actual_hash=$(_espvm_sha256 "$ESPVM_INSTALL_DIR/espvm")
    [[ -z "$actual_hash" ]] && { rm -f "$ESPVM_INSTALL_DIR/espvm"; die "Error: No SHA-256 tool available for verification"; }
    [[ "$actual_hash" != "$ESPVM_SHA256_EXPECTED" ]] && {
        red "Error: SHA-256 checksum mismatch!"
        red "  Expected: $ESPVM_SHA256_EXPECTED"
        red "  Actual:   $actual_hash"
        rm -f "$ESPVM_INSTALL_DIR/espvm"
        exit 1
    }
    green "SHA-256 checksum verified"
else
    sha256_file=$(mktemp "${TMPDIR:-/tmp}/espvm-sha256.XXXXXX" 2>/dev/null) || sha256_file=""
    if [[ -n "$sha256_file" ]] && command -v curl &>/dev/null; then
        if curl -fsSL "$ESPVM_SHA256_URL" -o "$sha256_file" 2>/dev/null; then
            remote_hash=$(cut -d' ' -f1 "$sha256_file" 2>/dev/null || echo "")
            actual_hash=$(_espvm_sha256 "$ESPVM_INSTALL_DIR/espvm")
            if [[ -n "$remote_hash" && -n "$actual_hash" && "$remote_hash" != "$actual_hash" ]]; then
                yellow "Warning: SHA-256 mismatch with remote .sha256 file"
                yellow "  Remote: $remote_hash"
                yellow "  Actual: $actual_hash"
                read -rp "Continue anyway? [y/N]: " answer
                [[ "$answer" =~ ^[Yy]$ ]] || { rm -f "$ESPVM_INSTALL_DIR/espvm" "$sha256_file"; exit 1; }
            elif [[ -n "$remote_hash" && -n "$actual_hash" ]]; then
                green "SHA-256 checksum verified against remote"
            fi
        else
            yellow "Warning: Could not download SHA-256 checksum file"
        fi
        rm -f "$sha256_file"
    fi
fi

# ── GPG verification ──

if [[ -n "$ESPVM_GPG_KEY" ]]; then
    if command -v gpg &>/dev/null; then
        sig_url="${ESPVM_SCRIPT_URL}.sig"
        sig_file=$(mktemp "${TMPDIR:-/tmp}/espvm-sig.XXXXXX" 2>/dev/null) || sig_file=""
        if [[ -n "$sig_file" ]]; then
            echo "Verifying GPG signature..."
            if curl -fsSL "$sig_url" -o "$sig_file" 2>/dev/null; then
                if gpg --verify "$sig_file" "$ESPVM_INSTALL_DIR/espvm" 2>/dev/null; then
                    green "GPG signature verified"
                else
                    rm -f "$ESPVM_INSTALL_DIR/espvm" "$sig_file"
                    die "Error: GPG signature verification failed!"
                fi
            else
                yellow "Warning: Could not download GPG signature file"
            fi
            rm -f "$sig_file"
        fi
    else
        yellow "Warning: ESPVM_GPG_KEY is set but gpg is not installed. Skipping."
    fi
fi

# ── Install ──

chmod +x "$ESPVM_INSTALL_DIR/espvm"
green "espvm installed to $ESPVM_INSTALL_DIR/espvm"

# ── Configure shell ──

SHELL_RC="$HOME/.bashrc"
case "$(basename "${SHELL:-/bin/bash}")" in
    zsh)  SHELL_RC="$HOME/.zshrc" ;;
    fish) SHELL_RC="$HOME/.config/fish/config.fish" ;;
esac

safe_install_dir=$(printf '%q' "$ESPVM_INSTALL_DIR")
SOURCE_LINE="source ${safe_install_dir}/espvm"

if [[ -f "$SHELL_RC" ]] && grep -qF "espvm" "$SHELL_RC"; then
    yellow "espvm already configured in $SHELL_RC"
else
    if [[ -f "$SHELL_RC" ]]; then
        cp "$SHELL_RC" "${SHELL_RC}.espvm.bak"
    fi
    rc_tmpfile=$(mktemp "${TMPDIR:-/tmp}/espvm-rc.XXXXXX") || die "Error: Failed to create temp file"
    chmod 600 "$rc_tmpfile"
    [[ -f "$SHELL_RC" ]] && cat "$SHELL_RC" > "$rc_tmpfile"
    echo "" >> "$rc_tmpfile"
    echo "# espvm - ESP SDK Version Manager" >> "$rc_tmpfile"
    echo "$SOURCE_LINE" >> "$rc_tmpfile"
    if ! mv "$rc_tmpfile" "$SHELL_RC"; then
        rm -f "$rc_tmpfile"
        [[ -f "${SHELL_RC}.espvm.bak" ]] && cp "${SHELL_RC}.espvm.bak" "$SHELL_RC"
        die "Error: Failed to update $SHELL_RC"
    fi
    green "Added espvm to $SHELL_RC"
fi

echo ""
green "Installation complete!"
echo ""
echo "Run: source $SHELL_RC"
echo "Or restart your terminal."
echo ""
echo "Quick start:"
echo "  espvm i 5.4.1     Install ESP-IDF v5.4.1"
echo "  espvm 5.4.1        Activate ESP-IDF v5.4.1"
echo "  espvm -m i 1.4    Install ESP-Matter v1.4"
echo "  espvm status       Show active SDKs"