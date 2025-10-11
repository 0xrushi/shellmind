#!/bin/zsh

DB_FILE="${COMMAND_LOG_DB:-$HOME/.command_history.db}"
HISTORY_IMPORT_SENTINEL="${HISTORY_IMPORT_SENTINEL:-${DB_FILE}.imported}"

# Initialize database
init_db() {
    sqlite3 "$DB_FILE" <<EOF
CREATE TABLE IF NOT EXISTS command_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    username TEXT,
    hostname TEXT,
    working_dir TEXT,
    command TEXT NOT NULL,
    exit_code INTEGER,
    session_id TEXT
);

CREATE INDEX IF NOT EXISTS idx_timestamp ON command_log(timestamp);
CREATE INDEX IF NOT EXISTS idx_command ON command_log(command);
CREATE INDEX IF NOT EXISTS idx_session ON command_log(session_id);
EOF
}

# Initialize if not exists
[ ! -f "$DB_FILE" ] && init_db

sql_escape() {
    printf "%s" "$1" | sed "s/'/''/g"
}

append_insert() {
    local ts_raw="$1"
    local command="$2"
    local session="$3"

    # Skip empty or whitespace-only commands
    if [ -z "${command//[[:space:]]/}" ]; then
        return
    fi

    # Strip trailing carriage returns that sometimes appear in history files
    command=${command%$'\r'}

    local ts_sql
    if [ -n "$ts_raw" ] && [[ "$ts_raw" =~ ^[0-9]+$ ]]; then
        ts_sql="datetime($ts_raw, 'unixepoch')"
    else
        SHELLMIND_IMPORT_COUNTER=$((SHELLMIND_IMPORT_COUNTER + 1))
        ts_sql="datetime('now', '-${SHELLMIND_IMPORT_COUNTER} seconds')"
    fi

    local command_escaped
    command_escaped=$(sql_escape "$command")
    local session_escaped
    session_escaped=$(sql_escape "$session")
    IMPORT_INSERT_COUNT=$((IMPORT_INSERT_COUNT + 1))

    printf "INSERT INTO command_log (timestamp, username, hostname, working_dir, command, exit_code, session_id) VALUES (%s, '%s', '%s', NULL, '%s', NULL, '%s');\n" \
        "$ts_sql" "$USER_ESCAPED" "$HOST_ESCAPED" "$command_escaped" "$session_escaped" >>"$SQL_BUFFER"
}

import_zsh_history() {
    local hist_file="${1:-$HOME/.zsh_history}"
    [ -r "$hist_file" ] || return 0

    SQL_BUFFER=$(mktemp)
    printf "BEGIN;\n" >"$SQL_BUFFER"

    local session_id="import-zsh-$(date +%s)"
    local pending_ts=""
    local pending_cmd=""
    local line=""

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" == :\ * ]]; then
            if [ -n "$pending_cmd" ]; then
                append_insert "$pending_ts" "$pending_cmd" "$session_id"
            fi
            local payload="${line#: }"
            local ts_part="${payload%%;*}"
            pending_ts="${ts_part%%:*}"
            pending_cmd="${payload#*;}"
        else
            if [ -n "$pending_cmd" ]; then
                pending_cmd="${pending_cmd}"$'\n'"$line"
            elif [ -n "$line" ]; then
                pending_ts=""
                pending_cmd="$line"
            fi
        fi
    done <"$hist_file"

    if [ -n "$pending_cmd" ]; then
        append_insert "$pending_ts" "$pending_cmd" "$session_id"
    fi

    printf "COMMIT;\n" >>"$SQL_BUFFER"
    sqlite3 "$DB_FILE" <"$SQL_BUFFER"
    rm -f "$SQL_BUFFER"
}

import_bash_history() {
    local hist_file="${1:-$HOME/.bash_history}"
    [ -r "$hist_file" ] || return 0

    SQL_BUFFER=$(mktemp)
    printf "BEGIN;\n" >"$SQL_BUFFER"

    local session_id="import-bash-$(date +%s)"
    local line=""
    local last_ts=""

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" == \#\ * ]] && [[ "${line#\# }" =~ ^[0-9]+$ ]]; then
            last_ts="${line#\# }"
            continue
        fi

        if [ -n "$line" ]; then
            append_insert "$last_ts" "$line" "$session_id"
            last_ts=""
        fi
    done <"$hist_file"

    printf "COMMIT;\n" >>"$SQL_BUFFER"
    sqlite3 "$DB_FILE" <"$SQL_BUFFER"
    rm -f "$SQL_BUFFER"
}

maybe_import_existing_history() {
    # Skip if sqlite3 unavailable
    if ! command -v sqlite3 >/dev/null 2>&1; then
        return
    fi

    # Only import once per database
    if [ -f "$HISTORY_IMPORT_SENTINEL" ]; then
        return
    fi

    SHELLMIND_IMPORT_COUNTER=0
    IMPORT_INSERT_COUNT=0
    HOST_ESCAPED=$(sql_escape "${HOST:-$(hostname 2>/dev/null || printf 'unknown')}")
    USER_ESCAPED=$(sql_escape "${USER:-import}")

    import_zsh_history "$HOME/.zsh_history"
    import_bash_history "$HOME/.bash_history"

    if [ "${IMPORT_INSERT_COUNT:-0}" -gt 0 ]; then
        touch "$HISTORY_IMPORT_SENTINEL"
        printf 'ShellMind: imported %s historical commands into %s.\n' "$IMPORT_INSERT_COUNT" "$DB_FILE" >&2
    else
        # Ensure we don't re-run imports repeatedly when no history files exist
        touch "$HISTORY_IMPORT_SENTINEL"
    fi
}

maybe_import_existing_history

# Generate session ID
export SESSION_ID="${SESSION_ID:-$(date +%s)-$$}"

# Log command after execution (runs after each command)
precmd() {
    local exit_code=$?
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Get the last command from history
    local cmd=$(fc -ln -1)

    # Skip if empty or duplicate
    if [ -n "$cmd" ] && [ "$cmd" != "$LAST_LOGGED_CMD" ]; then
        # Trim whitespace
        cmd=$(echo "$cmd" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # Escape single quotes for SQL
        cmd=$(echo "$cmd" | sed "s/'/''/g")

        sqlite3 "$DB_FILE" "INSERT INTO command_log (timestamp, username, hostname, working_dir, command, exit_code, session_id) VALUES ('$timestamp', '$USER', '$HOST', '$PWD', '$cmd', $exit_code, '$SESSION_ID');"

        LAST_LOGGED_CMD="$cmd"
    fi
}

# Export for use in subshells
export DB_FILE
export SESSION_ID
