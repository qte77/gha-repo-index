# GHA Ecosystem Interplay

`gha-repo-index` sits in the **OBSERVE** layer alongside `gha-arbitrary-repo-timeline`:
- **Index** = what repos ARE (static: structure, stack, purpose)
- **Timeline** = what repos DO (dynamic: issues, PRs, commits over time)

## Data Flow

```bash
gha-repo-index reads:
  ├── gh repo list (bulk metadata, 1 API call)
  ├── gh api repos/.../contents (file tree per repo)
  ├── gh api repos/.../readme (excerpts)
  └── GitHub Models API (AI summaries, Phase 2)

gha-repo-index produces → committed to qte77/qte77:
  ├── registry/index.json ──→ machine-readable SOT
  ├── REPO_REGISTRY.md ──→ agents read instead of exploring
  ├── registry/{name}.md ──→ per-repo deep context (Phase 2)
  └── README.md table ──→ human-readable profile page (Phase 2)

Future: other GHAs consume index.json (opt-in, one at a time):
  ├── timeline: jq '.[] | .nameWithOwner' < index.json
  ├── issue-sync: replaces repo_source: account
  ├── mirror: replaces hardcoded URLs
  └── future GHAs: single source of truth for "which repos"
```

## GHA Hierarchy

```text
┌─── OBSERVE ──────────────────────────────────────────┐
│                                                       │
│  gha-repo-index (NEW)      gha-arbitrary-repo-timeline│
│  ├─ what repos ARE         ├─ what repos DO over time │
│  ├─ structure, stack,      ├─ issues, PRs, commits    │
│  │  purpose, status        └─ per-repo Markdown logs  │
│  └─ registry + cards                                  │
│                                                       │
│  gha-arxiv-stats-action    gha-biorxiv-stats-action   │
│  └─ external: papers       └─ external: papers        │
└───────────────────────────────────────────────────────┘
                       │
                       ▼
┌─── TRANSFORM ────────────────────────────────────────┐
│                                                       │
│  gha-ai-changelog          gha-dirtree-to-readme      │
│  ├─ PR commits → summary   ├─ file tree → README      │
│  └─ GitHub Models AI       └─ structure snapshot       │
└───────────────────────────────────────────────────────┘
                       │
                       ▼
┌─── ORCHESTRATE ──────────────────────────────────────┐
│                                                       │
│  gha-cross-repo-issue-sync                            │
│  └─ syncs issues across repos → tracker               │
└───────────────────────────────────────────────────────┘
                       │
                       ▼
┌─── DISTRIBUTE ───────────────────────────────────────┐
│                                                       │
│  gha-github-mirror-action  gha-contribution-ascii     │
│  └─ repos → GitLab/Codeberg └─ contribution graph art │
└───────────────────────────────────────────────────────┘
```
