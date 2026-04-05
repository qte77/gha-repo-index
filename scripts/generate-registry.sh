#!/bin/bash
set -euo pipefail
# Main orchestrator: collect → render → output

generate_registry() {
  local output_dir="${INPUT_OUTPUT_DIR:-.}"
  local owner="${INPUT_OWNER:-}"
  mkdir -p "$output_dir"

  # 1. Collect bulk metadata
  local bulk
  bulk=$(collect_bulk_metadata "$owner")

  # 2. Enrich with per-repo metadata
  local enriched="[]"
  local repo_count
  repo_count=$(echo "$bulk" | jq length)

  for i in $(seq 0 $((repo_count - 1))); do
    local repo_json
    repo_json=$(echo "$bulk" | jq ".[$i]")

    local name_with_owner
    name_with_owner=$(echo "$repo_json" | jq -r '.nameWithOwner')

    # Per-repo supplementary data
    local per_repo
    per_repo=$(collect_per_repo_metadata "$name_with_owner")

    # Flatten languages from nested GH API format
    local langs
    langs=$(echo "$repo_json" | jq '[.languages[]?.node.name // empty]')

    # Flatten topics
    local topics
    topics=$(echo "$repo_json" | jq '[.repositoryTopics[]?.node.topic.name // empty]')

    # Merge into a single entry
    local entry
    entry=$(echo "$repo_json" | jq \
      --argjson per_repo "$per_repo" \
      --argjson langs "$langs" \
      --argjson topics "$topics" \
      '{
        name: .name,
        nameWithOwner: .nameWithOwner,
        description: (.description // ""),
        url: (.url // ""),
        primaryLanguage: (.primaryLanguage.name // ""),
        languages: $langs,
        topics: $topics,
        pushedAt: (.pushedAt // ""),
        createdAt: (.createdAt // ""),
        isArchived: (.isArchived // false),
        isFork: (.isFork // false),
        visibility: (.visibility // "PUBLIC"),
        defaultBranch: (.defaultBranchRef.name // "main"),
        stargazerCount: (.stargazerCount // 0),
        forkCount: (.forkCount // 0),
        license: (.licenseInfo.spdxId // ""),
        diskUsage: (.diskUsage // 0),
        keyFiles: $per_repo.keyFiles,
        projectType: $per_repo.projectType,
        readmeExcerpt: $per_repo.readmeExcerpt
      }')

    # AI summary (Phase 2, conditional)
    if [[ "${INPUT_AI_ENABLED:-false}" == "true" ]]; then
      local summary
      summary=$(summarize_repo "$entry")
      if [[ -n "$summary" ]]; then
        entry=$(echo "$entry" | jq --arg s "$summary" '. + {aiSummary: $s}')
      fi
    fi

    enriched=$(echo "$enriched" | jq --argjson e "$entry" '. + [$e]')
  done

  # 3. Write index.json
  local generated_at
  generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  jq -n \
    --arg ts "$generated_at" \
    --arg owner "$owner" \
    --argjson count "$repo_count" \
    --argjson repos "$enriched" \
    '{generated_at: $ts, owner: $owner, repo_count: $count, repos: $repos}' \
    > "$output_dir/index.json"

  # 4. Render table
  local table
  table=$(render_table "$enriched")

  # 5. Render per-repo cards
  local cards=""
  for i in $(seq 0 $((repo_count - 1))); do
    local repo_entry
    repo_entry=$(echo "$enriched" | jq ".[$i]")
    cards+="$(render_card "$repo_entry")"
    cards+=$'\n\n---\n\n'
  done

  # 6. Write REPO_REGISTRY.md
  render_registry_md "$table" "$cards" > "$output_dir/REPO_REGISTRY.md"
}
