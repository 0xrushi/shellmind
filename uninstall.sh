#!/bin/bash

set -e

echo "Uninstalling ShellMind"
echo "======================="

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION="$(cat "${SCRIPT_DIR}/VERSION" 2>/dev/null || echo "dev")"
echo "Version: ${VERSION}"

INSTALL_DIR="${HOME}/.local/bin"
SHELL_RC="${HOME}/.zshrc"
DB_FILE="${COMMAND_LOG_DB:-$HOME/.command_history.db}"
SENTINEL_FILE="${HISTORY_IMPORT_SENTINEL:-${DB_FILE}.imported}"

remove_file() {
  local file_path="$1"
  if [ -f "$file_path" ]; then
    rm "$file_path"
    echo "Removed $file_path"
  fi
}

remove_shellmind_block() {
  local rc_path="$1"
  if [ ! -f "$rc_path" ]; then
    return
  fi

  if ! grep -q "# ShellMind - Command History Database + AI Copilot" "$rc_path" 2>/dev/null; then
    return
  fi

  if command -v python3 >/dev/null 2>&1; then
    result=$(python3 - "$rc_path" <<'PYTHON'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
content = path.read_text()

pattern = re.compile(
    r'\n?# ShellMind - Command History Database \+ AI Copilot\n'
    r'export PATH="\$HOME/\.local/bin:\$PATH"\n'
    r'export COMMAND_LOG_DB="\$HOME/\.command_history\.db"\n\n'
    r'# Source command logging for zsh\n'
    r'if \[ -n "\$ZSH_VERSION" \]; then\n'
    r'\s*source "\$HOME/\.local/bin/setup_command_logging\.sh"\n'
    r'fi\n\n'
    r'# Source aiq function\n'
    r'if \[ -f "\$HOME/\.local/bin/aiq\.zsh" \]; then\n'
    r'\s*source "\$HOME/\.local/bin/aiq\.zsh"\n'
    r'fi\n?',
    re.MULTILINE,
)

updated, count = pattern.subn("\n", content, count=1)
if count:
    while "\n\n\n" in updated:
        updated = updated.replace("\n\n\n", "\n\n")
    path.write_text(updated.rstrip() + "\n")
    print("REMOVED", end="")
else:
    print("SKIP", end="")
PYTHON
)
    if [ "$result" = "REMOVED" ]; then
      echo "Removed ShellMind configuration from ${rc_path}"
    else
      echo "ShellMind configuration not found in ${rc_path}"
    fi
  else
    echo "python3 is not available; please remove the ShellMind block from ${rc_path} manually."
  fi
}

echo ""
echo "Removing executables from ${INSTALL_DIR}..."
remove_file "${INSTALL_DIR}/setup_command_logging.sh"
remove_file "${INSTALL_DIR}/query_commands.sh"
remove_file "${INSTALL_DIR}/aiq.zsh"

echo ""
echo "Cleaning shell configuration..."
remove_shellmind_block "${SHELL_RC}"

echo ""
if [ -f "$DB_FILE" ]; then
  read -r -p "Delete command history database at ${DB_FILE}? [y/N] " confirm_db
  case "$confirm_db" in
    [yY][eE][sS]|[yY])
      rm "$DB_FILE"
      echo "Deleted ${DB_FILE}"
      ;;
    *)
      echo "Kept ${DB_FILE}"
      ;;
  esac
fi

if [ -f "$SENTINEL_FILE" ]; then
  rm "$SENTINEL_FILE"
  echo "Removed ${SENTINEL_FILE}"
fi

rm -f "${DB_FILE}-wal" "${DB_FILE}-shm" 2>/dev/null || true

echo ""
echo "ShellMind uninstalled."
echo "Restart your shell or run: source ${SHELL_RC}"
