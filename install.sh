#!/bin/bash
# espvm installer - curl -fsSL <url>/install.sh | bash

set -e

ESPVM_INSTALL_DIR="${ESPVM_INSTALL_DIR:-$HOME/.local/bin}"
ESPVM_SCRIPT_URL="${ESPVM_SCRIPT_URL:-https://raw.githubusercontent.com/matterizelabs/espvm/refs/heads/main/espvm}"

# Colors
red() { echo -e "\033[0;31m$1\033[0m"; }
green() { echo -e "\033[0;32m$1\033[0m"; }
yellow() { echo -e "\033[0;33m$1\033[0m"; }

echo "Installing espvm - ESP SDK Version Manager"
echo ""

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

# Add source line if not already present
SOURCE_LINE="source \"$ESPVM_INSTALL_DIR/espvm\""

if [[ -f "$SHELL_RC" ]] && grep -qF "espvm" "$SHELL_RC"; then
    yellow "espvm already configured in $SHELL_RC"
else
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
echo "Then try:"
echo "  espvm help               Show available commands"
echo "  espvm idf list-remote    List available ESP-IDF versions"
echo "  espvm idf install 5.4.1  Install ESP-IDF v5.4.1"
echo "  espvm idf use 5.4.1      Switch to v5.4.1"
