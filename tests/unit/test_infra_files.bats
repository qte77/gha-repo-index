#!/usr/bin/env bats

# TDD RED: Infrastructure file contracts for gha-repo-index
# These tests define the required file structure before any implementation exists.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

# --- Action definition ---

@test "action.yaml exists" {
  [ -f "$REPO_ROOT/action.yaml" ]
}

@test "action.yaml has name field" {
  grep -q '^name:' "$REPO_ROOT/action.yaml"
}

@test "action.yaml has description field" {
  grep -q '^description:' "$REPO_ROOT/action.yaml"
}

@test "action.yaml has branding icon field" {
  grep -q 'icon:' "$REPO_ROOT/action.yaml"
}

@test "action.yaml has branding color field" {
  grep -q 'color:' "$REPO_ROOT/action.yaml"
}

@test "action.yaml has OWNER input" {
  grep -q 'OWNER:' "$REPO_ROOT/action.yaml"
}

@test "action.yaml has REPOS input" {
  grep -q 'REPOS:' "$REPO_ROOT/action.yaml"
}

@test "action.yaml has AI_ENABLED input" {
  grep -q 'AI_ENABLED:' "$REPO_ROOT/action.yaml"
}

@test "action.yaml has OUTPUT_DIR input" {
  grep -q 'OUTPUT_DIR:' "$REPO_ROOT/action.yaml"
}

@test "action.yaml uses composite runs" {
  grep -q 'using:.*composite' "$REPO_ROOT/action.yaml"
}

# --- Scripts ---

@test "scripts/common.sh exists and is executable" {
  [ -x "$REPO_ROOT/scripts/common.sh" ]
}

@test "scripts/collect-repo-metadata.sh exists and is executable" {
  [ -x "$REPO_ROOT/scripts/collect-repo-metadata.sh" ]
}

@test "scripts/render.sh exists and is executable" {
  [ -x "$REPO_ROOT/scripts/render.sh" ]
}

@test "scripts/generate-registry.sh exists and is executable" {
  [ -x "$REPO_ROOT/scripts/generate-registry.sh" ]
}

@test "scripts/summarize-with-ai.sh exists and is executable" {
  [ -x "$REPO_ROOT/scripts/summarize-with-ai.sh" ]
}

# --- CI & cleanup ---

@test ".github/scripts/delete_branch_pr_tag.sh exists and is executable" {
  [ -x "$REPO_ROOT/.github/scripts/delete_branch_pr_tag.sh" ]
}

@test ".github/workflows/test.yml exists" {
  [ -f "$REPO_ROOT/.github/workflows/test.yml" ]
}

# --- Project config ---

@test "pyproject.toml exists" {
  [ -f "$REPO_ROOT/pyproject.toml" ]
}

@test "pyproject.toml has bumpversion config" {
  grep -q 'tool.bumpversion' "$REPO_ROOT/pyproject.toml"
}

@test "Makefile exists" {
  [ -f "$REPO_ROOT/Makefile" ]
}

@test "Makefile has test target" {
  grep -q '^test:' "$REPO_ROOT/Makefile" || grep -q '^test ' "$REPO_ROOT/Makefile"
}

@test "Makefile has lint target" {
  grep -q '^lint:' "$REPO_ROOT/Makefile" || grep -q '^lint ' "$REPO_ROOT/Makefile"
}

@test "Makefile has setup_dev target" {
  grep -q '^setup_dev:' "$REPO_ROOT/Makefile" || grep -q '^setup_dev ' "$REPO_ROOT/Makefile"
}

# --- Documentation ---

@test "README.md exists" {
  [ -f "$REPO_ROOT/README.md" ]
}

@test "docs/ecosystem.md exists" {
  [ -f "$REPO_ROOT/docs/ecosystem.md" ]
}

@test "LICENSE exists" {
  [ -f "$REPO_ROOT/LICENSE" ]
}

# --- Test infrastructure ---

@test "tests/test_helper/gh_mock.bash exists" {
  [ -f "$REPO_ROOT/tests/test_helper/gh_mock.bash" ]
}

@test "tests/fixtures/repo_list.json exists" {
  [ -f "$REPO_ROOT/tests/fixtures/repo_list.json" ]
}

@test "tests/fixtures/repo_contents.json exists" {
  [ -f "$REPO_ROOT/tests/fixtures/repo_contents.json" ]
}

@test "tests/fixtures/readme_base64.txt exists" {
  [ -f "$REPO_ROOT/tests/fixtures/readme_base64.txt" ]
}
