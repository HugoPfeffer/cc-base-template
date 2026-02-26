---
title: "Verified Sources — TruffleHog GitHub Actions CI"
tags: [references, sources, citations, trufflehog, github-actions, secret-scanning]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "references"
---

# Verified Sources

All sources used to produce this documentation domain, with confidence ratings, the claims they support, and which documentation files reference each source.

---

## HIGH Confidence Sources

These sources are primary documentation, official source code, or official security advisories. Claims derived from them are treated as verified facts.

---

### 1. TruffleHog action.yml (main branch)

- **URL**: https://github.com/trufflesecurity/trufflehog/blob/main/action.yml
- **Type**: Primary — official source code
- **Confidence**: HIGH
- **Claims supported**:
  - Official action is a composite action wrapping Docker
  - Container image: `ghcr.io/trufflesecurity/trufflehog:${VERSION}`
  - Inputs: `path`, `base`, `head`, `extra_args`, `version`
  - Auto-injected flags: `--fail`, `--no-update`, `--github-actions`
  - Push event trigger: base = `github.event.before`, head = `github.event.after`
  - PR trigger: base = `github.event.pull_request.base.sha`, head = `github.event.pull_request.head.sha`
  - Schedule/dispatch triggers full scan (no range restriction)
- **Referenced in**: [../concepts/trufflehog-architecture.md](../concepts/trufflehog-architecture.md), [../patterns/ci-scan-on-push.md](../patterns/ci-scan-on-push.md), [../patterns/ci-scan-on-pull-request.md](../patterns/ci-scan-on-pull-request.md), [../patterns/binary-install-vs-official-action.md](../patterns/binary-install-vs-official-action.md)

---

### 2. TruffleHog .pre-commit-hooks.yaml

- **URL**: https://github.com/trufflesecurity/trufflehog/blob/main/.pre-commit-hooks.yaml
- **Type**: Primary — official source code
- **Confidence**: HIGH
- **Claims supported**:
  - Official hook command: `trufflehog git file://. --since-commit HEAD --results=verified --fail --trust-local-git-config`
  - Hook ID: `trufflehog`
  - Uses pre-commit framework with `repo: https://github.com/trufflesecurity/trufflehog`
- **Referenced in**: [../patterns/pre-commit-to-ci-layered-defense.md](../patterns/pre-commit-to-ci-layered-defense.md)

---

### 3. TruffleHog pkg/config/config.go

- **URL**: https://github.com/trufflesecurity/trufflehog/blob/main/pkg/config/config.go
- **Type**: Primary — official source code
- **Confidence**: HIGH
- **Claims supported**:
  - `config.yaml` uses `detectors:` key
  - `CustomRegexWebhook` object fields: name, keywords, regex, entropy, exclude_words, exclude_regexes_capture, exclude_regexes_match, validations, verify, verificationUrl
  - Config parsing uses protoyaml
  - Verification webhook POST format
- **Referenced in**: [../guides/configuring-detectors.md](../guides/configuring-detectors.md), [../examples/custom-detector-config.md](../examples/custom-detector-config.md), [../examples/config-yaml-with-allowlist.md](../examples/config-yaml-with-allowlist.md)

---

### 4. TruffleHog releases v3.93.4

- **URL**: https://github.com/trufflesecurity/trufflehog/releases/tag/v3.93.4
- **Type**: Primary — official release
- **Confidence**: HIGH
- **Claims supported**:
  - Latest version as of February 2026
  - Version number used in all workflow examples
- **Referenced in**: [../overview.md](../overview.md), all examples

---

### 5. TruffleHog issue #578 (SARIF declined)

- **URL**: https://github.com/trufflesecurity/trufflehog/issues/578
- **Type**: Primary — official GitHub issue
- **Confidence**: HIGH
- **Claims supported**:
  - SARIF output not supported (declined by maintainers December 2023)
  - Community workaround exists: narendrapalla486/trufflehog-sarif (unofficial)
- **Referenced in**: [../overview.md](../overview.md), [../glossary.md](../glossary.md)

---

### 6. CISA Advisory CVE-2025-30066

- **URL**: https://www.cisa.gov/news-events/alerts/2025/03/18/supply-chain-compromise-third-party-tj-actionschanged-files-cve-2025-30066
- **Type**: Primary — official US government security advisory
- **Confidence**: HIGH
- **Claims supported**:
  - tj-actions/changed-files supply-chain attack
  - March 2025 date
  - 23,000+ repositories affected
  - Mutable tags as the attack vector
  - CVE identifier: CVE-2025-30066
- **Referenced in**: [../concepts/github-actions-security-model.md](../concepts/github-actions-security-model.md), [../glossary.md](../glossary.md)

---

### 7. TruffleHog README

- **URL**: https://github.com/trufflesecurity/trufflehog
- **Type**: Primary — official documentation
- **Confidence**: HIGH
- **Claims supported**:
  - Go rewrite (TruffleHog v3)
  - AGPL-3.0 license
  - 24.7k GitHub stars (as of research date)
  - Install script command: `curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh | sh -s -- -b /usr/local/bin`
  - Docker run command
  - All scan subcommands (git, github, filesystem, s3, etc.)
  - Exit code behaviour: 0 = clean, 183 = findings detected, other = scan error
  - `--fail` flag requirement to enable exit code 183
- **Referenced in**: [../concepts/trufflehog-architecture.md](../concepts/trufflehog-architecture.md), [../guides/local-trufflehog-installation.md](../guides/local-trufflehog-installation.md)

---

### 8. TruffleHog CUSTOM_DETECTORS.md

- **URL**: https://github.com/trufflesecurity/trufflehog/blob/main/pkg/custom_detectors/CUSTOM_DETECTORS.md
- **Type**: Primary — official documentation
- **Confidence**: HIGH
- **Claims supported**:
  - Custom detector configuration schema
  - Verification webhook request format (POST JSON body)
  - Verification webhook response format (200 = valid, non-200 = invalid)
  - Named capture group regex requirement (`(?P<name>...)`)
- **Referenced in**: [../guides/configuring-detectors.md](../guides/configuring-detectors.md), [../examples/custom-detector-config.md](../examples/custom-detector-config.md)

---

### 9. TruffleHog official docs

- **URL**: https://docs.trufflesecurity.com/
- **Type**: Primary — official documentation site
- **Confidence**: HIGH
- **Claims supported**:
  - Pre-commit hook configuration and setup
  - Custom detector documentation
  - Customizing detection (allowlists, exclusions)
  - General TruffleHog usage and configuration
  - Detector list and coverage
- **Referenced in**: [../concepts/detection-engine.md](../concepts/detection-engine.md), [../guides/configuring-detectors.md](../guides/configuring-detectors.md)

---

### 10. Medium: Scaling Secret Detection with TruffleHog Reusable Workflows (October 2025)

- **URL**: https://medium.com/@oyesanyf/scaling-secret-detection-across-your-organization-with-trufflehog-and-reusable-github-actions-4ff10df5998e
- **Type**: Secondary — practitioner article
- **Confidence**: HIGH (content verified against GitHub documentation)
- **Claims supported**:
  - `workflow_call` trigger mechanism and configuration
  - `secrets: inherit` vs explicit secrets declaration
  - Environment secrets limitation with reusable workflows
  - Nested reusable workflow depth limit (10 levels)
  - Permission inheritance rules for called workflows
  - Organisation access settings for cross-repo workflows
  - Org-wide deployment patterns
- **Referenced in**: [../concepts/template-repository-model.md](../concepts/template-repository-model.md), [../patterns/reusable-workflow-pattern.md](../patterns/reusable-workflow-pattern.md), [../examples/reusable-called-workflow.md](../examples/reusable-called-workflow.md)

---

### 11. howtorotate.com

- **URL**: https://howtorotate.com
- **Type**: Primary — specialist reference site
- **Confidence**: HIGH
- **Claims supported**:
  - Service-specific credential rotation procedures
  - AWS access key rotation workflow
  - GitHub personal access token rotation workflow
  - Stripe API key rotation workflow
  - Step-by-step revocation and replacement procedures
- **Referenced in**: [../guides/handling-confirmed-leak.md](../guides/handling-confirmed-leak.md)

---

## MEDIUM Confidence Sources

These sources are third-party blog posts, security vendor guides, or community-derived documentation. Claims derived from them are cross-referenced against HIGH confidence sources where possible.

---

### 12. DeepWiki TruffleHog Architecture Documentation

- **URL**: https://deepwiki.com/trufflesecurity/trufflehog/
- **Type**: Secondary — code-derived architecture analysis
- **Confidence**: MEDIUM
- **Claims supported**:
  - Engine pipeline stage sequence (source → chunker → detector → verifier → deduplicator)
  - Aho-Corasick pre-filter description and role
  - Chunk processing model (byte slice + metadata)
- **Referenced in**: [../concepts/detection-engine.md](../concepts/detection-engine.md)

---

### 13. GitGuardian GitHub Actions Security Cheat Sheet (January 2026)

- **URL**: https://blog.gitguardian.com/github-actions-security-cheat-sheet/
- **Type**: Secondary — security vendor guide
- **Confidence**: MEDIUM
- **Claims supported**:
  - `permissions: {}` deny-all baseline recommendation
  - `pull_request_target` trigger danger and attack scenarios
  - SHA pinning recommendations and tooling
  - `persist-credentials: false` checkout option
  - CODEOWNERS for workflow file protection
- **Referenced in**: [../concepts/github-actions-security-model.md](../concepts/github-actions-security-model.md)

---

### 14. Orca Security GitHub Actions Hardening (November 2025)

- **URL**: https://orca.security/resources/blog/github-actions-hardening/
- **Type**: Secondary — security vendor guide
- **Confidence**: MEDIUM
- **Claims supported**:
  - zizmor static analysis tool for Actions YAML
  - Self-hosted runner risk analysis (PyTorch incident reference)
  - Attack surface taxonomy for GitHub Actions
- **Referenced in**: [../concepts/github-actions-security-model.md](../concepts/github-actions-security-model.md)

---

### 15. Wiz GitHub Actions Security Guide (May 2025)

- **URL**: https://www.wiz.io/blog/github-actions-security-guide
- **Type**: Secondary — security vendor guide
- **Confidence**: MEDIUM
- **Claims supported**:
  - Self-hosted runner persistent state risk
  - PyTorch self-hosted runner compromise incident details
  - Misconfigured `pull_request_target` attack scenarios
- **Referenced in**: [../concepts/github-actions-security-model.md](../concepts/github-actions-security-model.md)

---

### 16. AppSec Santa: TruffleHog vs Gitleaks Comparison (February 2026)

- **URL**: https://appsecsanta.com/gitleaks-vs-trufflehog
- **Type**: Secondary — tool comparison article
- **Confidence**: MEDIUM
- **Claims supported**:
  - Gitleaks: MIT license, ~150 detectors, no live verification, SARIF supported
  - detect-secrets (Yelp): Apache-2.0, no live verification, SARIF not supported
  - GitHub native scanning: proprietary, partner verification only, SARIF supported natively
  - TruffleHog live verification as primary differentiator
- **Referenced in**: [../overview.md](../overview.md)

---

## Source Statistics

| Confidence | Count |
|-----------|-------|
| HIGH | 11 |
| MEDIUM | 5 |
| **Total** | **16** |

---

## See Also

- [README.md](./README.md) — References section overview
- [../METADATA.md](../METADATA.md) — Coverage summary and research status
- [../overview.md](../overview.md) — Domain overview with tool comparison table
