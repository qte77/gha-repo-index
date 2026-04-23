#!/bin/bash
# Mock gh CLI for deterministic testing.
# Adapted from gha-cross-repo-issue-sync/tests/test_helper/gh_mock.bash

GH_MOCK_LOG="${GH_MOCK_LOG:-/tmp/gha-repo-index-gh-mock.log}"

gh() {
  echo "gh $*" >> "$GH_MOCK_LOG"

  # Fail injection
  if [[ -n "${GH_MOCK_FAIL_CMD:-}" ]] && echo "$*" | grep -q "$GH_MOCK_FAIL_CMD"; then
    return 1
  fi

  case "$*" in
    "repo list"*)
      if [[ -n "${GH_MOCK_REPO_LIST_JSON:-}" ]]; then
        cat "$GH_MOCK_REPO_LIST_JSON"
      else
        echo "[]"
      fi
      ;;
    "api repos/"*"/contents"*)
      if [[ -n "${GH_MOCK_CONTENTS_JSON:-}" ]]; then
        cat "$GH_MOCK_CONTENTS_JSON"
      else
        echo "[]"
      fi
      ;;
    "api repos/"*"/readme"*)
      if [[ -n "${GH_MOCK_README_JSON:-}" ]]; then
        cat "$GH_MOCK_README_JSON"
      else
        echo '{"content":""}'
      fi
      ;;
    *)
      echo "gh mock: unhandled command: $*" >&2
      ;;
  esac
}

# Helper: count gh calls
gh_calls() {
  cat "$GH_MOCK_LOG" 2>/dev/null || true
}

# Helper: check if a specific command was called
gh_called_with() {
  grep -q "$1" "$GH_MOCK_LOG" 2>/dev/null
}

export -f gh gh_calls gh_called_with
