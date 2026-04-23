#!/bin/bash
set -euo pipefail
# Bulk metadata collection + per-repo structure extraction

# Key files that indicate project type or are useful for agent context
KEY_FILE_PATTERNS=(
  "CLAUDE.md" "action.yaml" "action.yml"
  "Cargo.toml" "pyproject.toml" "package.json" "go.mod"
  "Dockerfile" "Makefile" ".devcontainer"
)

# Fetch bulk metadata for all repos of an owner.
# Filters archived/forked repos based on INPUT_INCLUDE_* env vars.
# Args: $1 = owner
collect_bulk_metadata() {
  local owner="$1"
  local raw
  raw=$(gh repo list "$owner" --limit 200 --json \
    name,nameWithOwner,description,primaryLanguage,languages,repositoryTopics,\
pushedAt,createdAt,isArchived,isFork,isTemplate,visibility,\
defaultBranchRef,stargazerCount,forkCount,licenseInfo,diskUsage,url)

  # Filter archived
  if [[ "${INPUT_INCLUDE_ARCHIVED:-false}" != "true" ]]; then
    raw=$(echo "$raw" | jq '[.[] | select(.isArchived == false)]')
  fi

  # Filter forks
  if [[ "${INPUT_INCLUDE_FORKS:-false}" != "true" ]]; then
    raw=$(echo "$raw" | jq '[.[] | select(.isFork == false)]')
  fi

  echo "$raw"
}

# Fetch per-repo supplementary metadata: file tree, key files, project type, README excerpt.
# Args: $1 = owner/name
collect_per_repo_metadata() {
  local repo="$1"

  # File tree (top-level)
  local contents
  contents=$(gh api "repos/$repo/contents" 2>/dev/null | jq -r '.[].name' 2>/dev/null || true)

  # Detect key files
  local key_files=()
  for pattern in "${KEY_FILE_PATTERNS[@]}"; do
    if echo "$contents" | grep -qx "$pattern"; then
      key_files+=("$pattern")
    fi
  done

  # Infer project type
  local project_type=""
  for f in "${key_files[@]}"; do
    case "$f" in
      Cargo.toml)      project_type="rust"; break ;;
      pyproject.toml)  project_type="python"; break ;;
      package.json)    project_type="node"; break ;;
      go.mod)          project_type="go"; break ;;
      action.yaml|action.yml) project_type="gha"; break ;;
    esac
  done

  # README excerpt
  local readme_excerpt=""
  local readme_raw
  readme_raw=$(gh api "repos/$repo/readme" 2>/dev/null | jq -r '.content' 2>/dev/null || true)
  if [[ -n "$readme_raw" ]]; then
    readme_excerpt=$(echo "$readme_raw" | base64 -d 2>/dev/null | head -20 || true)
  fi

  # Output as JSON
  jq -n \
    --arg pt "$project_type" \
    --arg excerpt "$readme_excerpt" \
    --argjson kf "$(printf '%s\n' "${key_files[@]}" | jq -R . | jq -s .)" \
    '{keyFiles: $kf, projectType: $pt, readmeExcerpt: $excerpt}'
}
