---
title: "Secret Scanning Fundamentals"
tags: [secret-scanning, detection, verification, false-positives, credential-types]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "concepts"
---

# Secret Scanning Fundamentals

## What Is a Secret in This Context

A "secret" in secret scanning refers to any credential that grants access to a system: API keys, access tokens, private keys, passwords, connection strings, and similar values. The defining property is that possession of the value alone is sufficient to authenticate — no other factor is needed.

Secrets end up in source code for several reasons:
- Developers hardcode values during local development and forget to remove them
- Configuration files are committed without realising they contain real credentials
- Credentials are embedded in scripts, notebooks, or test fixtures
- CI configuration files reference secrets inline rather than as environment variables

---

## Secret Types

### Structured Secrets (High Confidence Detection)

Structured secrets have a fixed, recognisable format defined by the issuing service:

| Secret Type | Example Pattern | Issuing Service |
|------------|----------------|-----------------|
| AWS Access Key | `AKIA[0-9A-Z]{16}` | Amazon Web Services |
| GitHub PAT (classic) | `ghp_[a-zA-Z0-9]{36}` | GitHub |
| GitHub PAT (fine-grained) | `github_pat_[a-zA-Z0-9_]{82}` | GitHub |
| Stripe Secret Key | `sk_live_[a-zA-Z0-9]{24}` | Stripe |
| Google API Key | `AIza[0-9A-Za-z\-_]{35}` | Google |
| Slack Bot Token | `xoxb-[0-9]+-[0-9]+-[a-zA-Z0-9]+` | Slack |

Structured secrets are the best candidates for automated detection because their format is both necessary and sufficient to identify them. TruffleHog's 700+ built-in detectors cover the structured secrets of nearly every major service.

### Unstructured Secrets (Lower Confidence Detection)

Unstructured secrets are values that look like secrets based on context or entropy but lack a distinctive pattern:

- Generic database passwords
- SSH passphrases
- Internal API tokens with organisation-specific formats
- RSA private key material (the PEM header is structured, but the key material is opaque)

TruffleHog handles some of these (PEM headers have keywords), but coverage is lower. Custom detectors can add organisation-specific patterns.

---

## Detection Methods

TruffleHog uses three signals to identify secrets:

### 1. Keyword Matching

Distinctive, service-specific substrings that almost always indicate a credential nearby (e.g., `AKIA`, `sk_live_`, `ghp_`). Used as the Aho-Corasick pre-filter gate. Rarely generates false positives alone but is insufficient by itself.

### 2. Regex Pattern Matching

Named-capture-group regexes that match the full credential format. Applied only after keyword match. Extracts the candidate credential string for verification.

### 3. Entropy Filtering

Optional Shannon entropy threshold. High-entropy strings (> 3.5 bits/char) are more likely to be machine-generated secrets than human-readable values. Used in custom detectors to filter weak matches.

---

## Verification States

TruffleHog assigns each finding one of four states after the verification phase:

### `verified`

The credential matched the detector's regex **and** a live API call to the issuing service confirmed it is currently active.

- **Action required**: Revoke the credential immediately. Removing it from code is not sufficient — the credential is already exposed in git history.
- These are the only findings that represent definite, immediate risk.

### `unverified`

The credential matched the regex but live verification was inconclusive:
- The verification HTTP call returned an error or unexpected status
- The service was unreachable (network timeout, rate limit hit)
- The service returned an ambiguous response

These findings require manual investigation. The credential may be real, rotated, or already revoked.

### `unknown`

Verification was not attempted. This happens when:
- `--no-verification` flag was passed
- The detector does not implement verification
- A custom detector has no webhook configured

Treat `unknown` findings as potentially real secrets pending review.

### `filtered_unverified`

The regex matched but the value was suppressed by TruffleHog's built-in word list of known placeholder values (`example`, `test`, `AKIAIOSFODNN7EXAMPLE`, etc.). These are almost always false positives from documentation or test code.

---

## False Positives

False positives are findings that match detection criteria but are not real secrets. They are the primary usability challenge in secret scanning.

### Common Sources

| Source | Example |
|--------|---------|
| Test fixtures | `password = "testpassword123"` |
| Documentation | AWS example keys in README files |
| Template placeholders | `API_KEY = "your-api-key-here"` |
| Committed mock data | Fake API responses in test fixtures |
| Third-party code | Vendor libraries containing example credentials |
| Rotation examples | Old keys in changelogs or migration scripts |

### False Positive Impact

False positives cause:
- Alert fatigue — developers learn to ignore scan results
- Wasted investigation time
- Pressure to disable scanning entirely

TruffleHog's live verification is the primary mitigation: a false positive string that fails verification is reported as `unverified` or `filtered_unverified`, not `verified`. Prioritising `verified` findings dramatically reduces false positive burden.

---

## The Most Important Principle

**Removing a secret from source code does not fix the problem.**

Once a credential is committed to a git repository:
1. It exists in git history indefinitely (until history is rewritten or the repository is deleted)
2. Anyone with past or present access to the repository may have a clone with the secret
3. Any automated system that mirrored the repository (CI, backup) may have a copy

The only correct response to a `verified` finding is to **revoke the credential at the issuing service** and issue a new one. Code remediation (removing the value, rewriting history) is a secondary step to prevent future exposure.

See [../guides/handling-confirmed-leak.md](../guides/handling-confirmed-leak.md) for the full incident response procedure.

---

## Scanning Scope Trade-offs

| Scan Scope | Catches | Cost |
|------------|---------|------|
| Git history scan | Catches historical secrets, full repo audit | High — needs full clone |
| Filesystem scan | Catches current secrets only, no history | Fast — no history needed |
| Both combined | Maximum coverage | Some duplicate findings |
| PR diff only | Secrets in this PR | Very low |
| Scheduled weekly full scan | Historical + new | Medium (amortised) |

The recommended strategy:
- PR scans (fast, catches new introductions before merge)
- Push scans (catches anything that merged outside of PRs)
- Weekly full-history schedule (audits the entire codebase periodically)

---

## Tool Comparison

Several open-source and commercial tools perform secret scanning. Key differences:

| Tool | License | Language | Detectors | Live Verification | SARIF Output |
|------|---------|----------|-----------|-------------------|--------------|
| TruffleHog | AGPL-3.0 | Go | 700+ built-in | Yes | No |
| Gitleaks | MIT | Go | ~150 rules | No | Yes |
| GitHub Native | Proprietary | — | Partner integrations | Push-time detection | Yes |
| detect-secrets (Yelp) | Apache-2.0 | Python | Configurable plugins | No | No (baseline files) |

TruffleHog's distinguishing feature is live verification. Gitleaks has broader adoption in pipelines that need SARIF for GitHub Code Scanning integration. detect-secrets uses a baseline file approach suited to repositories that already contain known false positives.

---

## Unstructured Secrets

**Unstructured secrets** lack a fixed, recognisable format and are harder to detect automatically:

- Generic database passwords (e.g., `password: super_secret_123`)
- SSH passphrases and private key passphrases
- Internal API tokens following no public standard
- Bearer tokens assigned by homegrown systems

TruffleHog handles PEM-wrapped private keys (the header `-----BEGIN RSA PRIVATE KEY-----` is a keyword) but coverage for fully unstructured values is limited. Entropy analysis raises the probability of detection but also increases false positives. Custom detectors can be added for organisation-specific token formats.

---

## See Also

- [detection-engine.md](./detection-engine.md) — How detection works mechanically
- [trufflehog-architecture.md](./trufflehog-architecture.md) — CLI flags for controlling result states
- [../guides/handling-confirmed-leak.md](../guides/handling-confirmed-leak.md) — What to do when a verified finding appears
- [../guides/suppressing-false-positives.md](../guides/suppressing-false-positives.md) — How to handle false positives
- [../troubleshooting/false-positives-common-cases.md](../troubleshooting/false-positives-common-cases.md) — Specific false positive scenarios
- [../glossary.md](../glossary.md) — Verification state definitions
