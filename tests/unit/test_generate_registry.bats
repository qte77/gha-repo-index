#!/usr/bin/env bats

# TDD RED: Integration tests for scripts/generate-registry.sh

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export TMPDIR="${BATS_TMPDIR:-/tmp}/gha-repo-index-test"
  mkdir -p "$TMPDIR"
  export GH_MOCK_LOG="$TMPDIR/gh_mock.log"
  export OUTPUT_DIR="$TMPDIR/output"

  # Wire mocks
  source "$REPO_ROOT/tests/test_helper/gh_mock.bash"
  export GH_MOCK_REPO_LIST_JSON="$REPO_ROOT/tests/fixtures/repo_list.json"
  export GH_MOCK_CONTENTS_JSON="$REPO_ROOT/tests/fixtures/repo_contents.json"

  # Wire env vars
  export INPUT_OWNER="qte77"
  export INPUT_REPOS=""
  export INPUT_INCLUDE_ARCHIVED="false"
  export INPUT_INCLUDE_FORKS="false"
  export INPUT_AI_ENABLED="false"
  export INPUT_OUTPUT_DIR="$OUTPUT_DIR"

  # Source scripts
  source "$REPO_ROOT/scripts/common.sh"
  source "$REPO_ROOT/scripts/collect-repo-metadata.sh"
  source "$REPO_ROOT/scripts/render.sh"
  source "$REPO_ROOT/scripts/generate-registry.sh"
}

teardown() {
  rm -f "$GH_MOCK_LOG"
  rm -rf "$TMPDIR"
}

# --- Output directory ---

@test "generate_registry creates output directory" {
  # ACT
  generate_registry
  # ASSERT
  [ -d "$OUTPUT_DIR" ]
}

# --- index.json ---

@test "generate_registry writes index.json" {
  # ACT
  generate_registry
  # ASSERT
  [ -f "$OUTPUT_DIR/index.json" ]
}

@test "generate_registry index.json is valid JSON" {
  # ACT
  generate_registry
  # ASSERT
  jq -e '.' "$OUTPUT_DIR/index.json" > /dev/null
}

@test "generate_registry index.json has generated_at field" {
  # ACT
  generate_registry
  # ASSERT
  jq -e '.generated_at' "$OUTPUT_DIR/index.json" > /dev/null
}

@test "generate_registry index.json has repos array" {
  # ACT
  generate_registry
  # ASSERT
  jq -e '.repos | type == "array"' "$OUTPUT_DIR/index.json" > /dev/null
}

@test "generate_registry index.json contains repo names" {
  # ACT
  generate_registry
  # ASSERT
  [ "$(jq -r '.repos[0].name' "$OUTPUT_DIR/index.json")" != "null" ]
}

# --- REPO_REGISTRY.md ---

@test "generate_registry writes REPO_REGISTRY.md" {
  # ACT
  generate_registry
  # ASSERT
  [ -f "$OUTPUT_DIR/REPO_REGISTRY.md" ]
}

@test "generate_registry REPO_REGISTRY.md contains hero text" {
  # ACT
  generate_registry
  # ASSERT
  grep -q "exploration tokens" "$OUTPUT_DIR/REPO_REGISTRY.md"
}

@test "generate_registry REPO_REGISTRY.md contains table" {
  # ACT
  generate_registry
  # ASSERT
  grep -q '| Repo |' "$OUTPUT_DIR/REPO_REGISTRY.md"
}
