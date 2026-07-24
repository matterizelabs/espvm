#!/bin/bash
set -euo pipefail

ESPVM_INSTALL_DIR="${ESPVM_INSTALL_DIR:-$HOME/.local/bin}"
ESPVM_CONFIG_DIR="${ESPVM_CONFIG_DIR:-$HOME/.espressif/.espvm}"
ESPVM_WORKTREE_DIR="${ESPVM_WORKTREE_DIR:-}"
PURGE=0

red()   { printf '\033[0;31m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow(){ printf '\033[0;33m%s\033[0m\n' "$*"; }

die()   { red "$1"; exit 1; }

for arg in "$@"; do
    case "$arg" in
        --purge) PURGE=1 ;;
        -h|--help)
            cat <<EOF
Usage: bash uninstall.sh [--purge]

Removes the espvm tool from $ESPVM_INSTALL_DIR and the source line
from your shell rc file.

  --purge   Also remove espvm config ($ESPVM_CONFIG_DIR) and the
            worktree directory holding installed SDK versions.
            Destructive: deletes all installed ESP-IDF/ESP-Matter versions.
EOF
            exit 0 ;;
        *) die "Unknown option: $arg" ;;
    esac
done

# ── Remove binary ──

if [[ -f "$ESPVM_INSTALL_DIR/espvm" ]]; then
    rm -f "$ESPVM_INSTALL_DIR/espvm"
    green "Removed $ESPVM_INSTALL_DIR/espvm"
else
    yellow "espvm not found in $ESPVM_INSTALL_DIR"
fi

# ── Remove shell rc line ──

SHELL_RC="$HOME/.bashrc"
case "$(basename "${SHELL:-/bin/bash}")" in
    zsh)  SHELL_RC="$HOME/.zshrc" ;;
    fish) SHELL_RC="$HOME/.config/fish/config.fish" ;;
esac

if [[ -f "$SHELL_RC" ]] && grep -qE '^[[:space:]]*source[[:space:]]+[^#]*/espvm[[:space:]]*$' "$SHELL_RC"; then
    rc_tmpfile=$(mktemp "${TMPDIR:-/tmp}/espvm-uninstall.XXXXXX") || die "Error: Failed to create temp file"
    chmod 600 "$rc_tmpfile"
    # Remove only the source line and the marker comment install.sh added
    grep -vE '^[[:space:]]*source[[:space:]]+[^#]*/espvm[[:space:]]*$' "$SHELL_RC" \
        | grep -vF '# espvm - ESP SDK Version Manager' > "$rc_tmpfile" || true
    if mv "$rc_tmpfile" "$SHELL_RC"; then
        green "Removed espvm source line from $SHELL_RC"
    else
        rm -f "$rc_tmpfile"
        red "Error: Failed to update $SHELL_RC"
    fi
    rm -f "${SHELL_RC}.espvm.bak"
else
    yellow "No espvm line found in $SHELL_RC"
fi

# ── Optional purge ──

if [[ $PURGE -eq 1 ]]; then
    if [[ -z "$ESPVM_WORKTREE_DIR" && -f "$ESPVM_CONFIG_DIR/config" ]]; then
        ESPVM_WORKTREE_DIR=$(sed -n 's/^ESPVM_WORKTREE_DIR="\(.*\)"$/\1/p' "$ESPVM_CONFIG_DIR/config" 2>/dev/null || true)
    fi
    if [[ -n "$ESPVM_WORKTREE_DIR" && -d "$ESPVM_WORKTREE_DIR" ]]; then
        case "$ESPVM_WORKTREE_DIR" in
            /|/usr|/usr/*|/etc|/etc/*|/var|/var/*|/bin|/bin/*|/sbin|/sbin/*|/opt|/boot|/boot/*|"$HOME")
                die "Error: Refusing to purge unsafe worktree dir: $ESPVM_WORKTREE_DIR" ;;
        esac
        rm -rf -- "$ESPVM_WORKTREE_DIR"
        green "Removed worktree dir: $ESPVM_WORKTREE_DIR"
    fi
    if [[ -d "$ESPVM_CONFIG_DIR" ]]; then
        rm -rf "$ESPVM_CONFIG_DIR"
        green "Removed config dir: $ESPVM_CONFIG_DIR"
    fi
    green "Purge complete"
fi

echo ""
green "Uninstallation complete"
echo "Restart your terminal or run: source $SHELL_RC"
