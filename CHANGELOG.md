# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Composite action with auto-discover via `gh repo list --limit 200`
- Bulk metadata collection with archive/fork filtering
- Per-repo structure extraction (key files, project type, README excerpt)
- `index.json` machine-readable registry output
- `REPO_REGISTRY.md` agent-facing overview with hero text
- Overview table sorted by last push date
- BATS test suite (70 tests) with `gh_mock.bash` infrastructure
- GHA ecosystem documentation (`docs/ecosystem.md`)
