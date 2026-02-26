---
title: "TruffleHog Detection Engine"
tags: [trufflehog, detection-engine, aho-corasick, regex, verification, detectors]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "concepts"
---

# TruffleHog Detection Engine

## Overview

The TruffleHog detection engine transforms raw bytes from any source into verified or unverified credential findings. It is designed around one performance constraint: 700+ detectors cannot all run regex matching on every byte — that would be computationally prohibitive. The engine solves this with a two-phase approach: a fast keyword pre-filter that gates access to the expensive regex stage.

---

## Phase 1: Aho-Corasick Pre-filter

Each detector declares a `Keywords()` method returning a list of short, distinctive strings. For example:

- AWS detector keywords: `["AKIA", "ABIA", "ACCA"]`
- Stripe detector keywords: `["sk_live_", "pk_live_", "sk_test_", "pk_test_"]`
- GitHub PAT detector keywords: `["ghp_", "gho_", "ghu_", "ghs_", "ghr_"]`

At startup, TruffleHog loads all keyword lists into a single **Aho-Corasick automaton** — a finite state machine that can simultaneously search for all patterns in a single linear pass over the input text. The time complexity is O(n + m + z) where n is text length, m is total keyword length, and z is the number of matches.

When a chunk of data arrives:

1. The Aho-Corasick automaton scans it in one pass
2. It returns the set of detectors whose keywords appeared
3. Only those detectors proceed to Phase 2
4. All other detectors are skipped entirely

For typical source code, most chunks will match only a small fraction of detectors, making the engine roughly proportional to actual findings rather than to detector count.

---

## Phase 2: Detector Regex Matching

Each detector that passes the keyword filter runs its `FromData()` method on the chunk. This method:

1. Applies one or more **named-capture-group regex patterns** to the raw bytes
2. Extracts candidate credential strings from the named groups
3. Optionally applies **entropy filtering** — discards matches below a Shannon entropy threshold (typical range: 3.0–4.0 bits per character)
4. Returns a list of `Result` objects, one per candidate

The regex patterns are deliberately specific to avoid false positives. An AWS access key regex, for example, matches exactly the 20-character uppercase alphanumeric pattern that AWS issues, not just any long string.

---

## Phase 3: Verification HTTP Call

For each `Result`, TruffleHog makes a live HTTP request to the issuing service's API. The exact request depends on the detector:

- **AWS**: `sts:GetCallerIdentity` — a lightweight, read-only API call
- **GitHub**: `GET /user` with the token as a Bearer
- **Stripe**: `GET /v1/balance` with the key in the Authorization header
- Custom webhook detectors: POST to a user-specified URL

The response determines the result state:

| HTTP Response | State |
|---------------|-------|
| 200 OK (authenticated) | `verified` |
| 401 / 403 (unauthenticated) | `unverified` |
| Network error / timeout / 5xx | `unknown` |
| Built-in word list match | `filtered_unverified` |

Verification requires network access from the runner. In air-gapped environments or when network calls to external APIs are blocked, use `--no-verification` to skip Phase 3 entirely.

---

## Phase 4: Deduplication

After verification, TruffleHog checks whether the raw credential value has already been reported in this scan run. Deduplication is keyed on a **SHA256 hash of the raw value**, not on location — the same AWS key found in 10 different commits is reported once.

This is important to understand: TruffleHog will not tell you *every* place a leaked credential appears, only that it appeared. Use `--json` output with location metadata to find all occurrences if needed for remediation.

---

## Detector Interface

Every built-in and custom detector implements this Go interface:

```go
type Detector interface {
    // Keywords returns short strings that must be present for this detector to run
    Keywords() []string

    // FromData extracts and optionally verifies credentials from raw bytes
    FromData(ctx context.Context, verify bool, data []byte) ([]Result, error)

    // Type returns the protobuf enum identifying this detector
    Type() detectorspb.DetectorType
}
```

TruffleHog ships 700+ detectors implementing this interface, covering every major cloud provider, SaaS platform, version control system, payment processor, and communication tool.

---

## Result States

| State | Meaning | Priority |
|-------|---------|----------|
| `verified` | Credential is currently active (confirmed by live API) | Critical — revoke immediately |
| `unverified` | Matched regex; verification call failed or was inconclusive | High — investigate manually |
| `unknown` | Verification could not be attempted (network issue, no API) | Medium — review context |
| `filtered_unverified` | Matched regex but suppressed by built-in word list | Low — likely false positive |

### Controlling Which States Appear in Output

```bash
# Default: verified + unverified
trufflehog git .

# Only confirmed active credentials
trufflehog git . --only-verified

# All states including likely false positives
trufflehog git . --results=verified,unverified,unknown,filtered_unverified

# Custom combination
trufflehog git . --results=verified,unknown
```

---

## Built-in Word List Filtering

The `filtered_unverified` state is applied when a regex match is present but the matched value appears in TruffleHog's built-in word lists. These lists contain:

- Common placeholder values (`example`, `test`, `dummy`, `changeme`)
- Documentation examples (`AKIAIOSFODNN7EXAMPLE`, `sk_test_...`)
- Known false-positive patterns from popular frameworks

This filtering reduces noise in the default output. If you are auditing a codebase and want to see everything, add `filtered_unverified` to `--results`.

---

## Custom Detectors

Users can extend the engine with custom regex detectors via `config.yaml` using the `CustomRegexWebhook` detector type. See [guides/configuring-detectors.md](../guides/configuring-detectors.md) and [examples/custom-detector-config.md](../examples/custom-detector-config.md) for the complete configuration reference.

Custom detectors participate in all four phases: their keywords are added to the Aho-Corasick automaton, their regex runs in Phase 2, and if a `CustomRegexWebhook` URL is configured it is called in Phase 3 to verify the match.

A minimal custom detector entry in `config.yaml`:

```yaml
detectors:
  - name: MyInternalToken
    keywords:
      - "myorg_tok_"
    regex:
      token: "myorg_tok_[a-zA-Z0-9]{32}"
    verify:
      - endpoint: https://api.internal.example.com/auth/verify
        unsafe: false
        headers:
          - "Authorization: Bearer {{.TOKEN}}"
```

---

## See Also

- [trufflehog-architecture.md](./trufflehog-architecture.md) — Full pipeline and CLI flags
- [secret-scanning-fundamentals.md](./secret-scanning-fundamentals.md) — Secret types and false positives
- [../guides/configuring-detectors.md](../guides/configuring-detectors.md) — How to configure detectors
- [../troubleshooting/verification-rate-limits.md](../troubleshooting/verification-rate-limits.md) — Rate limit issues during Phase 3
- [../glossary.md](../glossary.md) — Aho-Corasick, detector, verification state definitions
