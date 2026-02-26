---
title: "Template Repository Model for TruffleHog"
tags: [reusable-workflow, template-repository, workflow-call, organisation, versioning]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "concepts"
---

# Template Repository Model for TruffleHog

## Overview

When deploying TruffleHog across an organisation with many repositories, the naive approach is to copy a workflow file into every repository. This creates a maintenance problem: updating the scan configuration, fixing a security issue, or bumping the TruffleHog version requires opening a PR against every repository.

GitHub provides two mechanisms for reusing workflow definitions. Understanding the difference between them is essential for choosing the right approach.

---

## Mechanism 1: Starter Workflows (Copied Templates)

Starter workflows are YAML files stored in an organisation's `.github` repository under `.github/workflow-templates/`. When a developer creates a new workflow in any repository in the organisation, these templates appear as options in the workflow editor.

Key characteristic: **a starter workflow is copied into the consuming repository at creation time**. After that, it is independent. Updates to the template do not propagate to repositories that already adopted it.

Use starter workflows when:
- You want to help teams bootstrap with a good initial configuration
- Individual repositories need to customise the workflow
- You do not need to enforce identical behaviour across all repos

---

## Mechanism 2: Reusable Workflows (Runtime Invocation)

A reusable workflow is a workflow file that exposes a `workflow_call:` trigger. Other workflows invoke it using `uses: org/repo/.github/workflows/engine.yml@ref`. At runtime, GitHub fetches and executes the called workflow — **it is not copied**. Every invocation runs the current version of the called workflow.

This is the right model for organisation-wide TruffleHog enforcement:

- Update the engine workflow once → all callers automatically use the new version
- Enforce security controls centrally (permissions, SHA pins) that callers cannot override
- Individual repositories have minimal, uneditable caller workflows

---

## Reusable Workflow Architecture

```
org/.github repository
└── .github/workflows/
    └── trufflehog-engine.yml   ← Reusable workflow (workflow_call trigger)

Any repository in org
└── .github/workflows/
    └── secret-scan.yml         ← Thin caller (3–10 lines)
```

The thin caller in each repository:

```yaml
name: Secret Scan
on:
  push: {}
  pull_request: {}

jobs:
  scan:
    uses: org/.github/.github/workflows/trufflehog-engine.yml@main
    secrets: inherit
```

The engine workflow handles everything: checkout configuration, TruffleHog version pinning, flag selection, output formatting.

---

## Secrets Handling

Reusable workflows have two options for receiving secrets:

### `secrets: inherit`

```yaml
jobs:
  scan:
    uses: org/.github/.github/workflows/engine.yml@main
    secrets: inherit
```

Passes all caller secrets to the called workflow. Convenient, but violates least-privilege if the engine workflow does not need all secrets.

### Explicit Secrets

```yaml
jobs:
  scan:
    uses: org/.github/.github/workflows/engine.yml@main
    secrets:
      TRUFFLEHOG_TOKEN: ${{ secrets.GITHUB_PAT_FOR_SCANNING }}
```

Only the named secret is available to the called workflow. Preferred for security.

### Environment Secrets Limitation

**Environment secrets cannot be passed to reusable workflows.** This is a confirmed GitHub platform limitation that affects all `workflow_call` consumers. If your organisation stores credentials in GitHub Environments (e.g., production API keys attached to a `production` environment), those environment secrets are not accessible inside a called reusable workflow — only repository-level and organisation-level secrets can be passed. Use repository secrets instead for any value that a reusable workflow needs.

---

## Versioning the Engine Workflow

The caller's `uses:` reference determines which version of the engine runs.

| Reference Style | Behaviour | Risk |
|----------------|-----------|------|
| `@main` | Always runs latest | Breaking changes affect all callers immediately |
| `@v1` | Runs latest commit with tag `v1` | Tags are mutable — see CVE-2025-30066 |
| `@v1.2.3` | Specific release | Still mutable (tags can be moved) |
| `@abc123def456...` (40-char SHA) | Exact commit | Immutable — cannot be changed |

**Recommendation**: use a full SHA pin for production, with Dependabot to keep it updated.

```yaml
uses: org/.github/.github/workflows/trufflehog-engine.yml@a1b2c3d4e5f6...
```

### Nested Reusable Workflows

Reusable workflows can call other reusable workflows, up to **10 levels** of nesting. Each level can only maintain or decrease the permissions granted by the caller — nested workflows cannot escalate permissions.

---

## Organisation Access Configuration

By default, a reusable workflow in `org/repo` can only be called from `org/repo`. To allow other repositories in the organisation to call it:

1. Navigate to the engine workflow's repository
2. Go to **Settings > Actions > General**
3. Under "Access", select **"Accessible from repositories in the organization"**

This setting must be configured before any caller can use the workflow.

---

## Starter Workflow Setup

To create starter workflows that appear in every repository's workflow editor:

1. Create or use the organisation's `.github` repository
2. Add files under `.github/workflow-templates/`
3. Include a matching `.properties.json` metadata file:

```json
{
  "name": "TruffleHog Secret Scan",
  "description": "Scans repository for leaked credentials using TruffleHog",
  "iconName": "octicon shield",
  "categories": ["security"]
}
```

Starter workflows are useful for teams that want to customise their scan configuration but still need a good starting point.

---

## Which Mechanism to Choose

| Scenario | Recommended Mechanism |
|----------|-----------------------|
| Enforce identical scanning across all org repos | Reusable workflow |
| Let teams customise their scan config | Starter workflow |
| Central security team controls TruffleHog version | Reusable workflow |
| Fast initial adoption across new repos | Starter workflow |
| Audit that all repos are running scans | Reusable workflow (centralised logs) |

---

## See Also

- [../patterns/reusable-workflow-pattern.md](../patterns/reusable-workflow-pattern.md) — Implementation pattern
- [../examples/reusable-called-workflow.md](../examples/reusable-called-workflow.md) — Full engine workflow YAML
- [../examples/reusable-caller-workflow.md](../examples/reusable-caller-workflow.md) — Minimal caller YAML
- [../guides/creating-template-repository.md](../guides/creating-template-repository.md) — Step-by-step setup guide
- [github-actions-security-model.md](./github-actions-security-model.md) — Security model and SHA pinning
