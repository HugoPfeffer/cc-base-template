---
title: "Index — trufflehog-github-actions-ci"
tags: [index, navigation, trufflehog, github-actions, secret-scanning, ci-cd, template-repository, reusable-workflow, pre-commit, troubleshooting, configuration]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "root"
---

# TruffleHog GitHub Actions CI — Documentation Index

## Quick Navigation

| Section | Description |
|---------|-------------|
| [Overview](./overview.md) | Executive summary, quick-start, architecture, and tool comparison |
| [Glossary](./glossary.md) | Key terms and definitions |
| [Concepts](./concepts/README.md) | Core concepts and fundamentals |
| [Patterns](./patterns/README.md) | When and why to use each approach |
| [Examples](./examples/README.md) | Complete, ready-to-use code |
| [Guides](./guides/README.md) | Step-by-step how-to instructions |
| [Troubleshooting](./troubleshooting/README.md) | Problems and solutions |
| [References](./references/README.md) | External sources and further reading |

---

## Concepts

| File | Description |
|------|-------------|
| [concepts/trufflehog-architecture.md](./concepts/trufflehog-architecture.md) | Engine pipeline, CLI reference, JSON output format |
| [concepts/detection-engine.md](./concepts/detection-engine.md) | Aho-Corasick pre-filter, regex matching, verification flow, deduplication |
| [concepts/github-actions-security-model.md](./concepts/github-actions-security-model.md) | Permissions, triggers, token scoping, SHA pinning, hardening |
| [concepts/template-repository-model.md](./concepts/template-repository-model.md) | Reusable workflows, starter templates, versioning, org access |
| [concepts/secret-scanning-fundamentals.md](./concepts/secret-scanning-fundamentals.md) | Secret types, detection methods, verification states, false positives |

---

## Patterns

| File | Description |
|------|-------------|
| [patterns/ci-scan-on-push.md](./patterns/ci-scan-on-push.md) | Push event scanning pattern |
| [patterns/ci-scan-on-pull-request.md](./patterns/ci-scan-on-pull-request.md) | PR diff scanning to block merges containing secrets |
| [patterns/full-history-scan.md](./patterns/full-history-scan.md) | Scheduled full-history audit of all commits |
| [patterns/diff-only-scan.md](./patterns/diff-only-scan.md) | `--since-commit` and `--branch` for targeted PR diffs |
| [patterns/reusable-workflow-pattern.md](./patterns/reusable-workflow-pattern.md) | Central engine + thin caller pattern for org-wide enforcement |
| [patterns/pre-commit-to-ci-layered-defense.md](./patterns/pre-commit-to-ci-layered-defense.md) | Pre-commit hooks + CI as layered defence strategy |
| [patterns/binary-install-vs-official-action.md](./patterns/binary-install-vs-official-action.md) | Trade-offs between install script and Docker action |

---

## Examples

| File | Description |
|------|-------------|
| [examples/trufflehog-git-scan-workflow.md](./examples/trufflehog-git-scan-workflow.md) | Complete push + PR workflow YAML |
| [examples/trufflehog-pr-diff-scan-workflow.md](./examples/trufflehog-pr-diff-scan-workflow.md) | PR-only diff scan with JSON output and step summary |
| [examples/reusable-caller-workflow.md](./examples/reusable-caller-workflow.md) | Minimal caller workflow YAML |
| [examples/reusable-called-workflow.md](./examples/reusable-called-workflow.md) | Full reusable engine workflow YAML |
| [examples/config-yaml-with-allowlist.md](./examples/config-yaml-with-allowlist.md) | `config.yaml` with custom detectors and exclusions |
| [examples/custom-detector-config.md](./examples/custom-detector-config.md) | Custom regex detector with verification webhook |
| [examples/branch-protection-required-checks.md](./examples/branch-protection-required-checks.md) | Branch protection setup for enforcing required scans |

---

## Guides

| File | Description |
|------|-------------|
| [guides/local-trufflehog-installation.md](./guides/local-trufflehog-installation.md) | All installation methods (install script, Docker, Homebrew, action) |
| [guides/creating-template-repository.md](./guides/creating-template-repository.md) | Step-by-step template repository setup with workflows |
| [guides/configuring-detectors.md](./guides/configuring-detectors.md) | Built-in and custom detector configuration |
| [guides/suppressing-false-positives.md](./guides/suppressing-false-positives.md) | All false positive suppression methods |
| [guides/handling-confirmed-leak.md](./guides/handling-confirmed-leak.md) | Incident response when a verified secret is found |
| [guides/shallow-clone-fix.md](./guides/shallow-clone-fix.md) | `fetch-depth: 0` explanation and fix |

---

## Troubleshooting

| File | Description |
|------|-------------|
| [troubleshooting/false-positives-common-cases.md](./troubleshooting/false-positives-common-cases.md) | Common false positive sources and suppression strategies |
| [troubleshooting/shallow-clone-git-history.md](./troubleshooting/shallow-clone-git-history.md) | Shallow clone issues preventing history scanning in CI |
| [troubleshooting/runner-permission-errors.md](./troubleshooting/runner-permission-errors.md) | Docker, permissions, and self-hosted runner issues |
| [troubleshooting/verification-rate-limits.md](./troubleshooting/verification-rate-limits.md) | Rate limiting during live credential verification |
| [troubleshooting/large-repo-performance.md](./troubleshooting/large-repo-performance.md) | Performance tuning for large or monorepo codebases |

---

## References

| File | Description |
|------|-------------|
| [references/sources.md](./references/sources.md) | All 16 verified sources with URLs, confidence ratings, and claims |

---

## Tag Index

| Tag | Files |
|-----|-------|
| `trufflehog` | overview, concepts/trufflehog-architecture, concepts/detection-engine, all examples |
| `github-actions` | concepts/github-actions-security-model, all patterns, all examples |
| `security` | concepts/github-actions-security-model, examples/branch-protection-required-checks |
| `ci-cd` | all patterns, all examples |
| `secret-scanning` | concepts/secret-scanning-fundamentals, concepts/detection-engine, all patterns |
| `template-repository` | concepts/template-repository-model, guides/creating-template-repository |
| `reusable-workflow` | concepts/template-repository-model, patterns/reusable-workflow-pattern, examples/reusable-caller-workflow, examples/reusable-called-workflow |
| `pre-commit` | patterns/pre-commit-to-ci-layered-defense |
| `troubleshooting` | troubleshooting/false-positives-common-cases, troubleshooting/shallow-clone-git-history, troubleshooting/runner-permission-errors, troubleshooting/verification-rate-limits, troubleshooting/large-repo-performance |
| `configuration` | guides/configuring-detectors, examples/config-yaml-with-allowlist, examples/custom-detector-config |

---

## Reading Paths

### New to TruffleHog

1. [concepts/secret-scanning-fundamentals.md](./concepts/secret-scanning-fundamentals.md) — Understand what secret scanning does
2. [concepts/trufflehog-architecture.md](./concepts/trufflehog-architecture.md) — How TruffleHog works internally
3. [guides/local-trufflehog-installation.md](./guides/local-trufflehog-installation.md) — Install TruffleHog locally
4. [examples/trufflehog-git-scan-workflow.md](./examples/trufflehog-git-scan-workflow.md) — Your first workflow

### Single Repository CI Setup

1. [patterns/ci-scan-on-push.md](./patterns/ci-scan-on-push.md) — Push event scanning
2. [patterns/ci-scan-on-pull-request.md](./patterns/ci-scan-on-pull-request.md) — PR diff scanning
3. [examples/trufflehog-git-scan-workflow.md](./examples/trufflehog-git-scan-workflow.md) — Complete workflow YAML
4. [examples/branch-protection-required-checks.md](./examples/branch-protection-required-checks.md) — Enforce the scan as a required check

### Organization-Scale Deployment

1. [concepts/template-repository-model.md](./concepts/template-repository-model.md) — Understand reusable vs starter workflows
2. [patterns/reusable-workflow-pattern.md](./patterns/reusable-workflow-pattern.md) — Central engine + thin caller pattern
3. [examples/reusable-called-workflow.md](./examples/reusable-called-workflow.md) — Full reusable engine YAML
4. [examples/reusable-caller-workflow.md](./examples/reusable-caller-workflow.md) — Minimal caller YAML
5. [guides/creating-template-repository.md](./guides/creating-template-repository.md) — Step-by-step setup

### Security Hardening

1. [concepts/github-actions-security-model.md](./concepts/github-actions-security-model.md) — Permissions, triggers, SHA pinning
2. [patterns/pre-commit-to-ci-layered-defense.md](./patterns/pre-commit-to-ci-layered-defense.md) — Layered defense strategy
3. [guides/suppressing-false-positives.md](./guides/suppressing-false-positives.md) — Manage noise without weakening coverage

### Incident Response

1. [guides/handling-confirmed-leak.md](./guides/handling-confirmed-leak.md) — Immediate response to a verified finding
2. [troubleshooting/verification-rate-limits.md](./troubleshooting/verification-rate-limits.md) — When verification is throttled
3. [troubleshooting/false-positives-common-cases.md](./troubleshooting/false-positives-common-cases.md) — Confirm it is not a false positive
