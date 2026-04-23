#!/usr/bin/env bats

# TDD RED: Unit tests for scripts/render.sh

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export TMPDIR="${BATS_TMPDIR:-/tmp}/gha-repo-index-test"
  mkdir -p "$TMPDIR"
  source "$REPO_ROOT/scripts/render.sh"
}

teardown() {
  rm -rf "$TMPDIR"
}

# --- render_card ---

@test "render_card produces YAML frontmatter with name" {
  # ARRANGE
  local metadata
  metadata=$(cat <<'JSON'
{"name":"rtk","description":"CLI proxy that reduces LLM token consumption by 60-90% on common dev commands.","languages":["Rust","Shell"],"topics":["cli","token-optimization"],"pushedAt":"2026-04-01T12:00:00Z","keyFiles":["Cargo.toml","CLAUDE.md","Makefile"],"projectType":"rust","stargazerCount":42,"forkCount":5,"license":"MIT","url":"https://github.com/qte77/rtk","isArchived":false}
JSON
  )
  # ACT
  result=$(render_card "$metadata")
  # ASSERT
  echo "$result" | grep -q '^name: rtk'
}

@test "render_card includes languages" {
  # ARRANGE
  local metadata='{"name":"rtk","description":"desc","languages":["Rust","Shell"],"topics":[],"pushedAt":"2026-04-01T12:00:00Z","keyFiles":[],"projectType":"rust","stargazerCount":0,"forkCount":0,"license":"MIT","url":"","isArchived":false}'
  # ACT
  result=$(render_card "$metadata")
  # ASSERT
  echo "$result" | grep -q 'Rust'
}

@test "render_card handles missing optional fields" {
  # ARRANGE — minimal metadata
  local metadata='{"name":"bare-repo","description":"","languages":[],"topics":[],"pushedAt":"2026-01-01T00:00:00Z","keyFiles":[],"projectType":"","stargazerCount":0,"forkCount":0,"license":"","url":"","isArchived":false}'
  # ACT
  result=$(render_card "$metadata")
  # ASSERT — should not fail, should contain name
  echo "$result" | grep -q 'bare-repo'
}

# --- render_table ---

@test "render_table produces markdown table header" {
  # ARRANGE — two-repo JSON array
  local repos
  repos=$(cat <<'JSON'
[{"name":"rtk","description":"CLI proxy","primaryLanguage":"Rust","projectType":"rust","pushedAt":"2026-04-01T12:00:00Z","url":"https://github.com/qte77/rtk"},{"name":"polyforge-orchestrator","description":"Polyrepo dev forge","primaryLanguage":"Shell","projectType":"","pushedAt":"2026-04-03T08:00:00Z","url":"https://github.com/qte77/polyforge-orchestrator"}]
JSON
  )
  # ACT
  result=$(render_table "$repos")
  # ASSERT
  echo "$result" | head -1 | grep -q '| Repo |'
}

@test "render_table sorts repos by last_push descending" {
  # ARRANGE
  local repos='[{"name":"old","description":"","primaryLanguage":"","projectType":"","pushedAt":"2025-01-01T00:00:00Z","url":""},{"name":"new","description":"","primaryLanguage":"","projectType":"","pushedAt":"2026-04-01T00:00:00Z","url":""}]'
  # ACT
  result=$(render_table "$repos")
  # ASSERT — "new" should appear before "old" in output
  local first_repo
  first_repo=$(echo "$result" | grep '^\|' | tail -n+3 | head -1)
  [[ "$first_repo" == *"new"* ]]
}

@test "render_table includes repo link" {
  # ARRANGE
  local repos='[{"name":"rtk","description":"desc","primaryLanguage":"Rust","projectType":"rust","pushedAt":"2026-04-01T00:00:00Z","url":"https://github.com/qte77/rtk"}]'
  # ACT
  result=$(render_table "$repos")
  # ASSERT
  echo "$result" | grep -q '\[rtk\](https://github.com/qte77/rtk)'
}

# --- render_registry_md ---

@test "render_registry_md includes hero text" {
  # ARRANGE
  local table="| Repo |\n|------|\n| test |"
  # ACT
  result=$(render_registry_md "$table")
  # ASSERT
  echo "$result" | grep -q "exploration tokens"
}

@test "render_registry_md includes the table" {
  # ARRANGE
  local table="| Repo | Description |"
  # ACT
  result=$(render_registry_md "$table")
  # ASSERT
  echo "$result" | grep -q '| Repo |'
}
