---
title: "TruffleHog PR Diff Scan Workflow with JSON Output"
tags: [example, workflow, pull-request, json, step-summary, binary-install]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "examples"
---

# Example: TruffleHog PR Diff Scan with JSON Output and Step Summary

This workflow uses the binary install rather than the official action, enabling JSON output collection, a human-readable step summary, and full exit-code control. It scans only the commits introduced by the pull request.

## When to Use This Example

- When you need structured JSON output for downstream processing (SIEM ingestion, ticketing systems)
- When you want findings displayed in the GitHub Actions step summary
- When you need to separate the collection step from the failure step (e.g., to always post a summary)
- When you need full control over TruffleHog flags not exposed by the official action
- When integrating with `actions/upload-artifact` to archive findings

## The Workflow

```yaml
# .github/workflows/secret-scan-pr.yml
name: PR Secret Scan

on:
  pull_request:

permissions: {}

jobs:
  trufflehog:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - name: Checkout (full history)
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          persist-credentials: false

      - name: Install TruffleHog
        run: |
          curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh \
            | sh -s -- -b /usr/local/bin
          trufflehog --version

      - name: Scan PR diff
        run: |
          set -euo pipefail
          TMP_JSON="$RUNNER_TEMP/trufflehog-results.json"
          : > "$TMP_JSON"

          EXCLUDE_FILE="$RUNNER_TEMP/trufflehog-exclude.txt"
          printf '^\.git/\n^vendor/\n^node_modules/\n' > "$EXCLUDE_FILE"

          BASE="${{ github.event.pull_request.base.sha }}"
          HEAD="${{ github.event.pull_request.head.sha }}"

          trufflehog git "file://$GITHUB_WORKSPACE" \
            --since-commit "$BASE" \
            --branch "$HEAD" \
            --results=verified \
            --json --no-update --github-actions \
            --force-skip-binaries \
            --exclude-paths "$EXCLUDE_FILE" \
            >> "$TMP_JSON" || true

          cp "$TMP_JSON" trufflehog-results.json

      - name: Summarize findings
        if: always()
        run: |
          echo "### TruffleHog Secret Scan" >> "$GITHUB_STEP_SUMMARY"
          if [ -s trufflehog-results.json ]; then
            COUNT=$(jq -c . trufflehog-results.json | wc -l | tr -d ' ')
            if [ "$COUNT" -gt 0 ]; then
              echo "**Found $COUNT potential secret(s)**" >> "$GITHUB_STEP_SUMMARY"
              jq -r '
                (if .SourceMetadata?.Data?.Git?
                 then "\(.SourceMetadata.Data.Git.file):\(.SourceMetadata.Data.Git.line)"
                 elif .SourceMetadata?.Data?.Filesystem?
                 then "\(.SourceMetadata.Data.Filesystem.file):\(.SourceMetadata.Data.Filesystem.line // 0)"
                 else "unknown" end) as $loc |
                "- " + $loc + " — " + (.DetectorName // "unknown") + (if .Verified then " **VERIFIED**" else "" end)
              ' trufflehog-results.json | sort -u >> "$GITHUB_STEP_SUMMARY"
            else
              echo "No secrets found." >> "$GITHUB_STEP_SUMMARY"
            fi
          else
            echo "No secrets found." >> "$GITHUB_STEP_SUMMARY"
          fi

      - name: Upload results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: trufflehog-findings
          path: trufflehog-results.json
          if-no-files-found: ignore

      - name: Fail if secrets found
        run: |
          if [ -s trufflehog-results.json ]; then
            COUNT=$(jq -c . trufflehog-results.json | wc -l | tr -d ' ')
            if [ "$COUNT" -gt 0 ]; then
              echo "::error::TruffleHog found $COUNT potential secrets."
              exit 1
            fi
          fi
          echo "Clean scan."
```

## Step-by-Step Explanation

### Step: Checkout (full history)

```yaml
- name: Checkout (full history)
  uses: actions/checkout@v4
  with:
    fetch-depth: 0
    persist-credentials: false
```

- `fetch-depth: 0` fetches the complete git history, which is required so TruffleHog can access the PR base commit to establish the scan range.
- `persist-credentials: false` prevents the `GITHUB_TOKEN` from being written into `.git/config`, reducing the blast radius if any subsequent step is compromised.

### Step: Install TruffleHog

```yaml
- name: Install TruffleHog
  run: |
    curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh \
      | sh -s -- -b /usr/local/bin
    trufflehog --version
```

Downloads and installs the TruffleHog binary to `/usr/local/bin`. The install script detects the runner architecture and OS automatically. The `trufflehog --version` line verifies the install succeeded and logs the version to the Actions output for audit purposes.

To pin a specific version, append the version tag:

```bash
| sh -s -- -b /usr/local/bin v3.93.4
```

### Step: Scan PR diff

```yaml
- name: Scan PR diff
  run: |
    set -euo pipefail
    TMP_JSON="$RUNNER_TEMP/trufflehog-results.json"
    : > "$TMP_JSON"
    ...
```

Key elements:

- `set -euo pipefail` — fails fast on any unhandled error and catches failures in pipes.
- `TMP_JSON="$RUNNER_TEMP/trufflehog-results.json"` — uses `$RUNNER_TEMP` (a temporary directory isolated to this job) rather than the workspace, so the results file is not accidentally scanned or committed.
- `: > "$TMP_JSON"` — creates an empty file (truncates if it exists). This ensures later steps can safely test for file existence.
- `EXCLUDE_FILE` — creates a path exclusion file on the fly. The patterns `^\.git/`, `^vendor/`, and `^node_modules/` are regex patterns matched against relative file paths.

```yaml
BASE="${{ github.event.pull_request.base.sha }}"
HEAD="${{ github.event.pull_request.head.sha }}"

trufflehog git "file://$GITHUB_WORKSPACE" \
  --since-commit "$BASE" \
  --branch "$HEAD" \
  --results=verified \
  --json --no-update --github-actions \
  --force-skip-binaries \
  --exclude-paths "$EXCLUDE_FILE" \
  >> "$TMP_JSON" || true
```

- `--since-commit "$BASE"` and `--branch "$HEAD"` — constrain the scan to only the commits introduced by this pull request.
- `--results=verified` — reports only findings that TruffleHog has confirmed are active credentials. Expand to `--results=verified,unknown` for more coverage.
- `--json` — outputs one JSON object per finding (newline-delimited JSON), suitable for programmatic processing.
- `--no-update` — disables the automatic version update check, which would otherwise make an outbound network call.
- `--github-actions` — emits `::error file=X,line=Y::` annotations visible in the PR diff view.
- `--force-skip-binaries` — skips binary files (images, compiled artifacts, archives) that are unlikely to contain plaintext secrets and slow down the scan.
- `>> "$TMP_JSON" || true` — appends findings to the results file. The `|| true` prevents the step from failing when TruffleHog exits non-zero (e.g., exit code 183 when findings are detected). The failure check is deferred to a later dedicated step.

```yaml
cp "$TMP_JSON" trufflehog-results.json
```

Copies results to the workspace root so subsequent steps and the upload artifact step can reference it by a stable path.

### Step: Summarize findings

```yaml
- name: Summarize findings
  if: always()
  run: |
    echo "### TruffleHog Secret Scan" >> "$GITHUB_STEP_SUMMARY"
    ...
```

- `if: always()` — runs even when a previous step fails, ensuring the summary is always posted.
- `$GITHUB_STEP_SUMMARY` — a special file whose contents are rendered as markdown on the workflow run summary page in the GitHub Actions UI.
- `jq -c . trufflehog-results.json | wc -l` — counts the number of JSON objects (one per line) to determine the total finding count.
- The `jq -r` expression formats each finding as a bullet point showing file location, detector name, and whether the credential is verified.

### Step: Upload results

```yaml
- name: Upload results
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: trufflehog-findings
    path: trufflehog-results.json
    if-no-files-found: ignore
```

Archives the JSON results as a workflow artifact, available for download from the Actions UI for 90 days by default. `if-no-files-found: ignore` prevents the step from failing when the results file is empty.

### Step: Fail if secrets found

```yaml
- name: Fail if secrets found
  run: |
    if [ -s trufflehog-results.json ]; then
      COUNT=$(jq -c . trufflehog-results.json | wc -l | tr -d ' ')
      if [ "$COUNT" -gt 0 ]; then
        echo "::error::TruffleHog found $COUNT potential secrets."
        exit 1
      fi
    fi
    echo "Clean scan."
```

Separating the failure from the scan step ensures that:
1. The summary step always runs (because it uses `if: always()`)
2. The artifact is always uploaded
3. The job still fails if secrets were found, blocking the PR merge

`-s trufflehog-results.json` tests that the file exists and is non-empty before running `jq`, preventing errors on clean scans.

## JSON Output Schema Reference

Each finding in `trufflehog-results.json` is a JSON object on its own line (newline-delimited JSON / NDJSON):

```json
{
  "SourceMetadata": {
    "Data": {
      "Git": {
        "commit": "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
        "file": "config/database.yml",
        "email": "developer@example.com",
        "repository": "https://github.com/example/repo",
        "timestamp": "2026-01-15 10:30:00 +0000",
        "line": 42
      }
    }
  },
  "SourceID": 1,
  "SourceType": 16,
  "SourceName": "trufflehog - git",
  "DetectorType": 2,
  "DetectorName": "AWS",
  "DecoderName": "PLAIN",
  "Verified": true,
  "Raw": "AKIAIOSFODNN7EXAMPLE",
  "RawV2": "AKIAIOSFODNN7EXAMPLEwJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
  "Redacted": "",
  "ExtraData": {
    "account": "123456789012",
    "arn": "arn:aws:iam::123456789012:user/example"
  },
  "StructuredData": null
}
```

### Key Fields

| Field | Description |
|-------|-------------|
| `SourceMetadata.Data.Git.file` | Repository-relative path to the file containing the finding |
| `SourceMetadata.Data.Git.line` | Line number of the finding in the file |
| `SourceMetadata.Data.Git.commit` | Full SHA of the commit where the finding was introduced |
| `DetectorName` | Name of the detector that matched (e.g., `AWS`, `GitHub`, `Stripe`) |
| `Verified` | `true` if TruffleHog confirmed the credential is active via the provider's API |
| `Raw` | The matched value. Handle with care — this is the actual secret. |
| `ExtraData` | Provider-specific metadata (e.g., AWS account ID, GitHub username) |

Note: When the finding is from a filesystem scan rather than a git scan, `SourceMetadata.Data` will contain `Filesystem` instead of `Git`.

## See Also

- [../patterns/diff-only-scan.md](../patterns/diff-only-scan.md) — Diff-only scan pattern explanation
- [../patterns/binary-install-vs-official-action.md](../patterns/binary-install-vs-official-action.md) — When to use binary install vs the official action
- [trufflehog-git-scan-workflow.md](./trufflehog-git-scan-workflow.md) — Simpler official action version (push + PR)
- [reusable-called-workflow.md](./reusable-called-workflow.md) — Reusable engine that incorporates similar patterns
