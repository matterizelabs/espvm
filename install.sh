#!/bin/bash
set -euo pipefail

ESPVM_INSTALL_DIR="${ESPVM_INSTALL_DIR:-$HOME/.local/bin}"
ESPVM_REPO="${ESPVM_REPO:-matterizelabs/espvm}"
ESPVM_SCRIPT_URL="${ESPVM_SCRIPT_URL:-}"
ESPVM_SHA256_URL="${ESPVM_SHA256_URL:-}"
ESPVM_SHA256_EXPECTED="${ESPVM_SHA256_EXPECTED:-}"
ESPVM_GPG_KEY="${ESPVM_GPG_KEY:-}"
ESPVM_COMMIT_REF="${ESPVM_COMMIT_REF:-}"
ESPVM_RELEASE_TAG="${ESPVM_RELEASE_TAG:-}"

red()   { printf '\033[0;31m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow(){ printf '\033[0;33m%s\033[0m\n' "$*"; }
info()  { printf '\033[0;34m%s\033[0m\n' "$*"; }

die()   { red "$1"; exit 1; }

_espvm_sha256() {
    if command -v sha256sum &>/dev/null; then sha256sum "$1" | cut -d' ' -f1
    elif command -v shasum &>/dev/null; then shasum -a 256 "$1" | cut -d' ' -f1
    elif command -v openssl &>/dev/null; then openssl dgst -sha256 "$1" | awk '{print $NF}'
    else echo ""
    fi
}

# ── Validate ──

command -v git &>/dev/null || die "Error: git is required"
command -v python3 &>/dev/null || die "Error: python3 is required"

# ── Resolve URLs ──
# Default: latest GitHub release. espvm fetched from raw <tag>/espvm,
# espvm.sha256 fetched from release asset. Both immutable, always in sync.

if [[ -z "$ESPVM_SCRIPT_URL" ]]; then
    if [[ -n "$ESPVM_COMMIT_REF" ]]; then
        [[ "$ESPVM_COMMIT_REF" =~ ^[a-zA-Z0-9._/-]+$ ]] || \
            die "Error: ESPVM_COMMIT_REF contains invalid characters: $ESPVM_COMMIT_REF"
        ref="$ESPVM_COMMIT_REF"
    else
        if [[ -n "$ESPVM_RELEASE_TAG" ]]; then
            ref="$ESPVM_RELEASE_TAG"
        else
            ref=$(curl -fsSL "https://api.github.com/repos/$ESPVM_REPO/releases/latest" \
                | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)
            [[ -n "$ref" ]] || die "Error: Could not determine latest release tag for $ESPVM_REPO"
        fi
        info "Using latest release: $ref"
    fi
    ESPVM_SCRIPT_URL="https://github.com/$ESPVM_REPO/releases/download/$ref/espvm"
    [[ -z "$ESPVM_SHA256_URL" ]] && \
        ESPVM_SHA256_URL="https://github.com/$ESPVM_REPO/releases/download/$ref/espvm.sha256"
fi
[[ -z "$ESPVM_SHA256_URL" ]] && ESPVM_SHA256_URL="${ESPVM_SCRIPT_URL}.sha256"

[[ "$ESPVM_SCRIPT_URL" == https://* || "$ESPVM_SCRIPT_URL" == file://* ]] || \
    die "Error: ESPVM_SCRIPT_URL must use HTTPS or file://: $ESPVM_SCRIPT_URL"
[[ "$ESPVM_SHA256_URL" == https://* || "$ESPVM_SHA256_URL" == file://* ]] || \
    die "Error: ESPVM_SHA256_URL must use HTTPS or file://: $ESPVM_SHA256_URL"

# ── Download ──

mkdir -p "$ESPVM_INSTALL_DIR"
info "Downloading espvm..."
dl_tmp=$(mktemp "${TMPDIR:-/tmp}/espvm-dl.XXXXXX") || die "Error: Failed to create temp file"
if command -v curl &>/dev/null; then
    curl -fsSL "$ESPVM_SCRIPT_URL" -o "$dl_tmp" || { rm -f "$dl_tmp"; die "Error: Download failed"; }
elif command -v wget &>/dev/null; then
    wget -qO "$dl_tmp" "$ESPVM_SCRIPT_URL" || { rm -f "$dl_tmp"; die "Error: Download failed"; }
else
    rm -f "$dl_tmp"
    die "Error: curl or wget is required"
fi
mv "$dl_tmp" "$ESPVM_INSTALL_DIR/espvm"

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
                red "Error: SHA-256 checksum mismatch with remote .sha256 file"
                red "  Remote: $remote_hash"
                red "  Actual: $actual_hash"
                rm -f "$ESPVM_INSTALL_DIR/espvm" "$sha256_file"
                exit 1
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
        keyring=$(mktemp "${TMPDIR:-/tmp}/espvm-keyring.XXXXXX" 2>/dev/null) || keyring=""
        if [[ -n "$sig_file" && -n "$keyring" ]]; then
            info "Verifying GPG signature with key $ESPVM_GPG_KEY..."
            if curl -fsSL "$sig_url" -o "$sig_file" 2>/dev/null; then
                if [[ -f "$ESPVM_GPG_KEY" ]]; then
                    gpg --no-default-keyring --keyring "$keyring" --import "$ESPVM_GPG_KEY" 2>/dev/null
                else
                    gpg --no-default-keyring --keyring "$keyring" --recv-keys "$ESPVM_GPG_KEY" 2>/dev/null
                fi
                if gpg --no-default-keyring --keyring "$keyring" --verify "$sig_file" "$ESPVM_INSTALL_DIR/espvm" 2>/dev/null; then
                    green "GPG signature verified with key $ESPVM_GPG_KEY"
                else
                    rm -f "$ESPVM_INSTALL_DIR/espvm" "$sig_file" "$keyring"
                    die "Error: GPG signature verification failed!"
                fi
            else
                yellow "Warning: Could not download GPG signature file"
            fi
            rm -f "$sig_file" "$keyring"
        fi
    else
        yellow "Warning: ESPVM_GPG_KEY is set but gpg is not installed. Skipping."
    fi
fi

# ── Install ──

chmod +x "$ESPVM_INSTALL_DIR/espvm"
green "espvm installed to $ESPVM_INSTALL_DIR/espvm"

# ── Configure shell ──

shell_name="$(basename "${SHELL:-/bin/bash}")"
if [[ "$shell_name" == "fish" ]]; then
    yellow "fish shell is not supported by espvm (bash >= 4 or zsh required)."
    yellow "espvm was installed to $ESPVM_INSTALL_DIR/espvm but your shell rc was not modified."
    exit 0
fi

SHELL_RC="$HOME/.bashrc"
case "$shell_name" in
    zsh)  SHELL_RC="$HOME/.zshrc" ;;
    bash)
        # macOS bash login shells read .bash_profile, not .bashrc
        if [[ "$(uname -s 2>/dev/null)" == "Darwin" && -f "$HOME/.bash_profile" ]]; then
            SHELL_RC="$HOME/.bash_profile"
        fi ;;
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
info "Run: source $SHELL_RC"
info "Or restart your terminal."
echo ""
info "Quick start:"
echo "  espvm i 5.4.1     Install ESP-IDF v5.4.1"
echo "  espvm 5.4.1        Activate ESP-IDF v5.4.1"
echo "  espvm -m i 1.4    Install ESP-Matter v1.4"
echo "  espvm status       Show active SDKs"