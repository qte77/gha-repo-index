#!/bin/bash
set -euo pipefail
# Shared helpers for gha-repo-index

# Build repo list from INPUT_REPOS (comma-separated) or auto-discover from INPUT_OWNER.
# Outputs one repo per line (owner/name).
build_repo_list() {
  if [[ -n "${INPUT_REPOS:-}" ]]; then
    IFS=',' read -ra repos <<< "$INPUT_REPOS"
    for repo in "${repos[@]}"; do
      repo=$(echo "$repo" | xargs)
      [[ -n "$repo" ]] && echo "$repo"
    done
  elif [[ -n "${INPUT_OWNER:-}" ]]; then
    gh repo list "$INPUT_OWNER" --limit 200 --json nameWithOwner --jq '.[].nameWithOwner'
  fi
}

# Split owner/name into components.
# Usage: split_repo "owner/name" "owner|name"
split_repo() {
  local repo="$1"
  local part="$2"
  case "$part" in
    owner) echo "${repo%%/*}" ;;
    name)  echo "${repo##*/}" ;;
  esac
}

# Return ISO date N days ago. Defaults to 7.
# Cross-platform: handles Linux (date -d) and macOS (date -v).
days_ago() {
  local n="${1:-7}"
  date -d "$n days ago" +%Y-%m-%d 2>/dev/null \
    || date -v-"${n}"d +%Y-%m-%d
}
