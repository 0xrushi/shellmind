# --- aiq: Interactive AI shell copilot (using command log DB) ---------------
aiq() {
  : "${HCOUNT:=10}"
  : "${AIQ_MAX_CTX:=2000}"

  # Check if --all flag is present
  local use_all_history=false
  local args=()
  for arg in "$@"; do
    if [ "$arg" = "--all" ]; then
      use_all_history=true
    else
      args+=("$arg")
    fi
  done

  local filter_terms=()
  for arg in "${args[@]}"; do
    if [ -n "$arg" ]; then
      filter_terms+=("$arg")
    fi
  done

  _filter_history_by_terms() {
    if [ "$#" -eq 0 ]; then
      cat
      return
    fi

    local sep=$'\034'
    local bundle=""
    local term=""
    for term in "$@"; do
      if [ -z "$term" ]; then
        continue
      fi
      if [ -n "$bundle" ]; then
        bundle+="$sep"
      fi
      bundle+="$term"
    done

    if [ -z "$bundle" ]; then
      cat
      return
    fi

    awk -v terms="$bundle" -v sep="$sep" '
BEGIN {
  count = split(terms, raw, sep);
  for (i = 1; i <= count; i++) {
    lowered[i] = tolower(raw[i]);
  }
}
{
  current = tolower($0);
  for (i = 1; i <= count; i++) {
    if (lowered[i] != "" && index(current, lowered[i]) > 0) {
      print $0;
      next;
    }
  }
}
'
  }

  _hist() {
    # Use query_commands.sh to get unique successful commands
    if command -v query_commands.sh >/dev/null 2>&1; then
      if [ "$use_all_history" = true ]; then
        local history
        history=$(query_commands.sh unique-recent-all 2>/dev/null || true)
        if [ -n "$history" ] && [ "${#filter_terms[@]}" -gt 0 ]; then
          local filtered
          filtered=$(printf '%s' "$history" | _filter_history_by_terms "${filter_terms[@]}")
          if [ -n "$filtered" ]; then
            printf '%s\n' "$filtered"
          else
            printf '%s\n' "$history"
          fi
        else
          printf '%s\n' "$history"
        fi
      else
        query_commands.sh unique-recent "$PWD" 2>/dev/null || true
      fi
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
    local payload
    payload=$(printf '[System] You are a concise shell assistant.\n[Rule] Output exactly one valid shell command. No markdown, no prose.\n[Context]\n%s\n%s\n[Recent History]\n' "$(_ctx_os)" "$(_ctx_pwd)")
    payload+=$(_hist)
    payload=$(printf '%s\n\nQuestion: %s\n' "$payload" "${args[*]}")

    # Debug mode: print system prompt if debug=True in environment
    local debug_flag="${debug:-${DEBUG:-}}"
    case "${debug_flag}" in
      [Tt][Rr][Uu][Ee]|1|[Yy][Ee][Ss])
        printf '\033[1;33m[DEBUG] System Prompt:\033[0m\n%s\n\033[1;33m[DEBUG] End of System Prompt\033[0m\n\n' "$payload" >&2
        ;;
    esac

    printf '%s' "$payload"
  }

  _clean_lines() {
    sed -E 's/^```[a-zA-Z]*//; s/```$//; s/^[[:space:]]+//; s/[[:space:]]+$//'
  }

  _ask_one() {
    _payload "${args[@]}" | aichat -e 2>/dev/null | _clean_lines | awk 'NF{print; exit}'
  }

  cmd="$(_ask_one "${args[@]}")"
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
