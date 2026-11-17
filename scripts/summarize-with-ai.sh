#!/bin/bash
set -euo pipefail
# AI summarization of repo metadata.
#
# Reason: GitHub Models was retired 2026-07-30, so the provider is set
# explicitly. Dispatch order (same as gha-ai-changelog): an OpenAI-compatible
# API at INPUT_API_BASE with the AI_TOKEN bearer, then the Anthropic Messages
# API with ANTHROPIC_API_KEY. With neither set there is no request and no
# summary.

AI_MAX_RETRIES=3
AI_RETRY_DELAY=5
AI_CONNECT_TIMEOUT=10
AI_MAX_TIME=60
# Reason: summaries run in a subshell per repo, so a shell variable can't carry
# "auth failed" to the next repo; a marker file can. It lives in a private
# directory made by mktemp (mode 700), never at a predictable shared path.
AI_STATE_DIR=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/repo-index-ai.XXXXXX")
AI_AUTH_FAILED_FILE="$AI_STATE_DIR/auth-failed"
AI_SYSTEM_PROMPT="You are a concise technical writer. Given repository metadata, produce a 2-3 sentence summary describing: (1) what the project does, (2) its primary technology, (3) its role if part of a larger ecosystem. Output ONLY the summary text."

# Print the configured provider: "openai", "anthropic", or nothing.
ai_provider() {
  if [[ -n "${INPUT_API_BASE:-}" ]]; then
    echo "openai"
  elif [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    echo "anthropic"
  fi
}

# Build the JSON payload for the configured provider.
# Args: $1 = repo metadata JSON
build_ai_payload() {
  local meta="$1"

  local name desc langs topics readme key_files
  name=$(echo "$meta" | jq -r '.name')
  desc=$(echo "$meta" | jq -r '.description // ""')
  langs=$(echo "$meta" | jq -r '(.languages // []) | join(", ")')
  topics=$(echo "$meta" | jq -r '(.topics // []) | join(", ")')
  readme=$(echo "$meta" | jq -r '.readmeExcerpt // ""')
  key_files=$(echo "$meta" | jq -r '(.keyFiles // []) | join(", ")')

  local user_content="Repository: ${name}
Description: ${desc}
Languages: ${langs}
Topics: ${topics}
Key files: ${key_files}
README excerpt: ${readme}"

  if [[ "$(ai_provider)" == "anthropic" ]]; then
    jq -n \
      --arg model "${INPUT_AI_MODEL:-claude-haiku-5-5}" \
      --arg system "$AI_SYSTEM_PROMPT" \
      --arg user "$user_content" \
      '{
        model: $model,
        max_tokens: 200,
        system: $system,
        messages: [{role: "user", content: $user}]
      }'
  else
    jq -n \
      --arg model "${INPUT_AI_MODEL:-}" \
      --arg system "$AI_SYSTEM_PROMPT" \
      --arg user "$user_content" \
      '{
        model: $model,
        messages: [
          {role: "system", content: $system},
          {role: "user", content: $user}
        ],
        max_tokens: 200,
        temperature: 0.7
      }'
  fi
}

# Call the configured provider with retry.
# Args: $1 = JSON payload
# Returns: summary text, or empty on failure or without a provider
call_ai_model() {
  local payload="$1"
  local url content_path
  local -a headers

  case "$(ai_provider)" in
    openai)
      url="${INPUT_API_BASE%/}/chat/completions"
      headers=(-H "Authorization: Bearer ${AI_TOKEN:-}")
      content_path='.choices[0].message.content // empty'
      ;;
    anthropic)
      url="https://api.anthropic.com/v1/messages"
      headers=(-H "x-api-key: ${ANTHROPIC_API_KEY}" -H "anthropic-version: 2023-06-01")
      content_path='first(.content[]? | select(.type == "text") | .text) // empty'
      ;;
    *)
      return 0
      ;;
  esac

  # After an auth failure earlier in this run, don't call the provider again
  [ -e "$AI_AUTH_FAILED_FILE" ] && return 0

  local attempt=0
  while [ "$attempt" -lt "$AI_MAX_RETRIES" ]; do
    local response body status
    response=$(curl -s -w "\n%{http_code}" -X POST "$url" \
      --connect-timeout "$AI_CONNECT_TIMEOUT" --max-time "$AI_MAX_TIME" \
      -H "Content-Type: application/json" \
      "${headers[@]}" \
      -d "$payload")

    body=$(echo "$response" | head -n -1)
    status=$(echo "$response" | tail -n1)

    if [ "$status" = "200" ]; then
      echo "$body" | jq -r "$content_path"
      return 0
    fi
    case "$status" in
      401 | 403)
        echo "::warning::AI provider rejected the credentials (HTTP $status); skipping AI summaries for the rest of this run." >&2
        : > "$AI_AUTH_FAILED_FILE"
        return 0
        ;;
      4??)
        [ "$status" != "429" ] && return 0  # a request error won't succeed on retry
        ;;
    esac

    attempt=$((attempt + 1))
    [ "$attempt" -lt "$AI_MAX_RETRIES" ] && sleep "$AI_RETRY_DELAY"
  done

  echo ""
}

# Summarize a single repo.
# Args: $1 = repo metadata JSON
summarize_repo() {
  local meta="$1"
  local payload
  payload=$(build_ai_payload "$meta")
  call_ai_model "$payload"
}
