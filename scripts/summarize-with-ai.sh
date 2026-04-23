#!/bin/bash
set -euo pipefail
# GitHub Models AI summarization

AI_API_URL="https://models.github.ai/inference/chat/completions"
AI_MAX_RETRIES=3
AI_RETRY_DELAY=5

# Build JSON payload for GitHub Models API.
# Args: $1 = repo metadata JSON
build_ai_payload() {
  local meta="$1"
  local model="${INPUT_AI_MODEL:-openai/gpt-4.1-mini}"

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

  jq -n \
    --arg model "$model" \
    --arg system "You are a concise technical writer. Given repository metadata, produce a 2-3 sentence summary describing: (1) what the project does, (2) its primary technology, (3) its role if part of a larger ecosystem. Output ONLY the summary text." \
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
}

# Call GitHub Models API with retry.
# Args: $1 = JSON payload
# Returns: summary text or empty on failure
call_ai_model() {
  local payload="$1"
  local attempt=0

  while [ "$attempt" -lt "$AI_MAX_RETRIES" ]; do
    local response body status
    response=$(curl -s -w "\n%{http_code}" -X POST "$AI_API_URL" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${AI_TOKEN:-${GH_TOKEN:-}}" \
      -d "$payload")

    body=$(echo "$response" | head -n -1)
    status=$(echo "$response" | tail -n1)

    if [ "$status" = "200" ]; then
      echo "$body" | jq -r '.choices[0].message.content'
      return 0
    fi

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
