---
title: "Reusable Workflow — Caller (Application Repository)"
tags: [example, reusable-workflow, caller, workflow-call]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "examples"
---

# Example: Reusable Workflow Caller (Application Repository)

The caller workflow lives in each application repository. It is intentionally minimal — all scanning logic resides in the central engine workflow. Application teams copy this file into their repositories and do not modify the engine.

## When to Use This Example

- Any application repository that should participate in organisation-wide secret scanning
- When the central engine workflow is already deployed (see [reusable-called-workflow.md](./reusable-called-workflow.md))
- When you want a single place to update scan logic across all repositories

## The Workflow

```yaml
# .github/workflows/secret-scan.yml
name: Security Scan

on:
  push:
    branches: [main]
  pull_request:

jobs:
  secret-scan:
    permissions:
      contents: read
    uses: your-org/security-workflows/.github/workflows/secret-scan.yml@main
```

## Line-by-Line Explanation

### Trigger (`on`)

```yaml
on:
  push:
    branches: [main]
  pull_request:
```

- `push: branches: [main]` — triggers the scan when commits land on `main` directly (e.g., from a merge).
- `pull_request` — triggers on every pull request event (opened, synchronised, reopened), enabling the scan to block PR merges.

There is no `permissions: {}` at the workflow level here because `workflow_call` jobs inherit permissions from the caller job's `permissions` block, not the workflow level. However, adding `permissions: {}` at the workflow level is valid and adds defence-in-depth.

### Job: secret-scan

```yaml
jobs:
  secret-scan:
    permissions:
      contents: read
    uses: your-org/security-workflows/.github/workflows/secret-scan.yml@main
```

- `permissions: contents: read` — grants the minimum permission needed to clone the repository. This is passed through to the called workflow.
- `uses: your-org/security-workflows/.github/workflows/secret-scan.yml@main` — delegates to the central engine workflow. Replace `your-org/security-workflows` with your actual organisation and repository name.
- `@main` — references the `main` branch of the security workflows repository. In production, pin this to a specific SHA or tag (see "Pinning the Engine Reference" below).

Note: The job name `secret-scan` becomes the status check name in branch protection if the engine does not override it with a `name:` field on its own job.

## Variant: With Input Overrides

If the engine workflow accepts `inputs`, override them from the caller:

```yaml
# .github/workflows/secret-scan.yml
name: Security Scan

on:
  push:
    branches: [main]
  pull_request:

jobs:
  secret-scan:
    permissions:
      contents: read
    uses: your-org/security-workflows/.github/workflows/secret-scan.yml@main
    with:
      scan-level: verified,unknown
```

The `with:` block maps directly to the engine workflow's `inputs:` declarations. The engine defines what inputs are available and their defaults; callers may provide values for any input marked as `required: false`.

## Variant: With Explicit Secrets

If the engine requires a specific secret (e.g., a PAT for scanning private repositories or to avoid GitHub API rate limits), pass it explicitly rather than inheriting all secrets:

```yaml
# .github/workflows/secret-scan.yml
name: Security Scan

on:
  push:
    branches: [main]
  pull_request:

jobs:
  secret-scan:
    permissions:
      contents: read
    uses: your-org/security-workflows/.github/workflows/secret-scan.yml@main
    secrets:
      SCANNING_TOKEN: ${{ secrets.GITHUB_PAT_FOR_SCANNING }}
```

Using `secrets:` with explicit names rather than `secrets: inherit` means only the named secret is forwarded to the engine, following the principle of least privilege.

## Pinning the Engine Reference

For production use, pin the engine to a specific commit SHA instead of a branch name:

```yaml
jobs:
  secret-scan:
    permissions:
      contents: read
    # SHA of the engine workflow commit — update via Dependabot or manually
    uses: your-org/security-workflows/.github/workflows/secret-scan.yml@a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2
```

This prevents a compromise or accidental change to the `main` branch of the security workflows repository from immediately affecting all caller repositories.

Enable Dependabot to manage these SHA pins automatically:

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

## Notes

- Application teams should not modify the engine workflow — overrides should only use the engine's published `inputs:` interface.
- The status check name that appears in branch protection is determined by the `name:` field on the engine's job (or the job key if no `name:` is set). Coordinate with the security team when configuring required checks.
- The `workflow_call` trigger in the engine means the engine workflow cannot be triggered directly — only via a caller.

## See Also

- [reusable-called-workflow.md](./reusable-called-workflow.md) — The engine workflow this caller invokes
- [../patterns/reusable-workflow-pattern.md](../patterns/reusable-workflow-pattern.md) — Pattern explanation and organisational deployment model
- [branch-protection-required-checks.md](./branch-protection-required-checks.md) — Enforcing the scan as a merge gate
