---
title: "Binary Install vs Official Action"
tags: [pattern, binary-install, docker-action, trade-offs, exit-code]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "patterns"
---

# Pattern: Binary Install vs Official Action

## Problem

TruffleHog can be run in GitHub Actions two ways: using the official `trufflesecurity/trufflehog` action, or installing the binary via a shell script and running it directly. Each has trade-offs that affect flexibility, security, and maintenance.

## The Two Approaches

### Approach A: Official Action

```yaml
- uses: trufflesecurity/trufflehog@v3.93.4
  with:
    extra_args: --results=verified,unknown
```

The official action is a composite action that:
1. Determines the version to use (from the `version` input, default: same as action tag)
2. Runs `docker run ghcr.io/trufflesecurity/trufflehog:<version> git ...` as a container step
3. Automatically computes base/head from the event context
4. **Always injects**: `--fail`, `--no-update`, `--github-actions`

### Approach B: Binary Install

```yaml
- name: Install TruffleHog
  run: |
    curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh \
      | sh -s -- -b /usr/local/bin v3.93.4

- name: Scan
  run: |
    trufflehog git \
      --since-commit "${{ github.event.pull_request.base.sha }}" \
      --branch "${{ github.event.pull_request.head.ref }}" \
      --fail \
      --json \
      file://"$GITHUB_WORKSPACE"
```

---

## Comparison

| Aspect | Official Action | Binary Install |
|--------|----------------|----------------|
| Setup complexity | Zero (one `uses:` line) | ~5 lines (install script) |
| Auto base/head detection | Yes | Manual |
| Forced flags | `--fail`, `--no-update`, `--github-actions` | None |
| Can disable `--fail` | No | Yes |
| Exit code control | Fixed (0 or 183) | Full control |
| JSON + summary pattern | Workaround needed | Native |
| Docker dependency | Yes (wraps Docker) | No |
| Air-gapped runners | Problematic | Works (binary pre-bundled) |
| Custom config.yaml | Via `extra_args --config` | Via `--config` |
| SHA pinning | Pin action tag to SHA | Pin binary version in install command |

---

## When to Use the Official Action

Choose the official action when:
- You want minimal setup and zero configuration
- The auto-injected flags (`--fail`, `--no-update`, `--github-actions`) suit your workflow
- You are using GitHub-hosted runners with Docker available
- You want GitHub Actions annotations (`:warning:` messages in the PR diff view) — these come from `--github-actions` which is auto-injected

```yaml
# Best-practice official action setup
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
  with:
    fetch-depth: 0
    persist-credentials: false
- uses: trufflesecurity/trufflehog@v3.93.4
  with:
    extra_args: --results=verified,unknown
```

## Recommendation for Template Repositories

When building a **template repository** (a starting point that other repositories are created from), the binary install approach is recommended. Template repositories typically need:

- Full flag control to accommodate diverse downstream workflows
- The ability to run both `git` and `filesystem` scans in one workflow
- Custom exit code handling to generate actionable PR annotations and step summaries
- Freedom to disable `--fail` on certain steps while enforcing it on others

The official action's auto-injected flags are opinionated in ways that may conflict with template repository requirements. The binary install gives template maintainers complete control over how TruffleHog is invoked without working around the action's fixed behaviour.

## When to Use the Binary Install

Choose the binary install when:

**1. You need custom exit code handling**

The official action always exits 183 on findings. If you need to collect JSON output, post a step summary, and then fail:

```yaml
- name: Install TruffleHog
  run: |
    curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh \
      | sh -s -- -b /usr/local/bin v3.93.4

- name: Scan and collect output
  run: |
    trufflehog git --fail --json file://"$GITHUB_WORKSPACE" \
      2>/dev/null | tee /tmp/findings.ndjson || EXIT=$?
    FINDINGS=$(wc -l < /tmp/findings.ndjson)
    if [ "$FINDINGS" -gt "0" ]; then
      echo "## Findings: $FINDINGS" >> $GITHUB_STEP_SUMMARY
    fi
    exit ${EXIT:-0}
```

**2. You need to disable `--fail`**

When running TruffleHog in audit mode (report-only, no blocking):

```bash
trufflehog git --json file://. 2>/dev/null | tee findings.json
# Exits 0 even with findings
```

**3. You are on a self-hosted runner without Docker**

The official action uses Docker. On runners where Docker is unavailable, the binary install is the only option.

**4. You need a specific version not matching the action tag**

The `version` input of the official action defaults to the action's own tag version. If you need a hotfix version, use the binary install to pin independently.

---

## SHA Pinning for Both Approaches

### Official Action (pin action SHA)

```yaml
- uses: trufflesecurity/trufflehog@a1b2c3d4e5f6...  # v3.93.4
```

### Binary Install (pin version in URL)

```yaml
- run: |
    curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh \
      | sh -s -- -b /usr/local/bin v3.93.4
```

The install script accepts a version argument. Always specify an explicit version — never use `latest` in production CI.

---

## See Also

- [../concepts/trufflehog-architecture.md](../concepts/trufflehog-architecture.md) — All CLI flags
- [../guides/local-trufflehog-installation.md](../guides/local-trufflehog-installation.md) — All installation methods in detail
- [../concepts/github-actions-security-model.md](../concepts/github-actions-security-model.md) — SHA pinning rationale
- [../examples/trufflehog-git-scan-workflow.md](../examples/trufflehog-git-scan-workflow.md) — Complete push + PR workflow using the official action
- [../examples/trufflehog-pr-diff-scan-workflow.md](../examples/trufflehog-pr-diff-scan-workflow.md) — Binary install with JSON output
