---
title: "Verification Rate Limits"
tags: [troubleshooting, rate-limits, verification, github-api, unknown-results]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "troubleshooting"
---

# Troubleshooting: Verification Rate Limits

## Symptoms

- Many findings reported as `unknown` instead of `verified` or `unverified`
- Scan takes longer than expected and then produces mostly `unknown` results
- Verification calls failing silently or with HTTP 429 responses in debug output
- Results that previously showed `unverified` now show `unknown` in the same repository

---

## Root Cause

TruffleHog makes live HTTP calls to credential-issuing APIs (GitHub, AWS, Stripe, etc.) to verify each candidate credential. These APIs enforce rate limits. When rate limits are hit:

- The verification call returns HTTP 429 or fails with a network error
- TruffleHog marks the result as `unknown` (not `unverified` or `verified`)
- The scan continues — rate limiting does not cause missed results, only status degradation

**Critical clarification**: `unknown` does NOT mean the secret was missed. The secret was detected by pattern matching. Only the verification status could not be determined. Every matching pattern is still reported regardless of rate limit status.

---

## Understanding Result States

| Result Type | Meaning | Action Required |
|-------------|---------|-----------------|
| `verified` | Credential confirmed live against provider API | URGENT: Revoke immediately |
| `unverified` | Pattern matched; provider API says credential is not active | Review; likely safe, but investigate origin |
| `unknown` | Pattern matched; verification could not complete (rate limit, network error, API change) | Investigate manually |

Rate limiting converts results that would be `unverified` into `unknown` — it never causes a finding to be silently dropped.

---

## GitHub API Rate Limiting

The most common scenario. TruffleHog verifies detected GitHub tokens by calling the GitHub API.

### Default Limits

- **Unauthenticated**: 60 requests per hour per IP address
- **Authenticated (`GITHUB_TOKEN`)**: 5,000 requests per hour per token
- **Fine-grained PAT**: varies by token scope

Large repositories with many potential GitHub tokens in history can exhaust the unauthenticated limit quickly.

### Fix: Pass a GitHub Token

```yaml
- uses: trufflesecurity/trufflehog@v3.93.4
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  with:
    extra_args: --results=verified,unknown
```

With the binary:

```bash
trufflehog git \
  --token "$GITHUB_TOKEN" \
  --fail \
  file://.
```

Providing `GITHUB_TOKEN` raises the verification limit from 60 to 5,000 requests per hour.

### Check Your Current Rate Limit

```bash
curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://api.github.com/rate_limit | jq '.rate'
```

Output:

```json
{
  "limit": 5000,
  "remaining": 4721,
  "reset": 1708972800
}
```

The `reset` field is a Unix timestamp. Convert with `date -d @1708972800` to see when the limit resets.

---

## Non-GitHub Provider Rate Limits

Other services (Stripe, AWS STS, Slack, Twilio) also rate-limit their verification APIs. This is less common in practice because:

1. Most CI scans find far fewer valid credential candidates than GitHub tokens
2. TruffleHog's Aho-Corasick pre-filter limits the total number of verification attempts to actual pattern matches

For AWS specifically, the `sts:GetCallerIdentity` API call used for verification has very generous rate limits and rarely causes issues.

If you see `unknown` results for a specific non-GitHub detector, check that service's API rate limit documentation.

---

## Mitigation Strategies

### 1. Pass Authentication Tokens

Provide tokens for services you expect TruffleHog to verify against:

```yaml
env:
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### 2. Use `--results=verified` to Only Fail on Confirmed Secrets

If rate limits are causing noise from `unknown` results, configure the workflow to only fail on confirmed-live credentials:

```yaml
- uses: trufflesecurity/trufflehog@v3.93.4
  with:
    extra_args: --results=verified
```

This prevents false-positive CI failures from rate-limited verification while still detecting confirmed-live credentials.

### 3. Use `--no-verification` for Pure Detection

For initial audits or high-throughput scanning where verification latency is unacceptable:

```bash
trufflehog git \
  --no-verification \
  --results=verified,unverified,unknown \
  --fail \
  file://.
```

`--no-verification` skips all API calls. Results will show as `unverified` for all matches. Faster, but less actionable — requires manual investigation of all findings.

### 4. Limit Detectors to Reduce Verification Calls

```bash
trufflehog git \
  --include-detectors "AWS,GitHub,Stripe,GoogleCloud" \
  --fail \
  file://.
```

Only running detectors for services your organization uses reduces total verification API calls.

### 5. Stagger Scheduled Full-History Scans

Run large full-history scans at off-peak times to avoid competing with other API traffic:

```yaml
on:
  schedule:
    - cron: '0 2 * * 0'  # 2 AM UTC every Sunday
```

### 6. Reduce Concurrency to Stay Within Stricter Limits

```bash
trufflehog git \
  --concurrency 1 \
  --fail \
  file://.
```

Reducing concurrency to 1 sends one verification call at a time. Effective for providers with very low rate limits, but significantly increases scan time.

---

## See Also

- [../concepts/detection-engine.md](../concepts/detection-engine.md) — Verification phase explanation and result states
- [../concepts/secret-scanning-fundamentals.md](../concepts/secret-scanning-fundamentals.md) — Understanding `unknown` vs `unverified`
- [../guides/suppressing-false-positives.md](../guides/suppressing-false-positives.md) — How to handle `unknown` results that are not actionable
