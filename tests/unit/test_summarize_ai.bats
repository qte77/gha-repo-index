#!/usr/bin/env bats

# TDD RED: Unit tests for scripts/summarize-with-ai.sh

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export TMPDIR="${BATS_TMPDIR:-/tmp}/gha-repo-index-test"
  mkdir -p "$TMPDIR"
  source "$REPO_ROOT/scripts/summarize-with-ai.sh"

  # Mock curl
  export CURL_MOCK_LOG="$TMPDIR/curl_mock.log"
  export CURL_MOCK_RESPONSE=""
  export CURL_MOCK_STATUS="200"
  curl() {
    echo "curl $*" >> "$CURL_MOCK_LOG"
    # Return body + status on separate lines (matches -w "\n%{http_code}" pattern)
    # Reason: ${CURL_MOCK_RESPONSE:-{}} would append a stray "}" to a set value
    local body="${CURL_MOCK_RESPONSE:-}"
    [ -n "$body" ] || body='{}'
    echo "$body"
    echo "${CURL_MOCK_STATUS:-200}"
  }
  export -f curl

  # Default provider for the payload/call tests: OpenAI-compatible
  unset ANTHROPIC_API_KEY
  export INPUT_API_BASE="https://llm.example/v1"
  export AI_TOKEN="test-token"
  export INPUT_AI_MODEL="openai/gpt-4.1-mini"
}

teardown() {
  rm -rf "$TMPDIR"
}

# --- build_ai_payload ---

@test "build_ai_payload produces valid JSON" {
  # ARRANGE
  local metadata='{"name":"rtk","description":"CLI proxy","languages":["Rust"],"topics":["cli"],"readmeExcerpt":"# rtk\nCLI proxy","keyFiles":["Cargo.toml"]}'
  # ACT
  result=$(build_ai_payload "$metadata")
  # ASSERT
  echo "$result" | jq -e '.' > /dev/null
}

@test "build_ai_payload includes model field" {
  # ARRANGE
  export INPUT_AI_MODEL="openai/gpt-4.1-mini"
  local metadata='{"name":"rtk","description":"desc","languages":[],"topics":[],"readmeExcerpt":"","keyFiles":[]}'
  # ACT
  result=$(build_ai_payload "$metadata")
  # ASSERT
  [ "$(echo "$result" | jq -r '.model')" = "openai/gpt-4.1-mini" ]
}

@test "build_ai_payload has system and user messages" {
  # ARRANGE
  local metadata='{"name":"rtk","description":"desc","languages":[],"topics":[],"readmeExcerpt":"","keyFiles":[]}'
  # ACT
  result=$(build_ai_payload "$metadata")
  # ASSERT
  [ "$(echo "$result" | jq -r '.messages[0].role')" = "system" ]
  [ "$(echo "$result" | jq -r '.messages[1].role')" = "user" ]
}

@test "build_ai_payload user message contains repo name" {
  # ARRANGE
  local metadata='{"name":"rtk","description":"desc","languages":[],"topics":[],"readmeExcerpt":"","keyFiles":[]}'
  # ACT
  result=$(build_ai_payload "$metadata")
  # ASSERT
  [[ "$(echo "$result" | jq -r '.messages[1].content')" == *"rtk"* ]]
}

# --- call_ai_model ---

@test "call_ai_model extracts summary from 200 response" {
  # ARRANGE
  CURL_MOCK_RESPONSE='{"choices":[{"message":{"content":"A CLI proxy for token savings."}}]}'
  CURL_MOCK_STATUS="200"
  local payload='{"model":"openai/gpt-4.1-mini","messages":[]}'
  # ACT
  result=$(call_ai_model "$payload")
  # ASSERT
  [ "$result" = "A CLI proxy for token savings." ]
}

@test "call_ai_model retries on non-200 then succeeds" {
  # ARRANGE — file-based counter survives subshells
  echo "0" > "$TMPDIR/curl_call_count"
  curl() {
    local count
    count=$(cat "$TMPDIR/curl_call_count")
    count=$((count + 1))
    echo "$count" > "$TMPDIR/curl_call_count"
    if [ "$count" -eq 1 ]; then
      echo '{"error":"rate limit"}'
      echo "429"
    else
      echo '{"choices":[{"message":{"content":"Success after retry."}}]}'
      echo "200"
    fi
  }
  export -f curl
  # Override retry delay for fast test
  AI_RETRY_DELAY=0
  local payload='{"model":"openai/gpt-4.1-mini","messages":[]}'
  # ACT
  result=$(call_ai_model "$payload")
  # ASSERT
  [ "$result" = "Success after retry." ]
}

@test "call_ai_model returns empty on all retries exhausted" {
  # ARRANGE
  CURL_MOCK_RESPONSE='{"error":"server error"}'
  CURL_MOCK_STATUS="500"
  local payload='{"model":"openai/gpt-4.1-mini","messages":[]}'
  # ACT
  result=$(call_ai_model "$payload")
  # ASSERT
  [ -z "$result" ]
}

# --- summarize_repo ---

@test "summarize_repo returns AI summary on success" {
  # ARRANGE
  CURL_MOCK_RESPONSE='{"choices":[{"message":{"content":"Token-saving CLI proxy."}}]}'
  CURL_MOCK_STATUS="200"
  export INPUT_AI_MODEL="openai/gpt-4.1-mini"
  local metadata='{"name":"rtk","description":"CLI proxy","languages":["Rust"],"topics":["cli"],"readmeExcerpt":"# rtk","keyFiles":["Cargo.toml"]}'
  # ACT
  result=$(summarize_repo "$metadata")
  # ASSERT
  [ "$result" = "Token-saving CLI proxy." ]
}

@test "summarize_repo returns empty on failure" {
  # ARRANGE
  CURL_MOCK_RESPONSE='{"error":"fail"}'
  CURL_MOCK_STATUS="500"
  export INPUT_AI_MODEL="openai/gpt-4.1-mini"
  local metadata='{"name":"rtk","description":"desc","languages":[],"topics":[],"readmeExcerpt":"","keyFiles":[]}'
  # ACT
  result=$(summarize_repo "$metadata")
  # ASSERT
  [ -z "$result" ]
}

# --- provider selection (GitHub Models was retired 2026-07-30) ---

@test "ai_provider prefers API_BASE over ANTHROPIC_API_KEY" {
  export ANTHROPIC_API_KEY="sk-ant-test"
  [ "$(ai_provider)" = "openai" ]
}

@test "ai_provider is anthropic with only ANTHROPIC_API_KEY" {
  unset INPUT_API_BASE
  export ANTHROPIC_API_KEY="sk-ant-test"
  [ "$(ai_provider)" = "anthropic" ]
}

@test "ai_provider is empty when no provider is configured" {
  unset INPUT_API_BASE ANTHROPIC_API_KEY
  [ -z "$(ai_provider)" ]
}

@test "call_ai_model posts to API_BASE chat completions with the AI_TOKEN bearer" {
  CURL_MOCK_RESPONSE='{"choices":[{"message":{"content":"ok"}}]}'
  call_ai_model '{"model":"m","messages":[]}' > /dev/null
  grep -q "https://llm.example/v1/chat/completions" "$CURL_MOCK_LOG"
  grep -q "Authorization: Bearer test-token" "$CURL_MOCK_LOG"
  ! grep -q "models.github.ai" "$CURL_MOCK_LOG"
}

@test "anthropic payload puts the system prompt top-level and defaults the model" {
  unset INPUT_API_BASE INPUT_AI_MODEL
  export ANTHROPIC_API_KEY="sk-ant-test"
  local metadata='{"name":"rtk","description":"desc","languages":[],"topics":[],"readmeExcerpt":"","keyFiles":[]}'
  result=$(build_ai_payload "$metadata")
  [ "$(echo "$result" | jq -r '.model')" = "claude-haiku-5-5" ]
  [ -n "$(echo "$result" | jq -r '.system')" ]
  [ "$(echo "$result" | jq -r '.messages[0].role')" = "user" ]
  [ "$(echo "$result" | jq '.messages | length')" = "1" ]
}

@test "anthropic call uses the Messages API and extracts content text" {
  unset INPUT_API_BASE
  export ANTHROPIC_API_KEY="sk-ant-test"
  CURL_MOCK_RESPONSE='{"content":[{"type":"text","text":"A CLI proxy."}]}'
  result=$(call_ai_model '{"model":"m","messages":[]}')
  [ "$result" = "A CLI proxy." ]
  grep -q "https://api.anthropic.com/v1/messages" "$CURL_MOCK_LOG"
  grep -q "x-api-key: sk-ant-test" "$CURL_MOCK_LOG"
}

@test "call_ai_model makes no request and returns empty without a provider" {
  unset INPUT_API_BASE ANTHROPIC_API_KEY
  result=$(call_ai_model '{"model":"m","messages":[]}')
  [ -z "$result" ]
  [ ! -s "$CURL_MOCK_LOG" ]
}
