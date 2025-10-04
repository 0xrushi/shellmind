# ShellMind Example Queries

This document provides practical examples of using ShellMind's command history database and AI copilot.

## Command History Queries

### Basic History Viewing

```bash
# View your last 20 commands
query_commands.sh recent

# View your last 100 commands
query_commands.sh recent 100
```

Example output:
```
timestamp            working_dir              command                 exit_code
-------------------  -----------------------  ----------------------  ---------
2025-10-04 16:30:15  /home/user/projects      git status              0
2025-10-04 16:29:42  /home/user/projects      npm test                0
2025-10-04 16:28:11  /home/user/projects      docker ps               0
```

### Finding Failed Commands

```bash
# See which commands failed recently
query_commands.sh failed

# See last 50 failed commands
query_commands.sh failed 50
```

This helps you quickly identify and fix commands that didn't work.

### Searching Command History

```bash
# Find all docker commands you've run
query_commands.sh search docker

# Find all git commands
query_commands.sh search git

# Find all npm commands
query_commands.sh search npm
```

Example output:
```
timestamp            working_dir              command                      exit_code
-------------------  -----------------------  ---------------------------  ---------
2025-10-04 16:28:11  /home/user/projects      docker ps                    0
2025-10-04 15:42:33  /home/user/projects      docker-compose up -d         0
2025-10-04 14:15:22  /home/user/backend       docker build -t myapp .      0
```

### Directory-Specific Commands

```bash
# See all commands you ran in current directory
query_commands.sh dir

# See commands from a specific project
query_commands.sh dir /home/user/projects/myapp

# List all directories where you've run commands
query_commands.sh dirs
```

Example output for `dirs`:
```
working_dir                      command_count
-------------------------------  -------------
/home/user/projects/myapp        342
/home/user/dotfiles              156
/home/user/scripts               89
```

### Unique Commands

```bash
# Get unique successful commands from current directory
query_commands.sh unique

# Get unique commands from specific directory
query_commands.sh unique /home/user/projects

# Get unique commands ordered by most recent usage
query_commands.sh unique-recent
```

This is useful for seeing what commands are available in a project without duplicates.

### Statistics

```bash
# View your command usage statistics
query_commands.sh stats
```

Example output:
```
total_commands  successful  failed  sessions  directories
--------------  ----------  ------  --------  -----------
5234            5102        132     89        23
```

### Today's Commands

```bash
# See everything you've done today
query_commands.sh today
```

Great for end-of-day review or daily standup preparation.

### Export History

```bash
# Export your entire history to CSV
query_commands.sh export
```

Creates `command_history_export.csv` for analysis in spreadsheets or other tools.

## AI Copilot Examples

### File Operations

```bash
# Find files
aiq find all pdf files

# Suggested: find . -name "*.pdf"

aiq show me large files over 100MB

# Suggested: find . -type f -size +100M -exec ls -lh {} \;

aiq count lines in all python files

# Suggested: find . -name "*.py" -exec wc -l {} + | tail -1
```

### Git Operations

```bash
aiq show me commits from last week

# Suggested: git log --since="1 week ago" --oneline

aiq create a new branch for feature X

# Suggested: git checkout -b feature/X

aiq undo my last commit but keep the changes

# Suggested: git reset --soft HEAD~1
```

### Docker Operations

```bash
aiq stop all running containers

# Suggested: docker stop $(docker ps -q)

aiq remove unused docker images

# Suggested: docker image prune -a

aiq show container logs

# Suggested: docker logs <container_name>
```

### System Monitoring

```bash
aiq show me disk usage

# Suggested: df -h

aiq find processes using most memory

# Suggested: ps aux --sort=-%mem | head -10

aiq check which process is using port 8080

# Suggested: lsof -i :8080
```

### Text Processing

```bash
aiq count unique ip addresses in access.log

# Suggested: awk '{print $1}' access.log | sort -u | wc -l

aiq extract all email addresses from file.txt

# Suggested: grep -Eo '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b' file.txt

aiq replace all occurrences of foo with bar in all js files

# Suggested: find . -name "*.js" -exec sed -i 's/foo/bar/g' {} \;
```

### Archive Operations

```bash
aiq compress this directory

# Suggested: tar -czf archive.tar.gz .

aiq extract that tar.gz file

# Suggested: tar -xzf archive.tar.gz

aiq create a zip file of all images

# Suggested: zip images.zip *.jpg *.png *.gif
```

### Network Operations

```bash
aiq check if port 80 is open

# Suggested: nc -zv localhost 80

aiq download file from url

# Suggested: wget <url>

aiq what is my public ip

# Suggested: curl ifconfig.me
```

## Pro Tips

### Combining Queries

```bash
# Find failed docker commands
query_commands.sh failed | grep docker

# Search commands in a specific directory from today
query_commands.sh today | grep "/home/user/myproject"

# Export and analyze
query_commands.sh export
# Then open command_history_export.csv in your favorite tool
```

### Using with Other Tools

```bash
# Pipe to fzf for interactive search
query_commands.sh recent 1000 | fzf

# Get command ideas for current project
query_commands.sh unique-recent | head -20

# Track your most used commands
sqlite3 ~/.command_history.db "SELECT command, COUNT(*) as count FROM command_log GROUP BY command ORDER BY count DESC LIMIT 10;"
```

### AI Copilot Best Practices

1. **Be specific about context**: "in this directory", "for python files", etc.
2. **Ask for what you want to achieve**, not the exact command
3. **Review before executing**: Always check the suggested command makes sense
4. **Learn from suggestions**: The AI uses your history, so it adapts to your style

### Custom Queries

You can also query the database directly:

```bash
# Find commands you ran on weekends
sqlite3 ~/.command_history.db "SELECT * FROM command_log WHERE strftime('%w', timestamp) IN ('0','6');"

# Find your longest running session
sqlite3 ~/.command_history.db "SELECT session_id, COUNT(*) as commands FROM command_log GROUP BY session_id ORDER BY commands DESC LIMIT 1;"

# Commands you always run successfully
sqlite3 ~/.command_history.db "SELECT command, COUNT(*) as runs FROM command_log WHERE exit_code = 0 GROUP BY command HAVING runs > 10 ORDER BY runs DESC;"
```

## Environment Variables

Customize behavior with environment variables:

```bash
# Use a different database location
export COMMAND_LOG_DB="$HOME/my_custom_history.db"

# Show more history to AI (default: 10)
export HCOUNT=20

# Increase AI context size (default: 2000)
export AIQ_MAX_CTX=4000
```

Add these to your `~/.zshrc` to make them permanent.

> **Note**: ShellMind only works with Zsh shell.
