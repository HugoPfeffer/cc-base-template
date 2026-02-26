---
title: "Examples — TruffleHog GitHub Actions CI"
tags: [examples, navigation]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "examples"
---

# Examples

Complete, copy-paste-ready workflows and configuration files for TruffleHog GitHub Actions integration.

## Files

| File | What It Demonstrates |
|------|---------------------|
| [trufflehog-git-scan-workflow.md](./trufflehog-git-scan-workflow.md) | Push + PR workflow using the official action with `--results=verified` |
| [trufflehog-pr-diff-scan-workflow.md](./trufflehog-pr-diff-scan-workflow.md) | PR-only scan using binary install with JSON output, step summary, and artifact upload |
| [reusable-caller-workflow.md](./reusable-caller-workflow.md) | Minimal caller workflow that delegates to a central engine |
| [reusable-called-workflow.md](./reusable-called-workflow.md) | Full reusable engine workflow with parameterised inputs and dual git+filesystem scan |
| [config-yaml-with-allowlist.md](./config-yaml-with-allowlist.md) | `config.yaml` with custom detector, entropy filtering, word exclusions, and path exclusion file |
| [custom-detector-config.md](./custom-detector-config.md) | Custom regex detector (`HogTokenDetector`) with verification webhook and Python server |
| [branch-protection-required-checks.md](./branch-protection-required-checks.md) | Branch protection rules (UI, CLI, Rulesets) and CODEOWNERS for workflow file protection |

## Copying Examples

All YAML in this section is production-ready with the following caveats:

1. **Action references use `@main` or `@v4`** — pin to specific SHAs or tags in production, or let Dependabot manage them.
2. **Organisation and repository names are placeholders** — replace `your-org` and `security-workflows` with your actual values.
3. **Verification webhook URLs are examples** — replace `http://localhost:8000/` and similar with your actual internal endpoints.

## Which Example to Start With

- **New to TruffleHog in CI** — start with [trufflehog-git-scan-workflow.md](./trufflehog-git-scan-workflow.md). Copy it, run it, confirm the check passes.
- **Need JSON output or step summary** — use [trufflehog-pr-diff-scan-workflow.md](./trufflehog-pr-diff-scan-workflow.md).
- **Deploying across many repositories** — set up [reusable-called-workflow.md](./reusable-called-workflow.md) first, then distribute [reusable-caller-workflow.md](./reusable-caller-workflow.md).
- **Reducing false positives** — configure [config-yaml-with-allowlist.md](./config-yaml-with-allowlist.md) with your exclusion paths.
- **Detecting organisation-specific secrets** — follow [custom-detector-config.md](./custom-detector-config.md).
- **Making the scan mandatory** — follow [branch-protection-required-checks.md](./branch-protection-required-checks.md) after the workflow is running.

## See Also

- [../patterns/README.md](../patterns/README.md) — Explains when and why to use each approach
- [../guides/README.md](../guides/README.md) — Step-by-step instructions for complex setups
- [../concepts/README.md](../concepts/README.md) — Background on how TruffleHog and GitHub Actions work
