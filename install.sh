#!/bin/bash

set -e

SHELLMIND_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION="$(cat "${SHELLMIND_DIR}/VERSION" 2>/dev/null || echo "dev")"

echo "Installing ShellMind - Command History Database + AI Copilot"
echo "=============================================================="
echo "Version: ${VERSION}"
echo ""
echo "⚠️  WARNING: ShellMind only works with Zsh shell."
echo "    It will NOT work with Bash or other shells."
echo ""

# Determine install location
INSTALL_DIR="${HOME}/.local/bin"

# Create install directory if it doesn't exist
mkdir -p "$INSTALL_DIR"

# Copy scripts to ~/.local/bin
echo "Installing scripts to ${INSTALL_DIR}..."
cp "${SHELLMIND_DIR}/bin/setup_command_logging.sh" "$INSTALL_DIR/"
cp "${SHELLMIND_DIR}/bin/query_commands.sh" "$INSTALL_DIR/"
chmod +x "${INSTALL_DIR}/setup_command_logging.sh"
chmod +x "${INSTALL_DIR}/query_commands.sh"

# Detect shell configuration file
if [ -n "$ZSH_VERSION" ] || [ -f "$HOME/.zshrc" ]; then
    SHELL_RC="$HOME/.zshrc"
    SHELL_NAME="zsh"
else
    echo "❌ ERROR: Zsh not detected!"
    echo "   ShellMind requires Zsh and will not work with Bash or other shells."
    echo "   Please install Zsh and try again."
    exit 1
fi

echo "Detected shell: $SHELL_NAME"
echo "Shell config: $SHELL_RC"

# Check if already installed
if grep -q "shellmind" "$SHELL_RC" 2>/dev/null; then
    echo "ShellMind appears to be already configured in $SHELL_RC"
    echo "Skipping configuration update."
else
    echo "Adding ShellMind configuration to $SHELL_RC..."
    cat >> "$SHELL_RC" <<'EOF'

# ShellMind - Command History Database + AI Copilot
export PATH="$HOME/.local/bin:$PATH"
export COMMAND_LOG_DB="$HOME/.command_history.db"

# Source command logging for zsh
if [ -n "$ZSH_VERSION" ]; then
    source "$HOME/.local/bin/setup_command_logging.sh"
fi

# Source aiq function
if [ -f "$HOME/.local/bin/aiq.zsh" ]; then
    source "$HOME/.local/bin/aiq.zsh"
fi
EOF
fi

# Copy aiq.zsh to ~/.local/bin
echo "Installing aiq function..."
cp "${SHELLMIND_DIR}/zsh/aiq.zsh" "${INSTALL_DIR}/aiq.zsh"

# Initialize database
echo "Initializing command history database..."
if command -v sqlite3 >/dev/null 2>&1; then
    bash "${INSTALL_DIR}/setup_command_logging.sh"
    echo "Database initialized at ${HOME}/.command_history.db"
else
    echo "Warning: sqlite3 not found. Please install sqlite3 to use ShellMind."
    echo "  Ubuntu/Debian: sudo apt install sqlite3"
    echo "  macOS: brew install sqlite3"
    echo "  Arch: sudo pacman -S sqlite"
fi

# Check for aichat
if ! command -v aichat >/dev/null 2>&1; then
    echo ""
    echo "Warning: aichat not found. The 'aiq' AI copilot feature requires aichat."
    echo "Install aichat: https://github.com/sigoden/aichat"
    echo ""
fi

echo ""
echo "Installation complete!"
echo ""
echo "Please restart your shell or run:"
echo "  source $SHELL_RC"
echo ""
echo "Available commands:"
echo "  query_commands.sh [command]  - Query your command history"
echo "  aiq [question]               - AI shell copilot"
echo ""
echo "Examples:"
echo "  query_commands.sh recent"
echo "  query_commands.sh stats"
echo "  aiq find all pdf files in current directory"
echo ""
