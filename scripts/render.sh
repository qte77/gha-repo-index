#!/bin/bash
set -euo pipefail
# Render cards + table from metadata

HERO_TEXT="You're paying exploration tokens repeatedly for context that changes infrequently."

# Render a per-repo card from JSON metadata.
# Args: $1 = JSON string with repo metadata
render_card() {
  local meta="$1"
  local name desc langs topics pushed key_files ptype stars forks license status

  name=$(echo "$meta" | jq -r '.name')
  desc=$(echo "$meta" | jq -r '.description // ""')
  langs=$(echo "$meta" | jq -r '(.languages // []) | join(", ")')
  topics=$(echo "$meta" | jq -r '(.topics // []) | join(", ")')
  pushed=$(echo "$meta" | jq -r '.pushedAt // "" | split("T")[0]')
  key_files=$(echo "$meta" | jq -r '(.keyFiles // []) | join(", ")')
  ptype=$(echo "$meta" | jq -r '.projectType // ""')
  stars=$(echo "$meta" | jq -r '.stargazerCount // 0')
  forks=$(echo "$meta" | jq -r '.forkCount // 0')
  license=$(echo "$meta" | jq -r '.license // ""')
  status=$(echo "$meta" | jq -r 'if .isArchived then "archived" else "active" end')

  cat <<EOF
---
name: $name
status: $status
languages: [${langs}]
topics: [${topics}]
last_push: $pushed
---
**${name}** — ${desc}

- **Languages**: ${langs:-—}
- **Topics**: ${topics:-—}
- **Key files**: ${key_files:-—}
- **Type**: ${ptype:-—}
- **Stars**: ${stars} | **Forks**: ${forks} | **License**: ${license:-—}
EOF
}

# Render overview table from JSON array of repos.
# Args: $1 = JSON array
render_table() {
  local repos="$1"

  # Header
  echo "| Repo | Description | Languages | Type | Last Push |"
  echo "|------|-------------|-----------|------|-----------|"

  # Rows sorted by pushedAt descending
  echo "$repos" | jq -r '
    sort_by(.pushedAt) | reverse | .[] |
    "| [\(.name)](\(.url)) | \(.description // "") | \(.primaryLanguage // "—") | \(.projectType // "—") | \(.pushedAt | split("T")[0]) |"
  '
}

# Render combined REPO_REGISTRY.md.
# Args: $1 = table content, $2 = cards content (optional)
render_registry_md() {
  local table="$1"
  local cards="${2:-}"

  cat <<EOF
# Repo Registry

> ${HERO_TEXT}

This registry provides structured metadata for all repos.
Agents: read this file instead of exploring repos from scratch.

## Overview

${table}
EOF

  if [[ -n "$cards" ]]; then
    cat <<EOF

## Detail Cards

${cards}
EOF
  fi
}
