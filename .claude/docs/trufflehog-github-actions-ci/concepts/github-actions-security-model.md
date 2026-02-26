---
title: "GitHub Actions Security Model"
tags: [github-actions, security, permissions, sha-pinning, codeowners, supply-chain]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "concepts"
---

# GitHub Actions Security Model

## Overview

GitHub Actions gives workflows access to repository secrets, write permissions to code, and the ability to deploy to production environments. This makes the Actions runtime an attractive target: a compromised workflow does not just run malicious code — it can exfiltrate credentials, modify source code, and corrupt releases. Understanding the security model is prerequisite to deploying TruffleHog (or any security tool) in CI.

---

## The GITHUB_TOKEN and Permissions

Every workflow run receives a `GITHUB_TOKEN` — a short-lived credential scoped to the current repository. Its default permissions depend on the organisation's settings, but they are often overly broad (read-write on `contents`, `packages`, `deployments`).

### Principle of Least Privilege

The recommended pattern is to **deny all at workflow level, then grant per job**:

```yaml
# Deny all permissions for all jobs by default
permissions: {}

jobs:
  scan:
    runs-on: ubuntu-latest
    permissions:
      contents: read  # Grant only what this job needs
    steps:
      # ...
```

For a TruffleHog scan, `contents: read` is sufficient. The scanner reads code; it never writes to the repository.

### Permissions Reference

| Use Case | Required Permissions |
|----------|---------------------|
| Scanning only | `contents: read` |
| Scan + PR comment | `contents: read`, `pull-requests: write` |
| Scan + SARIF upload | `contents: read`, `security-events: write` |
| OIDC token usage | `contents: read`, `id-token: write` |
| TruffleHog default | `contents: read` only |

All other scopes should be denied explicitly by setting `permissions: {}` at the workflow level.

---

## Trigger Selection

The trigger you choose determines what code runs and what credentials it can access.

### `pull_request` (Safe)

```yaml
on:
  pull_request: {}
```

- Runs in the context of the **fork** (if from a fork)
- Token has **read-only** access
- Cannot access repository secrets
- Safe to run on untrusted code

### `pull_request_target` (Dangerous)

```yaml
# DO NOT use this for secret scanning
on:
  pull_request_target: {}
```

- Runs in the context of the **base repository**
- Token has write access
- **Can access repository secrets**
- A malicious PR can read and exfiltrate your secrets

`pull_request_target` exists for legitimate use cases (labelling PRs from forks) but must never be combined with steps that check out or execute PR code.

### `push` and `schedule`

These triggers run in the full repository context. They are safe for secret scanning because you control what code runs. TruffleHog scans the repository; it does not execute the repository's code.

---

## SHA Pinning

### The Problem with Tags

A GitHub Action reference like `uses: some-org/some-action@v2` resolves the `v2` tag at runtime. Tags are mutable — the repository owner (or an attacker who compromises the owner) can silently redirect `v2` to a different commit.

This is exactly what happened in the tj-actions supply-chain attack (CVE-2025-30066, March 2025): the `v35` tag of `tj-actions/changed-files` was redirected to a malicious commit that printed runner environment variables (including secrets) to the workflow log. 23,000+ repositories were affected.

### The Fix: Pin to Commit SHA

```yaml
# Vulnerable — tag can be redirected
- uses: actions/checkout@v4

# Safe — SHA cannot be changed
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
```

The full 40-character SHA cannot be changed without creating a new commit, making it tamper-proof.

### Keeping Pins Current

SHA pins go stale when the action publishes security updates. Use Dependabot or Renovate to automate SHA pin updates:

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
```

---

## Protecting Workflow Files

### CODEOWNERS

Require security team review for any change to workflow files:

```
# .github/CODEOWNERS
.github/workflows/ @org/security-team
```

This ensures no one can add a malicious workflow without a security review, even if they have write access to the repository.

### Branch Protection

For the branch protection rules that enforce TruffleHog scans as required status checks, see [examples/branch-protection-required-checks.md](../examples/branch-protection-required-checks.md).

---

## Credential Hygiene in Workflows

### persist-credentials: false

```yaml
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
  with:
    fetch-depth: 0
    persist-credentials: false  # Do not store token in .git/config
```

By default, `actions/checkout` writes the `GITHUB_TOKEN` into `.git/config` for subsequent Git operations. Any step or action that runs after checkout can read this file. Disabling it reduces the blast radius if a later action is malicious.

### Secrets in Logs

Never echo secrets to stdout. GitHub Actions will mask known secret values in logs, but only secrets explicitly passed via `${{ secrets.NAME }}` — arbitrary strings that happen to be secret are not masked.

---

## Self-Hosted Runners

Self-hosted runners introduce additional risks:

- **Persistent state**: Unlike GitHub-hosted runners (which are ephemeral), self-hosted runners retain files between jobs. A malicious job can plant files that affect future jobs.
- **Network access**: Self-hosted runners may have access to internal networks, making them higher-value targets.
- **PyTorch incident**: Attackers compromised a self-hosted runner with write tokens by exploiting persistent state, demonstrating the real-world risk.

For secret scanning workflows specifically: if possible, use GitHub-hosted runners. If self-hosted runners are required, ensure they are ephemeral (torn down after each job).

---

## Static Analysis: zizmor

`zizmor` is a static analysis tool that scans GitHub Actions YAML files for security misconfigurations. It detects:

- `pull_request_target` without proper guards
- Missing `permissions: {}` denials
- Mutable tag references (not SHA-pinned)
- `run:` steps that use user-controlled input without sanitisation

Integrate it in your own CI:

```yaml
- name: Audit workflow security
  run: |
    pip install zizmor
    zizmor .github/workflows/
```

---

## Layered Security Checklist

For any TruffleHog workflow in production:

- [ ] `permissions: {}` at workflow level, `contents: read` per job
- [ ] Use `pull_request` not `pull_request_target`
- [ ] All `uses:` references pinned to full SHA
- [ ] `persist-credentials: false` on checkout
- [ ] `fetch-depth: 0` on checkout (for TruffleHog)
- [ ] CODEOWNERS protecting `.github/workflows/`
- [ ] Dependabot or Renovate updating SHA pins weekly
- [ ] Branch protection requiring TruffleHog as a required check
- [ ] zizmor in CI to catch future misconfigurations

---

## See Also

- [template-repository-model.md](./template-repository-model.md) — Enforcing these controls at org scale
- [../patterns/ci-scan-on-pull-request.md](../patterns/ci-scan-on-pull-request.md) — Trigger and permission pattern for PR scanning
- [../examples/trufflehog-git-scan-workflow.md](../examples/trufflehog-git-scan-workflow.md) — Full workflow YAML with security hardening applied
- [../examples/branch-protection-required-checks.md](../examples/branch-protection-required-checks.md) — Branch protection configuration
- [../patterns/binary-install-vs-official-action.md](../patterns/binary-install-vs-official-action.md) — SHA pinning the TruffleHog action itself
- [../glossary.md](../glossary.md) — SHA pinning, CVE-2025-30066, pull_request_target definitions
