#!/bin/bash

DB_FILE="${COMMAND_LOG_DB:-$HOME/.command_history.db}"

case "$1" in
    recent)
        # Show last 20 commands with directory
        sqlite3 -column -header "$DB_FILE" "SELECT timestamp, working_dir, command, exit_code FROM command_log ORDER BY id DESC LIMIT ${2:-20};"
        ;;
    failed)
        # Show failed commands
        sqlite3 -column -header "$DB_FILE" "SELECT timestamp, working_dir, command, exit_code FROM command_log WHERE exit_code != 0 ORDER BY id DESC LIMIT ${2:-20};"
        ;;
    search)
        # Search for commands containing a string
        sqlite3 -column -header "$DB_FILE" "SELECT timestamp, working_dir, command, exit_code FROM command_log WHERE command LIKE '%$2%' ORDER BY id DESC LIMIT 50;"
        ;;
    dir)
        # Show commands from a specific directory
        search_dir="${2:-$PWD}"
        sqlite3 -column -header "$DB_FILE" "SELECT timestamp, command, exit_code FROM command_log WHERE working_dir = '$search_dir' ORDER BY id DESC LIMIT 50;"
        ;;
    dirs)
        # Show all directories you've run commands in
        sqlite3 -column -header "$DB_FILE" "SELECT DISTINCT working_dir, COUNT(*) as command_count FROM command_log GROUP BY working_dir ORDER BY command_count DESC;"
        ;;
    unique)
        # Show unique successful commands from current or specified directory
        search_dir="${2:-$PWD}"
        sqlite3 "$DB_FILE" "SELECT DISTINCT command FROM command_log WHERE working_dir = '$search_dir' AND exit_code = 0 ORDER BY command;"
        ;;
    unique-recent)
        # Show unique successful commands ordered by most recent
        search_dir="${2:-$PWD}"
        sqlite3 "$DB_FILE" "SELECT command FROM command_log WHERE working_dir = '$search_dir' AND exit_code = 0 GROUP BY command ORDER BY MAX(id) DESC;"
        ;;
    stats)
        # Show statistics
        sqlite3 -column -header "$DB_FILE" "
        SELECT
            COUNT(*) as total_commands,
            SUM(CASE WHEN exit_code = 0 THEN 1 ELSE 0 END) as successful,
            SUM(CASE WHEN exit_code != 0 THEN 1 ELSE 0 END) as failed,
            COUNT(DISTINCT session_id) as sessions,
            COUNT(DISTINCT working_dir) as directories
        FROM command_log;"
        ;;
    today)
        # Show today's commands
        sqlite3 -column -header "$DB_FILE" "SELECT timestamp, working_dir, command, exit_code FROM command_log WHERE DATE(timestamp) = DATE('now') ORDER BY id DESC;"
        ;;
    export)
        # Export to CSV
        sqlite3 -header -csv "$DB_FILE" "SELECT * FROM command_log ORDER BY id DESC;" > command_history_export.csv
        echo "Exported to command_history_export.csv"
        ;;
    *)
        echo "Usage: query_commands.sh [recent|failed|search|dir|dirs|unique|unique-recent|stats|today|export] [args]"
        echo ""
        echo "Examples:"
        echo "  query_commands.sh unique              # Unique successful commands (current dir, alphabetical)"
        echo "  query_commands.sh unique /path/dir    # Unique successful commands (specific dir)"
        echo "  query_commands.sh unique-recent       # Unique successful commands (current dir, by recency)"
        echo "  query_commands.sh recent 50           # Last 50 commands with directories"
        echo "  query_commands.sh failed              # Failed commands"
        echo "  query_commands.sh search docker       # Search for 'docker' commands"
        echo "  query_commands.sh dir /home/user/code # Commands run in specific directory"
        echo "  query_commands.sh dir                 # Commands run in current directory"
        echo "  query_commands.sh dirs                # List all directories with command counts"
        echo "  query_commands.sh stats               # Show statistics"
        echo "  query_commands.sh today               # Today's commands"
        echo "  query_commands.sh export              # Export to CSV"
        ;;
esac
