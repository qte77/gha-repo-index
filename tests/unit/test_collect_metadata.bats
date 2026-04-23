#!/usr/bin/env bats

# TDD RED: Unit tests for scripts/collect-repo-metadata.sh

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export TMPDIR="${BATS_TMPDIR:-/tmp}/gha-repo-index-test"
  mkdir -p "$TMPDIR"
  export GH_MOCK_LOG="$TMPDIR/gh_mock.log"
  source "$REPO_ROOT/tests/test_helper/gh_mock.bash"
  source "$REPO_ROOT/scripts/common.sh"
  source "$REPO_ROOT/scripts/collect-repo-metadata.sh"
}

teardown() {
  rm -f "$GH_MOCK_LOG"
  rm -rf "$TMPDIR"
}

# --- collect_bulk_metadata ---

@test "collect_bulk_metadata returns valid JSON array" {
  # ARRANGE
  export GH_MOCK_REPO_LIST_JSON="$REPO_ROOT/tests/fixtures/repo_list.json"
  # ACT
  result=$(collect_bulk_metadata "qte77")
  # ASSERT
  echo "$result" | jq -e 'type == "array"' > /dev/null
}

@test "collect_bulk_metadata contains expected repo names" {
  # ARRANGE
  export GH_MOCK_REPO_LIST_JSON="$REPO_ROOT/tests/fixtures/repo_list.json"
  # ACT
  result=$(collect_bulk_metadata "qte77")
  # ASSERT
  [ "$(echo "$result" | jq -r '.[0].name')" = "rtk" ]
  [ "$(echo "$result" | jq -r '.[1].name')" = "polyforge-orchestrator" ]
}

@test "collect_bulk_metadata excludes archived repos by default" {
  # ARRANGE
  export GH_MOCK_REPO_LIST_JSON="$REPO_ROOT/tests/fixtures/repo_list.json"
  export INPUT_INCLUDE_ARCHIVED="false"
  # ACT
  result=$(collect_bulk_metadata "qte77")
  # ASSERT — fixture has 3 repos, 1 archived
  [ "$(echo "$result" | jq length)" -eq 2 ]
}

@test "collect_bulk_metadata includes archived repos when requested" {
  # ARRANGE
  export GH_MOCK_REPO_LIST_JSON="$REPO_ROOT/tests/fixtures/repo_list.json"
  export INPUT_INCLUDE_ARCHIVED="true"
  # ACT
  result=$(collect_bulk_metadata "qte77")
  # ASSERT
  [ "$(echo "$result" | jq length)" -eq 3 ]
}

@test "collect_bulk_metadata excludes forks by default" {
  # ARRANGE
  export GH_MOCK_REPO_LIST_JSON="$REPO_ROOT/tests/fixtures/repo_list.json"
  export INPUT_INCLUDE_FORKS="false"
  # ACT
  result=$(collect_bulk_metadata "qte77")
  # ASSERT — no forks in fixture, count unchanged
  local count
  count=$(echo "$result" | jq '[.[] | select(.isFork == false)] | length')
  [ "$(echo "$result" | jq length)" -eq "$count" ]
}

# --- collect_per_repo_metadata ---

@test "collect_per_repo_metadata returns key files list" {
  # ARRANGE
  export GH_MOCK_CONTENTS_JSON="$REPO_ROOT/tests/fixtures/repo_contents.json"
  # ACT
  result=$(collect_per_repo_metadata "qte77/rtk")
  # ASSERT
  echo "$result" | jq -e '.keyFiles' > /dev/null
  [[ "$(echo "$result" | jq -r '.keyFiles[]' | grep -c 'Cargo.toml')" -eq 1 ]]
}

@test "collect_per_repo_metadata detects CLAUDE.md" {
  # ARRANGE
  export GH_MOCK_CONTENTS_JSON="$REPO_ROOT/tests/fixtures/repo_contents.json"
  # ACT
  result=$(collect_per_repo_metadata "qte77/rtk")
  # ASSERT
  echo "$result" | jq -e '.keyFiles[] | select(. == "CLAUDE.md")' > /dev/null
}

@test "collect_per_repo_metadata infers projectType from Cargo.toml" {
  # ARRANGE
  export GH_MOCK_CONTENTS_JSON="$REPO_ROOT/tests/fixtures/repo_contents.json"
  # ACT
  result=$(collect_per_repo_metadata "qte77/rtk")
  # ASSERT
  [ "$(echo "$result" | jq -r '.projectType')" = "rust" ]
}

@test "collect_per_repo_metadata extracts readme excerpt" {
  # ARRANGE
  export GH_MOCK_CONTENTS_JSON="$REPO_ROOT/tests/fixtures/repo_contents.json"
  export GH_MOCK_README_JSON="$TMPDIR/readme_response.json"
  local b64
  b64=$(cat "$REPO_ROOT/tests/fixtures/readme_base64.txt")
  echo "{\"content\":\"$b64\"}" > "$GH_MOCK_README_JSON"
  # ACT
  result=$(collect_per_repo_metadata "qte77/rtk")
  # ASSERT
  [[ "$(echo "$result" | jq -r '.readmeExcerpt')" == *"rtk"* ]]
}

@test "collect_per_repo_metadata handles missing README gracefully" {
  # ARRANGE
  export GH_MOCK_CONTENTS_JSON="$REPO_ROOT/tests/fixtures/repo_contents.json"
  export GH_MOCK_README_JSON=""
  # ACT
  result=$(collect_per_repo_metadata "qte77/rtk")
  # ASSERT — should not fail, excerpt should be empty
  [ "$(echo "$result" | jq -r '.readmeExcerpt')" = "" ]
}

@test "collect_per_repo_metadata infers gha type from action.yaml" {
  # ARRANGE — fixture with action.yaml
  echo '[{"name":"action.yaml","type":"file"},{"name":"README.md","type":"file"}]' > "$TMPDIR/gha_contents.json"
  export GH_MOCK_CONTENTS_JSON="$TMPDIR/gha_contents.json"
  # ACT
  result=$(collect_per_repo_metadata "qte77/gha-ai-changelog")
  # ASSERT
  [ "$(echo "$result" | jq -r '.projectType')" = "gha" ]
}

@test "collect_per_repo_metadata infers python type from pyproject.toml" {
  # ARRANGE
  echo '[{"name":"pyproject.toml","type":"file"},{"name":"src","type":"dir"}]' > "$TMPDIR/py_contents.json"
  export GH_MOCK_CONTENTS_JSON="$TMPDIR/py_contents.json"
  # ACT
  result=$(collect_per_repo_metadata "qte77/some-py-project")
  # ASSERT
  [ "$(echo "$result" | jq -r '.projectType')" = "python" ]
}
