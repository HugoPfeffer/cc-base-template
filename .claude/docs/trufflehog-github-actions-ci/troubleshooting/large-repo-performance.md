---
title: "Large Repository Performance"
tags: [troubleshooting, performance, large-repo, timeout, concurrency, skip-binaries]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "troubleshooting"
---

# Troubleshooting: Large Repository Performance

## Symptoms

- Full-history scan approaches or exceeds GitHub Actions' 6-hour job limit
- Scan takes more than 30 minutes for routine PR checks
- Scan times out with no results produced
- Memory usage causes the runner process to be killed (OOM)

---

## Understanding What Takes Time

TruffleHog scan time is proportional to several factors:

1. **`fetch-depth: 0` checkout** — downloading the full git history for very large repositories can take 1–10 minutes before the scan even begins
2. **Git object traversal** — every commit, every file in every commit version is scanned
3. **Binary file scanning** — PDFs, images, compiled objects are large but rarely contain text credentials; scanning them wastes time
4. **Archive decompression** — `.zip`, `.jar`, `.tar.gz` files are extracted recursively; large archives can cause OOM
5. **Verification HTTP calls** — one network round-trip per candidate credential; thousands of candidates = significant latency

---

## Fix 1: Skip Binary Files

The single most impactful optimization for repositories containing compiled assets, images, or media:

```bash
trufflehog git \
  --force-skip-binaries \
  --fail \
  file://.
```

Skips all files detected as binary. Secrets are in text files — compiled executables, images, audio, and video files rarely contain credentials in a usable format. This can reduce scan time by 50–90% in asset-heavy repositories.

In the official action:

```yaml
- uses: trufflesecurity/trufflehog@v3.93.4
  with:
    extra_args: --force-skip-binaries
```

---

## Fix 2: Limit Archive Size

Archives are extracted and scanned recursively. A single large `.zip` can trigger OOM or add minutes to scan time:

```bash
trufflehog git \
  --archive-max-size=5MB \
  --force-skip-binaries \
  --fail \
  file://.
```

Archives larger than the specified threshold are skipped entirely. Choose a threshold appropriate for your repository — most secrets are in text files, not in large archives.

---

## Fix 3: Limit History Depth for PR and Push Scans

For PR and push scans, scan only the new commits, not full history. Use `--since-commit` to set the diff base:

```yaml
- name: Scan PR diff only
  run: |
    trufflehog git \
      --since-commit "${{ github.event.pull_request.base.sha }}" \
      --branch "${{ github.event.pull_request.head.ref }}" \
      --force-skip-binaries \
      --fail \
      file://"$GITHUB_WORKSPACE"
```

For push scans:

```bash
trufflehog git \
  --since-commit "${{ github.event.before }}" \
  --force-skip-binaries \
  --fail \
  file://"$GITHUB_WORKSPACE"
```

This avoids re-scanning the entire repository history on every push.

---

## Fix 4: Run Full-History Scans as Separate Scheduled Jobs

Do not run full-history scans on every PR — reserve them for scheduled jobs:

```yaml
# .github/workflows/secret-scan-full.yml — runs weekly, not on every PR
name: Weekly Full History Scan
on:
  schedule:
    - cron: '0 2 * * 0'  # 2 AM UTC every Sunday

jobs:
  full-scan:
    runs-on: ubuntu-latest
    timeout-minutes: 360   # 6-hour limit, explicitly set
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
        with:
          fetch-depth: 0
      - uses: trufflesecurity/trufflehog@v3.93.4
        with:
          extra_args: >-
            --force-skip-binaries
            --archive-max-size=5MB
            --results=verified,unknown
```

This pattern separates fast per-PR diff scans from slow periodic full-history scans.

---

## Fix 5: Increase Concurrency

TruffleHog uses goroutines for parallel detection. Increasing concurrency uses more CPU cores and can reduce total scan time on multi-core runners:

```bash
trufflehog git \
  --concurrency 8 \
  --force-skip-binaries \
  --fail \
  file://.
```

Recommended values by runner type:

| Runner Type | Recommended `--concurrency` |
|-------------|---------------------------|
| GitHub-hosted `ubuntu-latest` (2 vCPU) | 4–8 (default) |
| GitHub-hosted `ubuntu-latest-4-cores` (4 vCPU) | 8–16 |
| GitHub-hosted large runner (8 vCPU) | 16–32 |
| Self-hosted (16+ vCPU) | 32–64 |

Note: Setting concurrency too high can cause memory pressure from many simultaneous verification HTTP connections. Start with the default and increase incrementally.

---

## Fix 6: Limit to Relevant Detectors

If your organization uses only specific cloud services, skip the other 690+ detectors entirely:

```bash
trufflehog git \
  --include-detectors "AWS,GitHub,Stripe,GoogleCloud" \
  --fail \
  file://.
```

This reduces the Aho-Corasick pattern matching workload to only the detectors that matter for your environment.

---

## Full Optimized Command

For a large repository full-history scan:

```bash
trufflehog git \
  --results=verified \
  --json --no-update --github-actions \
  --force-skip-binaries \
  --archive-max-size=5MB \
  --concurrency=16 \
  --exclude-paths=.trufflehog/exclude-paths.txt \
  file://"$GITHUB_WORKSPACE"
```

For PR/push scans on a large repository (fast path):

```bash
trufflehog git \
  --since-commit "$BASE_SHA" \
  --force-skip-binaries \
  --archive-max-size=5MB \
  --fail \
  file://"$GITHUB_WORKSPACE"
```

---

## See Also

- [../patterns/full-history-scan.md](../patterns/full-history-scan.md) — Full history scan pattern and timing considerations
- [../patterns/diff-only-scan.md](../patterns/diff-only-scan.md) — Keeping PR scans fast
- [../concepts/trufflehog-architecture.md](../concepts/trufflehog-architecture.md) — All CLI flags including `--concurrency`, `--force-skip-binaries`, `--archive-max-size`
