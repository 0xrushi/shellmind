#!/bin/zsh

DB_FILE="${COMMAND_LOG_DB:-$HOME/.command_history.db}"

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
