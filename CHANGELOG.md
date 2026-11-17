# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- AI summaries work again after the GitHub Models retirement (2026-07-30, #20):
  `scripts/summarize-with-ai.sh` calls an OpenAI-compatible API (`API_BASE` + `AI_TOKEN`) or the
  Anthropic Messages API (`ANTHROPIC_API_KEY`, default model `claude-haiku-5-5`), the same order as
  gha-ai-changelog. New inputs `API_BASE`, `AI_TOKEN`, `ANTHROPIC_API_KEY`; `AI_MODEL` now defaults to
  empty (required with `API_BASE`). With `AI_ENABLED` on and no usable provider, the registry still builds
  and the run logs one warning instead of silently writing no summaries. `AI_TOKEN` no longer falls back
  to the GitHub token. Each request times out (10 s to connect, 60 s in total); a 4xx other than 429 is not retried; after a
  401/403 the run stops calling the provider; a response without text stores no summary (never the string `null`). The
  default Anthropic model is the small one on purpose: summaries are 2-3 sentences
- `scripts/collect-repo-metadata.sh`: `collect_bulk_metadata` retries `gh repo list` up to 3 times
  (5 s apart) when it fails or returns no JSON array, as a transient GraphQL HTTP 502 does, and then
  fails with a clear error. Before, the empty output surfaced later as a `jq --argjson` error
- `pyproject.toml`, `README.md`: version files aligned to the existing `v0.1.1` tag and release
  (2026-06-13); they had stayed at `0.1.0`.

### Added

- `.github/workflows/test.yml`: `action-smoke` job runs the composite action on every PR and
  checks `index.json` and that `REPO_REGISTRY.md` lists this repo, so changes to `action.yaml` are exercised by CI
- Composite action with auto-discover via `gh repo list --limit 200`
- Bulk metadata collection with archive/fork filtering
- Per-repo structure extraction (key files, project type, README excerpt)
- `index.json` machine-readable registry output
- `REPO_REGISTRY.md` agent-facing overview with hero text
- Overview table sorted by last push date
- BATS test suite (70 tests) with `gh_mock.bash` infrastructure
- GHA ecosystem documentation (`docs/ecosystem.md`)
- `dependabot.yml` with weekly grouped `github-actions` updates
- `.github/workflows/codeql.yml`: CodeQL code scanning (`actions` language,
  matching the SHA-pinned variant used by sibling `gha-*` repos), closing the
  gap where this repo was the sole `gha-*` outlier without one
- `.github/workflows/lint-actions.yml`: adopt the shared `qte77/.github` reusable
  `lint-actions` gate (actionlint + yamllint + zizmor) on push/PR/dispatch to `main`
- `Makefile`: wire `actionlint` and `zizmor` into the `lint` target (previously
  install-only in `setup_dev`) and install `zizmor` there too
