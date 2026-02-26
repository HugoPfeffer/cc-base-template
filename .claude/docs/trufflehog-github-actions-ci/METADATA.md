---
title: "Metadata — trufflehog-github-actions-ci"
tags: [metadata]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "root"
---

# Research Metadata

| Field | Value |
|-------|-------|
| Domain | trufflehog-github-actions-ci |
| Created | 2026-02-26 |
| Last Updated | 2026-02-26 |
| Pipeline | research-pipeline v1.0.0 |
| Status | Complete |
| Research Depth | Full Research Pipeline |
| Estimated Complexity | complex |
| TruffleHog Version Covered | v3.93.4 (February 2026) |
| Total Files | 41 |
| Verified Sources | 16 |

---

## File Count by Section

| Section | File Count |
|---------|-----------|
| concepts | 5 |
| patterns | 7 |
| examples | 7 |
| guides | 6 |
| troubleshooting | 5 |
| references | 1 |
| root | 4 |
| READMEs | 6 |
| **Total** | **41** |

---

## Coverage Summary

| Area | Files Covering | Notes |
|------|----------------|-------|
| TruffleHog v3 architecture | concepts/trufflehog-architecture.md | Engine pipeline, Go rewrite, AGPL-3.0 |
| Detection engine internals | concepts/detection-engine.md | Aho-Corasick, 700+ detectors, verification states |
| GitHub Actions integration | concepts/github-actions-security-model.md, all patterns | action.yml inputs, triggers, auto-injected flags |
| CLI flags | concepts/trufflehog-architecture.md | All verified flags documented |
| Installation methods | guides/local-trufflehog-installation.md | Script, Docker, Homebrew, action |
| Configuration system | guides/configuring-detectors.md, examples/config-yaml-with-allowlist.md | config.yaml schema, custom detectors |
| Security hardening | concepts/github-actions-security-model.md, examples/branch-protection-required-checks.md | Permissions, SHA pinning, CODEOWNERS |
| Reusable workflows | concepts/template-repository-model.md, patterns/reusable-workflow-pattern.md | workflow_call, secrets:inherit, versioning |
| Pre-commit integration | patterns/pre-commit-to-ci-layered-defense.md | Official .pre-commit-hooks.yaml |
| Secret scanning fundamentals | concepts/secret-scanning-fundamentals.md | Detection methods, verification states |
| Troubleshooting | troubleshooting/*.md | SARIF gap, rate limits, shallow clones, performance |
| SARIF support | overview.md, glossary.md | Confirmed absent — issue #578 declined Dec 2023 |
| Tool comparison | overview.md | TruffleHog, Gitleaks, GitHub native, detect-secrets |
| Incident response | guides/handling-confirmed-leak.md | howtorotate.com, revocation workflow |
| False positives | guides/suppressing-false-positives.md, troubleshooting/false-positives-common-cases.md | Inline ignore, allowlist, exclude patterns |
| CI push scanning | patterns/ci-scan-on-push.md, examples/trufflehog-git-scan-workflow.md | Push event workflow |
| CI PR scanning | patterns/ci-scan-on-pull-request.md, examples/trufflehog-pr-diff-scan-workflow.md | PR diff workflow |
| Full history scanning | patterns/full-history-scan.md | Scheduled full-history audit |
| Diff-only scanning | patterns/diff-only-scan.md | --since-commit range scanning |
| Binary vs action install | patterns/binary-install-vs-official-action.md | Install method trade-offs |

---

## Source Summary

| Confidence Level | Count |
|-----------------|-------|
| HIGH | 11 |
| MEDIUM | 5 |
| **Total** | **16** |

See [references/sources.md](./references/sources.md) for full source details with URLs and claims.

---

## Revision History

| Date | Agent | Changes |
|------|-------|---------|
| 2026-02-26 | scaffold-docs.sh | Initial skeleton created |
| 2026-02-26 | research-synthesis | Full content written for all 41 files |

---

## See Also

- [INDEX.md](./INDEX.md) — Full navigation index
- [references/sources.md](./references/sources.md) — Verified sources with confidence ratings
