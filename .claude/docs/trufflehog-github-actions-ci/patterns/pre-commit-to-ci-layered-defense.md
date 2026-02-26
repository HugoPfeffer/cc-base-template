---
title: "Pre-commit to CI Layered Defense"
tags: [pattern, pre-commit, layered-defense, developer-feedback, ci-enforcement]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "patterns"
---

# Pattern: Pre-commit to CI Layered Defense

## Problem

CI scanning catches secrets after they are committed, requiring a commit revert or history rewrite. Developers want earlier feedback. But pre-commit hooks can be bypassed, so they cannot be the sole control.

## Solution

Deploy TruffleHog at two layers:

1. **Pre-commit hook** — runs locally on the developer's machine before each commit, providing immediate feedback at zero CI cost
2. **CI scan** — runs in GitHub Actions on every push and PR, providing non-bypassable enforcement

The two layers are complementary: pre-commit provides fast feedback, CI provides certainty.

## Layer 1: Pre-commit Hook

TruffleHog provides an official hook for the `pre-commit` framework.

### Installation

```bash
# Install the pre-commit framework
pip install pre-commit

# Configure the hook in .pre-commit-config.yaml
cat > .pre-commit-config.yaml << 'EOF'
repos:
  - repo: https://github.com/trufflesecurity/trufflehog
    rev: v3.93.4
    hooks:
      - id: trufflehog
EOF

# Install the hook into the local git repository
pre-commit install
```

### What the Official Hook Runs

The official `trufflehog` hook from `.pre-commit-hooks.yaml` executes:

```bash
trufflehog git file://. \
  --since-commit HEAD \
  --results=verified \
  --fail \
  --trust-local-git-config
```

Key characteristics:
- `--since-commit HEAD` — only scans the staged commit, not full history
- `--results=verified` — only fails on confirmed active credentials (no false positive noise)
- `--trust-local-git-config` — respects local git configuration (useful for private repos)

### Stricter Alternative (Optional)

For higher sensitivity, scan for `verified` and `unknown` (catches secrets even when verification is unavailable):

```yaml
repos:
  - repo: https://github.com/trufflesecurity/trufflehog
    rev: v3.93.4
    hooks:
      - id: trufflehog
        args: [--results=verified,unknown]
```

### Team-Wide Deployment

To enforce the pre-commit hook across the team, add `.pre-commit-config.yaml` to the repository and document installation in the README. Optionally use a CI step to verify the hook is installed:

```yaml
- name: Verify pre-commit config exists
  run: |
    if [ ! -f .pre-commit-config.yaml ]; then
      echo "Missing .pre-commit-config.yaml"
      exit 1
    fi
```

### Global Hook (Individual Developer)

A developer can also install TruffleHog as a global git hook that runs for every repository on their machine:

```bash
mkdir -p ~/.git-hooks
cat > ~/.git-hooks/pre-commit << 'EOF'
#!/bin/sh
trufflehog git file://. \
  --since-commit HEAD \
  --results=verified \
  --fail \
  --trust-local-git-config
EOF
chmod +x ~/.git-hooks/pre-commit
git config --global core.hookspath ~/.git-hooks
```

## Layer 2: CI Enforcement

The pre-commit hook can be bypassed: `git commit --no-verify` skips all hooks. CI is the enforcement layer that cannot be bypassed.

```yaml
# .github/workflows/secret-scan.yml
name: Secret Scan
on:
  push: {}
  pull_request: {}

permissions: {}

jobs:
  scan:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
        with:
          fetch-depth: 0
      - uses: trufflesecurity/trufflehog@v3.93.4
```

With branch protection requiring the `scan` check to pass, no code can merge without passing the CI scan.

## Layer 3 (Optional): Scheduled Full-History Sweep

Add a weekly scheduled scan as a third layer that catches any secret that slipped through the first two layers — for example, secrets committed via automated tooling or workflow tool integrations that bypass developer machines:

```yaml
# .github/workflows/full-history-scan.yml
name: Weekly Full History Scan
on:
  schedule:
    - cron: '0 3 * * 0'  # Every Sunday at 03:00 UTC
  workflow_dispatch: {}

permissions: {}

jobs:
  scan:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
        with:
          fetch-depth: 0
      - uses: trufflesecurity/trufflehog@v3.93.4
        with:
          extra_args: --results=verified,unknown --force-skip-binaries
```

See [full-history-scan.md](./full-history-scan.md) for full details on scheduling and performance tuning.

## The Defense-in-Depth Value

| Layer | Speed | Bypassable | Cost |
|-------|-------|-----------|------|
| Pre-commit hook | Immediate | Yes (`--no-verify`) | Free |
| CI (PR scan) | Minutes | No (with branch protection) | CI minutes |
| CI (push scan) | Minutes | No | CI minutes |
| CI (full history) | Variable | No | CI minutes |

The pre-commit hook catches 90% of accidental exposures instantly. CI catches the remaining 10% (intentional bypasses, workflow tool commits, imports, etc.).

## Version Pinning the Pre-commit Hook

The `rev:` in `.pre-commit-config.yaml` should be pinned to a specific version tag:

```yaml
repos:
  - repo: https://github.com/trufflesecurity/trufflehog
    rev: v3.93.4   # Pin to a specific release
    hooks:
      - id: trufflehog
```

Use `pre-commit autoupdate` periodically to bump the version.

## See Also

- [ci-scan-on-push.md](./ci-scan-on-push.md) — The CI enforcement layer for push events
- [ci-scan-on-pull-request.md](./ci-scan-on-pull-request.md) — The CI enforcement layer for PRs
- [../concepts/secret-scanning-fundamentals.md](../concepts/secret-scanning-fundamentals.md) — Why CI must be the enforcement gate
- [../guides/local-trufflehog-installation.md](../guides/local-trufflehog-installation.md) — All installation methods
