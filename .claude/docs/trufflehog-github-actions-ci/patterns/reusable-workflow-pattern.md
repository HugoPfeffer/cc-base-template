---
title: "Reusable Workflow Pattern"
tags: [pattern, reusable-workflow, workflow-call, organisation, central-enforcement]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "patterns"
---

# Pattern: Reusable Workflow — Central Engine + Thin Caller

## Problem

An organisation with 50+ repositories needs consistent secret scanning across all of them. Copying a workflow file into each repository creates a maintenance burden: every TruffleHog version bump, configuration change, or security fix requires 50 separate PRs.

## Solution

Deploy a single **engine workflow** in a central repository (the organisation's `.github` repo or a dedicated security repo). Each application repository contains a minimal **caller workflow** that delegates all scanning logic to the engine.

```
org/.github
└── .github/workflows/
    └── trufflehog-engine.yml   ← All scanning logic lives here

any-repo
└── .github/workflows/
    └── secret-scan.yml         ← 8 lines: just calls the engine
```

## How It Works

The engine workflow uses the `workflow_call:` trigger. The caller workflow references it with `uses: org/repo/.github/workflows/engine.yml@ref`.

When a PR is opened in `any-repo`, GitHub executes `any-repo`'s caller workflow, which in turn fetches and runs `org/.github`'s engine workflow. All logic runs from the engine — the caller does nothing except invoke it.

## The Caller Workflow (Application Repository)

```yaml
# any-repo/.github/workflows/secret-scan.yml
name: Secret Scan
on:
  push: {}
  pull_request: {}

jobs:
  scan:
    uses: org/.github/.github/workflows/trufflehog-engine.yml@main
    secrets: inherit
```

That is the entire file. Eight lines. It cannot be modified to bypass the scan logic.

## The Engine Workflow (Central Repository)

```yaml
# org/.github/.github/workflows/trufflehog-engine.yml
name: TruffleHog Scan Engine
on:
  workflow_call:
    secrets:
      TRUFFLEHOG_TOKEN:
        required: false

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
          persist-credentials: false
      - uses: trufflesecurity/trufflehog@v3.93.4
        with:
          extra_args: --results=verified,unknown
```

See [../examples/reusable-called-workflow.md](../examples/reusable-called-workflow.md) for the complete engine workflow.

## Benefits

| Benefit | Detail |
|---------|--------|
| Single point of update | Bump TruffleHog version once, all repos get it on next run |
| Enforced security controls | `permissions: {}`, SHA pins, `persist-credentials: false` set centrally |
| Uniform configuration | Same detectors, same `config.yaml`, same exclusions everywhere |
| Audit trail | All scan results flow through one place |
| Reduced onboarding | New repos need 8 lines, not 40 |

## Security Considerations

### Versioning the Engine Reference

```yaml
# Risky — main can change at any time
uses: org/.github/.github/workflows/engine.yml@main

# Better — pinned tag (still mutable)
uses: org/.github/.github/workflows/engine.yml@v1.0.0

# Best — pinned SHA (immutable)
uses: org/.github/.github/workflows/engine.yml@a1b2c3d4e5f6...
```

If the engine workflow reference is mutable (branch or tag), a compromised commit to the engine can affect all callers simultaneously. Use SHA pinning for production deployments.

### secrets: inherit vs Explicit

```yaml
# Convenient but grants all secrets to the engine
secrets: inherit

# Least-privilege — only pass what the engine needs
secrets:
  TRUFFLEHOG_TOKEN: ${{ secrets.GITHUB_PAT }}
```

### Permissions in Called Workflows

The called workflow's permissions cannot exceed the caller's permissions. If the caller grants `contents: read`, the engine cannot escalate to `contents: write` even if it declares it.

## Enabling Cross-Repository Access

For the caller to invoke the engine, the engine repository must be configured to allow it:

1. Go to the engine repository's **Settings > Actions > General**
2. Under "Access", select **"Accessible from repositories in the organization"**

Without this setting, callers outside the engine's repository will receive a permission error.

## Keeping the Engine Up to Date with Dependabot

The engine workflow references `trufflesecurity/trufflehog@vX.Y.Z`. Add a Dependabot configuration in the engine repository to receive automated PRs when a new TruffleHog version is released:

```yaml
# org/.github/.github/dependabot.yml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: "/.github/workflows"
    schedule:
      interval: weekly
    labels:
      - dependencies
      - security
```

Dependabot will open a PR against the engine repository each week if a newer action tag is available. After merging, all caller repositories pick up the update on their next run — no changes needed in the individual repos.

For SHA-pinned references, Dependabot can still propose updates: it will change both the SHA and the version comment in the same PR.

## Onboarding New Repositories

With this pattern, onboarding a new repository to organisation-wide scanning is:

1. Create `.github/workflows/secret-scan.yml` with 8 lines
2. Open a PR to add the file
3. Branch protection requires the check — it is automatically enforced on merge

No need to configure TruffleHog, choose flags, or manage versions.

## See Also

- [../concepts/template-repository-model.md](../concepts/template-repository-model.md) — Reusable vs starter workflows explained
- [../examples/reusable-called-workflow.md](../examples/reusable-called-workflow.md) — Complete engine YAML
- [../examples/reusable-caller-workflow.md](../examples/reusable-caller-workflow.md) — Complete caller YAML
- [../guides/creating-template-repository.md](../guides/creating-template-repository.md) — Step-by-step setup
