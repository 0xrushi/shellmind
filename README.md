# ShellMind

**Command History Database + AI Copilot**

ShellMind enhances your shell experience by logging all commands to a SQLite database and providing an AI-powered copilot for intelligent command suggestions based on your history.

## Features

- **Persistent Command History Database**: Store all shell commands in a searchable SQLite database
- **Context-Aware Logging**: Track commands with timestamps, working directory, exit codes, and session info
- **Powerful Query Interface**: Search and analyze your command history with flexible queries
- **AI Copilot (`aiq`)**: Get intelligent command suggestions based on your history and context
- **Cross-Session History**: Access commands across different shell sessions
- **Directory-Aware**: View commands specific to directories or projects

## Installation

### Prerequisites

- `sqlite3` - for command history database
- `aichat` - for AI copilot feature (optional but recommended)
  - Install from: https://github.com/sigoden/aichat

### Quick Install

```bash
git clone https://github.com/shellmind/shellmind.git
cd shellmind
./install.sh
```

Then restart your shell or run:
```bash
source ~/.zshrc  # or ~/.bashrc for bash
```

## Usage

### Command History Queries

Query your command history with various filters:

```bash
# Show recent commands
query_commands.sh recent

# Show last 50 commands
query_commands.sh recent 50

# Show failed commands
query_commands.sh failed

# Search for specific commands
query_commands.sh search docker

# Show commands from current directory
query_commands.sh dir

# Show commands from specific directory
query_commands.sh dir /path/to/project

# List all directories with command counts
query_commands.sh dirs

# Show unique successful commands (current dir)
query_commands.sh unique

# Show statistics
query_commands.sh stats

# Show today's commands
query_commands.sh today

# Export history to CSV
query_commands.sh export
```

### AI Copilot (`aiq`)

Ask natural language questions to get command suggestions:

```bash
# Get command suggestions based on your question
aiq find all pdf files

# The AI will suggest a command based on:
# - Your recent command history
# - Current working directory
# - Operating system context
```

The `aiq` function will:
1. Analyze your recent command history from the database
2. Consider your current context (PWD, OS)
3. Generate an appropriate shell command
4. Ask for confirmation before executing

## Architecture

```
shellmind/
├── README.md                          # This file
├── LICENSE                            # MIT License
├── install.sh                         # Installation script
├── bin/
│   ├── setup_command_logging.sh      # Initialize DB and logging hooks
│   └── query_commands.sh             # Query interface for command history
├── zsh/
│   └── aiq.zsh                       # AI copilot function
└── examples/
    └── example_queries.md            # Usage examples
```

### Database Schema

```sql
CREATE TABLE command_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    username TEXT,
    hostname TEXT,
    working_dir TEXT,
    command TEXT NOT NULL,
    exit_code INTEGER,
    session_id TEXT
);
```

## Configuration

Environment variables:

- `COMMAND_LOG_DB`: Path to SQLite database (default: `~/.command_history.db`)
- `HCOUNT`: Number of history commands to show to AI (default: 10)
- `AIQ_MAX_CTX`: Max context size for AI queries (default: 2000)

## How It Works

1. **Command Logging**: The `precmd` hook in zsh captures every command after execution
2. **Database Storage**: Commands are stored with metadata in SQLite
3. **Query Interface**: `query_commands.sh` provides various query modes
4. **AI Integration**: `aiq` sends context + history to `aichat` for intelligent suggestions

## Examples

See [examples/example_queries.md](examples/example_queries.md) for detailed usage examples.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Contributing

Contributions welcome! Please open an issue or pull request.

## Credits

Built with:
- [SQLite](https://www.sqlite.org/) - Command history database
- [aichat](https://github.com/sigoden/aichat) - AI CLI interface
