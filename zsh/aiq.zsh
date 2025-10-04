# --- aiq: Interactive AI shell copilot (using command log DB) ---------------
aiq() {
  : "${HCOUNT:=10}"
  : "${AIQ_MAX_CTX:=2000}"

  _hist() {
    # Use query_commands.sh to get unique successful commands from current directory
    if command -v query_commands.sh >/dev/null 2>&1; then
      query_commands.sh unique-recent "$PWD" 2>/dev/null || true
    else
      # Fallback to regular history if query_commands.sh not available
      if command -v fc >/dev/null 2>&1; then
        fc -ln -"${HCOUNT}" 2>/dev/null | grep -vE '^\s*aiq(\s|$)' || true
      elif [ -n "${HISTFILE:-}" ] && [ -r "$HISTFILE" ]; then
        tail -n "${HCOUNT}" -- "$HISTFILE" 2>/dev/null | grep -vE '^\s*aiq(\s|$)' || true
      fi
    fi
  }

  _ctx_pwd() { printf 'PWD: %s\n' "$(pwd)"; }
  _ctx_os()  { printf 'OS: %s\n' "$(uname -s)"; }

  _payload() {
    printf '[System] You are a concise shell assistant.\n'
    printf '[Rule] Output exactly one valid shell command. No markdown, no prose.\n'
    printf '[Context]\n%s\n%s\n' "$(_ctx_os)" "$(_ctx_pwd)"
    printf '[Recent History]\n'
    _hist
    printf '\nQuestion: %s\n' "$*"
  }

  _clean_lines() {
    sed -E 's/^```[a-zA-Z]*//; s/```$//; s/^[[:space:]]+//; s/[[:space:]]+$//'
  }

  _ask_one() {
    _payload "$@" | aichat -e 2>/dev/null | _clean_lines | awk 'NF{print; exit}'
  }

  cmd="$(_ask_one "$@")"
  if [ -z "$cmd" ]; then
    printf 'No command returned.\n' >&2
    return 1
  fi

  printf '\033[1;32mSuggested command:\033[0m %s\n' "$cmd"
  printf 'Run this command? [y/N] '
  read -r confirm
  if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
    printf '\033[1;34mRunning...\033[0m\n'
    # Execute in current shell instead of subshell
    eval "$cmd"
  else
    printf 'Aborted.\n'
  fi

  # --------- remove aiq from shell history ---------
  if [ -n "$BASH_VERSION" ]; then
    # Remove last command (aiq invocation) from in-memory history
    history -d $((HISTCMD-1)) 2>/dev/null || true
    # Optional: don't record future aiq invocations at all
    export HISTIGNORE="aiq *:$HISTIGNORE"
  elif [ -n "$ZSH_VERSION" ]; then
    # Delete last history entry if it starts with "aiq"
    fc -p >/dev/null  # isolate private history session
    BUFFER=""
    zle && zle reset-prompt >/dev/null 2>&1 || true
  fi
}
# ---------------------------------------------------------------------------
