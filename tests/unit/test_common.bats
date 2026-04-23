#!/usr/bin/env bats

# TDD RED: Unit tests for scripts/common.sh

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export TMPDIR="${BATS_TMPDIR:-/tmp}/gha-repo-index-test"
  mkdir -p "$TMPDIR"
  export GH_MOCK_LOG="$TMPDIR/gh_mock.log"
  source "$REPO_ROOT/tests/test_helper/gh_mock.bash"
  source "$REPO_ROOT/scripts/common.sh"
}

teardown() {
  rm -f "$GH_MOCK_LOG"
  rm -rf "$TMPDIR"
}

# --- build_repo_list ---

@test "build_repo_list parses comma-separated input" {
  # ARRANGE
  export INPUT_REPOS="qte77/rtk,qte77/polyforge-orchestrator"
  export INPUT_OWNER=""
  # ACT
  mapfile -t result < <(build_repo_list)
  # ASSERT
  [ "${#result[@]}" -eq 2 ]
  [ "${result[0]}" = "qte77/rtk" ]
  [ "${result[1]}" = "qte77/polyforge-orchestrator" ]
}

@test "build_repo_list trims whitespace from entries" {
  # ARRANGE
  export INPUT_REPOS="  qte77/rtk , qte77/polyforge-orchestrator  "
  export INPUT_OWNER=""
  # ACT
  mapfile -t result < <(build_repo_list)
  # ASSERT
  [ "${result[0]}" = "qte77/rtk" ]
  [ "${result[1]}" = "qte77/polyforge-orchestrator" ]
}

@test "build_repo_list auto-discovers from owner when REPOS empty" {
  # ARRANGE
  export INPUT_REPOS=""
  export INPUT_OWNER="qte77"
  export GH_MOCK_REPO_LIST_JSON="$REPO_ROOT/tests/fixtures/repo_list.json"
  # ACT
  mapfile -t result < <(build_repo_list)
  # ASSERT
  [ "${#result[@]}" -gt 0 ]
}

@test "build_repo_list uses --limit 200 for auto-discovery" {
  # ASSERT — verify the source contains --limit 200 in build_repo_list
  grep -q '\-\-limit 200' "$REPO_ROOT/scripts/common.sh"
}

@test "build_repo_list returns empty for empty owner and empty repos" {
  # ARRANGE
  export INPUT_REPOS=""
  export INPUT_OWNER=""
  # ACT
  mapfile -t result < <(build_repo_list)
  # ASSERT
  [ "${#result[@]}" -eq 0 ]
}

# --- split_repo ---

@test "split_repo extracts owner from owner/name" {
  # ACT
  result=$(split_repo "qte77/rtk" "owner")
  # ASSERT
  [ "$result" = "qte77" ]
}

@test "split_repo extracts name from owner/name" {
  # ACT
  result=$(split_repo "qte77/rtk" "name")
  # ASSERT
  [ "$result" = "rtk" ]
}

@test "split_repo handles nested owner (org/suborg not expected but safe)" {
  # ACT
  result=$(split_repo "qte77/my-repo" "name")
  # ASSERT
  [ "$result" = "my-repo" ]
}

# --- days_ago ---

@test "days_ago returns ISO date for 0 days ago (today)" {
  # ACT
  result=$(days_ago 0)
  expected=$(date +%Y-%m-%d)
  # ASSERT
  [ "$result" = "$expected" ]
}

@test "days_ago returns ISO date for 7 days ago" {
  # ACT
  result=$(days_ago 7)
  expected=$(date -d "7 days ago" +%Y-%m-%d 2>/dev/null || date -v-7d +%Y-%m-%d)
  # ASSERT
  [ "$result" = "$expected" ]
}

@test "days_ago defaults to 7 when no argument given" {
  # ACT
  result=$(days_ago)
  expected=$(date -d "7 days ago" +%Y-%m-%d 2>/dev/null || date -v-7d +%Y-%m-%d)
  # ASSERT
  [ "$result" = "$expected" ]
}
