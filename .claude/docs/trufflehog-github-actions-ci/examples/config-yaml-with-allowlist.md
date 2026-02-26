---
title: "config.yaml with Allowlist and Path Exclusions"
tags: [example, config-yaml, allowlist, exclusions, false-positives, custom-detector]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "examples"
---

# Example: config.yaml with Allowlist and Path Exclusions

TruffleHog's `config.yaml` file controls custom detector definitions, exclusion rules, and detector selection. This example shows a complete configuration for a repository with known false positive sources and organisation-specific credential formats.

## When to Use This Example

- When the repository contains test fixtures with fake credentials
- When specific directories should be excluded from scanning (vendor/, docs/)
- When you need organisation-specific credential patterns alongside built-in detectors
- When entropy filtering is needed to reduce noise from low-quality regex matches

## The config.yaml

```yaml
# .trufflehog/config.yaml

detectors:
  - name: InternalAPIKey
    keywords:
      - internal_token
      - company_key
    regex:
      token: 'int_[A-Za-z0-9]{40}'
    entropy: 3.5
    exclude_words:
      - example
      - placeholder
      - XXXXXXXX
    exclude_regexes_match:
      - 'int_[Aa0]{40}'
```

## The exclude-paths.txt

Path exclusions are passed as a separate file via `--exclude-paths`. Each line is a regular expression matched against the relative file path:

```
# .trufflehog/exclude-paths.txt
# Lines starting with # are comments. One regex per line.

^\.git/
^vendor/
^node_modules/
^test/fixtures/
.*\.lock$
.*_test\.go$
```

## How to Use Both Files

```bash
trufflehog filesystem . \
  --config=.trufflehog/config.yaml \
  --exclude-paths=.trufflehog/exclude-paths.txt
```

Or in a GitHub Actions workflow:

```yaml
- name: TruffleHog Scan
  uses: trufflesecurity/trufflehog@main
  with:
    extra_args: >-
      --config .trufflehog/config.yaml
      --exclude-paths .trufflehog/exclude-paths.txt
      --results=verified
```

Or with the binary install:

```yaml
- name: Scan
  run: |
    trufflehog git "file://$GITHUB_WORKSPACE" \
      --config .trufflehog/config.yaml \
      --exclude-paths .trufflehog/exclude-paths.txt \
      --results=verified \
      --json --no-update --github-actions
```

## config.yaml Schema Reference

### Top-Level Keys

| Key | Type | Description |
|-----|------|-------------|
| `detectors` | list | Custom regex detector definitions (see Detector Object Keys below) |
| `include_detectors` | string | Comma-separated list of built-in detectors to enable (all others disabled) |
| `exclude_detectors` | string | Comma-separated list of built-in detectors to disable |

`include_detectors` and `exclude_detectors` affect only the 700+ built-in detectors, not custom detectors defined in `detectors`. Custom detectors always run when defined.

### Detector Object Keys

| Key | Required | Type | Description |
|-----|----------|------|-------------|
| `name` | Yes | string | Display name shown in output and used in the verification POST body |
| `keywords` | Yes | list of strings | Aho-Corasick pre-filter keywords. Files and chunks without any keyword are skipped before the regex runs. Choose short, distinctive strings. |
| `regex` | Yes | map (string to string) | Named capture group patterns. Each key is the group name; the value is the regex. |
| `entropy` | No | float | Minimum Shannon entropy for the matched value (typical range: 3.0–4.0). Filters low-entropy placeholders. |
| `exclude_words` | No | list of strings | Exact strings that, if present in the matched value, suppress the finding. |
| `exclude_regexes_match` | No | list of strings | Regexes applied to the full match context. If any regex matches, the finding is suppressed. |
| `exclude_regexes_capture` | No | list of strings | Regexes applied to the captured (extracted) value. If any regex matches, the finding is suppressed. |
| `verify` | No | bool | Whether to POST to a verification endpoint. |
| `verificationUrl` | No | string | URL for POST-based verification. |

### exclude_words vs exclude_regexes_match vs exclude_regexes_capture

These three suppression mechanisms operate at different scopes:

- `exclude_words` — simple substring match against the captured value. Fastest. Use for known placeholder strings (e.g., `XXXXXXXX`, `example`, `placeholder`).
- `exclude_regexes_capture` — regex applied to just the extracted value (the named group). Use for structural patterns that are always safe (e.g., `^int_000` for a known test prefix).
- `exclude_regexes_match` — regex applied to the broader match context (the surrounding text). Use when the context determines whether a match is safe (e.g., suppress if the line also contains `# noqa`).

## Extended config.yaml with Multiple Detectors

```yaml
# .trufflehog/config.yaml

# Run only a subset of built-in detectors alongside custom ones.
# Omit this line to run all 700+ built-in detectors.
# include_detectors: "AWS,GitHub,Stripe"

# Disable a specific built-in detector that causes persistent false positives.
# exclude_detectors: "SomeDetector"

detectors:
  # Internal API key with entropy filter and word exclusions
  - name: InternalAPIKey
    keywords:
      - internal_token
      - company_key
    regex:
      token: 'int_[A-Za-z0-9]{40}'
    entropy: 3.5
    exclude_words:
      - example
      - placeholder
      - XXXXXXXX
    exclude_regexes_match:
      - 'int_[Aa0]{40}'

  # Service token with verification webhook
  - name: InternalServiceToken
    keywords:
      - svc_tok_
    regex:
      token: 'svc_tok_[A-Za-z0-9]{40}'
    entropy: 3.8
    verify: true
    verificationUrl: 'https://auth.internal.example.com/verify-token'

  # OAuth token — no verification, unknown state only
  - name: InternalOAuthToken
    keywords:
      - corp_oauth_
    regex:
      token: 'corp_oauth_[a-zA-Z0-9_-]{64}'
    entropy: 3.8
    exclude_regexes_capture:
      - '^corp_oauth_test_'   # Suppress test-environment tokens
```

## Extended exclude-paths.txt

```
# .trufflehog/exclude-paths.txt

# Version control metadata
^\.git/

# Third-party dependencies
^vendor/
^node_modules/
^\.yarn/

# Test fixtures — these contain intentional fake credentials
^test/fixtures/
^spec/fixtures/
^testdata/

# Generated files unlikely to contain real secrets
.*\.lock$
.*_generated\.go$
.*\.min\.js$
.*\.pb\.go$

# Documentation with example credentials
^docs/examples/
^README

# Historical migration scripts with already-rotated keys
^scripts/migrations/2023-01-legacy-key-rotation/
```

## See Also

- [../guides/configuring-detectors.md](../guides/configuring-detectors.md) — Complete guide to detector configuration
- [../guides/suppressing-false-positives.md](../guides/suppressing-false-positives.md) — All false-positive suppression methods
- [custom-detector-config.md](./custom-detector-config.md) — Detailed custom detector with verification webhook
