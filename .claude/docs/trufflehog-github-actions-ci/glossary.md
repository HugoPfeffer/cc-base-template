---
title: "Glossary — TruffleHog GitHub Actions CI"
tags: [glossary, definitions, trufflehog, github-actions]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "root"
---

# Glossary

Definitions for terms used throughout this documentation domain.

---

## Aho-Corasick Pre-filter

A multi-pattern string-matching algorithm used in TruffleHog's detection engine as the first pass over each data chunk. Each detector declares one or more **keywords** — short, distinctive strings (e.g., `AKIA` for AWS access keys). The Aho-Corasick automaton scans a chunk once and identifies which detectors have at least one keyword match. Only those detectors advance to the more expensive regex phase. This keeps CPU cost proportional to matches rather than to the total number of detectors.

See: [concepts/detection-engine.md](./concepts/detection-engine.md)

---

## Base SHA / Head SHA

In GitHub Actions, the two commit SHAs that define the range of a diff scan:

- **Base SHA**: the commit before the change (older end of the range)
- **Head SHA**: the commit after the change (newer end, the one being evaluated)

For push events: base = `github.event.before`, head = `github.event.after`.
For pull requests: base = `github.event.pull_request.base.sha`, head = `github.event.pull_request.head.sha`.
For scheduled/dispatch runs: both are empty, triggering a full-history scan.

See: [concepts/trufflehog-architecture.md](./concepts/trufflehog-architecture.md)

---

## Chunk

The unit of data TruffleHog processes internally. A source (git, filesystem, S3, etc.) emits chunks — byte slices of content plus metadata (file path, commit SHA, line number). The detection pipeline processes one chunk at a time through the filter, regex, and verification stages.

---

## CODEOWNERS

A GitHub repository file (`.github/CODEOWNERS`) that assigns automatic review requirements to specific file paths. Used in CI security hardening to require the security team to approve any change to `.github/workflows/`.

See: [concepts/github-actions-security-model.md](./concepts/github-actions-security-model.md)

---

## Composite Action

A GitHub Actions action type that sequences multiple `run:` steps and `uses:` steps in a single reusable unit, defined by an `action.yml` file. The official TruffleHog action (`trufflesecurity/trufflehog`) is a composite action that wraps a Docker container call.

---

## Custom Regex Detector

A user-defined detector specified in `config.yaml` under the `detectors:` key. It consists of a name, one or more keywords, a named-group regex pattern, and optionally an entropy threshold and a verification webhook URL. TruffleHog evaluates custom detectors alongside its 700+ built-in detectors.

See: [guides/configuring-detectors.md](./guides/configuring-detectors.md), [examples/custom-detector-config.md](./examples/custom-detector-config.md)

---

## CVE-2025-30066

A supply-chain vulnerability (March 2025) in the `tj-actions/changed-files` GitHub Action. The action's mutable version tags were redirected to a malicious commit that exfiltrated repository secrets. Affected 23,000+ repositories. The root cause was tag mutability — a pinned SHA would have prevented the compromise. This event is the canonical argument for SHA pinning in GitHub Actions.

See: [concepts/github-actions-security-model.md](./concepts/github-actions-security-model.md)

---

## Deduplication

TruffleHog's built-in mechanism for suppressing duplicate findings within a single scan run. If the same raw credential value appears in multiple commits or files, it is reported only once. Deduplication is based on the raw credential value, not its location.

---

## Detector

A Go struct in TruffleHog that implements the `detectors.Detector` interface. Required methods: `Keywords() []string`, `FromData(ctx, verify bool, data []byte) ([]detectors.Result, error)`, `Type() detectorspb.DetectorType`. TruffleHog ships 700+ built-in detectors.

See: [concepts/detection-engine.md](./concepts/detection-engine.md)

---

## Diff Scan

A scan mode that inspects only the commits or files within a specified range, rather than the entire repository history. Triggered in TruffleHog with `--since-commit <SHA>` and `--branch <name>`. The official action performs a diff scan automatically when `base` and `head` inputs are provided.

See: [patterns/diff-only-scan.md](./patterns/diff-only-scan.md)

---

## Entropy

A measure of randomness in a string, calculated as Shannon entropy. High-entropy strings (typically > 3.0–4.0 bits per character) are more likely to be machine-generated secrets. TruffleHog's custom detector configuration accepts an optional `entropy` threshold to filter low-entropy matches.

---

## Exit Code 183

TruffleHog's specific exit code meaning "scan completed and findings were detected." Exit code 0 means clean (no findings). Any other non-zero code indicates a scan error. The `--fail` flag enables this behaviour; without it, TruffleHog always exits 0 regardless of findings. The official action always injects `--fail`.

See: [concepts/trufflehog-architecture.md](./concepts/trufflehog-architecture.md)

---

## fetch-depth: 0

A `actions/checkout` parameter that instructs Git to fetch the complete commit history rather than a shallow clone. Required for TruffleHog to walk git history. Default checkout depth is 1 (only the latest commit), which causes TruffleHog to miss all historical secrets.

See: [guides/shallow-clone-fix.md](./guides/shallow-clone-fix.md), [troubleshooting/shallow-clone-git-history.md](./troubleshooting/shallow-clone-git-history.md)

---

## filtered_unverified

A TruffleHog result state for findings that matched a detector's regex but were suppressed by a built-in word list (common test values, example placeholders). These represent likely false positives. Included in output only when `--results=filtered_unverified` is explicitly requested.

See: [concepts/secret-scanning-fundamentals.md](./concepts/secret-scanning-fundamentals.md)

---

## Full History Scan

A scan that walks every commit in a repository's history from the initial commit to HEAD. Triggered when TruffleHog has no base/head range to restrict to. Computationally expensive for large repositories. Typically scheduled weekly rather than run on every push.

See: [patterns/full-history-scan.md](./patterns/full-history-scan.md)

---

## NDJSON (Newline-Delimited JSON)

TruffleHog's machine-readable output format when `--json` is passed. Each finding is a single JSON object on its own line, allowing streaming processing with `jq` or log aggregation pipelines. Not SARIF; SARIF output is not supported.

---

## `permissions: {}`

A GitHub Actions workflow or job key that sets explicit permission scopes for the `GITHUB_TOKEN`. An empty object `{}` denies all permissions at the workflow level. Individual jobs then grant only what they need (e.g., `contents: read`). This is the recommended baseline for any workflow that runs untrusted code.

See: [concepts/github-actions-security-model.md](./concepts/github-actions-security-model.md)

---

## persist-credentials: false

A parameter for `actions/checkout` that prevents the action from storing the GitHub token as a Git credential. Without it, the token is written to `.git/config` and accessible to any subsequent step or action in the job.

---

## Pre-commit Hook

A Git hook that runs before each commit is recorded. TruffleHog provides an official hook via the pre-commit framework that scans staged content. Pre-commit hooks give developers immediate feedback but can be bypassed with `git commit --no-verify`. CI is the non-bypassable enforcement layer.

See: [patterns/pre-commit-to-ci-layered-defense.md](./patterns/pre-commit-to-ci-layered-defense.md)

---

## `pull_request_target`

A GitHub Actions trigger that runs in the context of the base repository (not the fork), giving it access to repository secrets. It is **dangerous** for secret scanning workflows because a malicious PR can exfiltrate those secrets. Use `pull_request` instead, which runs in a read-only fork context.

See: [concepts/github-actions-security-model.md](./concepts/github-actions-security-model.md)

---

## Reusable Workflow

A GitHub Actions workflow file that exposes a `workflow_call` trigger, allowing it to be invoked from other workflows. Used to centralise TruffleHog scanning logic in one repository while thin caller workflows in individual repositories delegate to it. Different from starter workflows (which are copied templates).

See: [concepts/template-repository-model.md](./concepts/template-repository-model.md), [patterns/reusable-workflow-pattern.md](./patterns/reusable-workflow-pattern.md)

---

## SARIF

Static Analysis Results Interchange Format — a JSON-based standard for reporting code analysis findings, natively supported by GitHub's Security tab. TruffleHog does **not** produce SARIF output (declined in issue #578, December 2023). This is a known limitation when comparing TruffleHog to Gitleaks or GitHub native scanning.

---

## SHA Pinning

The practice of referencing a GitHub Action by its full commit SHA (e.g., `uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683`) rather than a mutable tag or branch name. Prevents tag-redirect supply-chain attacks like CVE-2025-30066. The recommended approach for any production workflow.

See: [concepts/github-actions-security-model.md](./concepts/github-actions-security-model.md)

---

## Starter Workflow

A workflow YAML file stored in an organization's `.github` repository that appears as a template option when a developer creates a new workflow. Starter workflows are **copied** into the consuming repository — they are independent after creation. Distinct from reusable workflows, which are executed by reference at runtime.

See: [concepts/template-repository-model.md](./concepts/template-repository-model.md)

---

## `trufflehog:ignore`

An inline comment placed on the same line as a false positive to suppress TruffleHog findings for that specific line. The comment must appear on the exact line containing the matched credential. This is the most surgical suppression method.

See: [guides/suppressing-false-positives.md](./guides/suppressing-false-positives.md)

---

## unknown

A TruffleHog result state for findings where the detector does not support live verification. The credential format matched the detector's regex, but no API call was made (or could be made) to confirm whether the credential is active. `unknown` results should be reviewed manually; they may be valid secrets that cannot be automatically confirmed. Included in output when `--results=verified,unknown` is specified.

See: [concepts/secret-scanning-fundamentals.md](./concepts/secret-scanning-fundamentals.md)

---

## unverified

A TruffleHog result state for findings where the credential format matched a detector's regex but the live verification HTTP call failed (network error, timeout, or the service returned an ambiguous response). The credential may or may not be valid. Requires manual investigation.

See: [concepts/secret-scanning-fundamentals.md](./concepts/secret-scanning-fundamentals.md)

---

## verified

A TruffleHog result state for findings where the credential format matched and the live verification HTTP call confirmed the credential is **currently active**. These are the highest-priority findings requiring immediate credential revocation.

See: [concepts/secret-scanning-fundamentals.md](./concepts/secret-scanning-fundamentals.md), [guides/handling-confirmed-leak.md](./guides/handling-confirmed-leak.md)

---

## `workflow_call`

The GitHub Actions trigger type that makes a workflow file invocable as a reusable workflow from another workflow. Supports `inputs:`, `outputs:`, and `secrets:` declarations for parameterisation.

---

## zizmor

A static analysis tool for GitHub Actions YAML files that detects security misconfigurations — overly broad permissions, dangerous triggers (`pull_request_target`), missing SHA pins, and other hardening gaps. Recommended as a complement to TruffleHog in CI pipelines.

See: [concepts/github-actions-security-model.md](./concepts/github-actions-security-model.md)

---

## See Also

- [overview.md](./overview.md) — Domain overview
- [concepts/secret-scanning-fundamentals.md](./concepts/secret-scanning-fundamentals.md) — Detection states in depth
- [concepts/detection-engine.md](./concepts/detection-engine.md) — Engine internals
