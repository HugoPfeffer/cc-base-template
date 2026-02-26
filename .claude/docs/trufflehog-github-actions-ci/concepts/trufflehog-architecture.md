---
title: "TruffleHog v3 Architecture"
tags: [trufflehog, architecture, go, agpl, cli, pipeline]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "concepts"
---

# TruffleHog v3 Architecture

## Overview

TruffleHog v3 is a complete Go rewrite of the original Python tool. It is open-source (AGPL-3.0), has **24.7k+ GitHub stars**, and as of February 2026 the latest release is **v3.93.4**.

The central design decision that distinguishes v3 from other secret scanners is **live credential verification**: TruffleHog does not just report pattern matches but makes real HTTP calls to each credential's issuing service to confirm whether the key is currently valid. This moves secret scanning from "find anything that looks like a key" to "find secrets that are actively dangerous."

---

## Engine Pipeline

TruffleHog processes data through a linear pipeline of stages:

```
Source
  │
  ▼
Chunks (byte slices + metadata)
  │
  ▼
Aho-Corasick Pre-filter  ← fast keyword matching
  │  (drops chunks with no detector keyword)
  ▼
Detector Regex Matching  ← named-group regex per detector
  │  (extracts candidate credential strings)
  ▼
Verification HTTP Call   ← live API call to issuing service
  │  (sets Verified / Unverified / Unknown state)
  ▼
Deduplication            ← same raw value seen before? suppress
  │
  ▼
Output (stdout, NDJSON, GitHub Actions annotations)
```

Each stage narrows the result set. The Aho-Corasick filter is the primary performance gate: scanning 700+ detectors against every byte is infeasible; scanning for a short keyword list first makes it practical.

See [detection-engine.md](./detection-engine.md) for a deep dive into each stage.

---

## Scan Subcommands

TruffleHog uses a subcommand-per-source model. All subcommands share the same detection pipeline but use different source adapters to produce chunks.

| Subcommand | Source |
|------------|--------|
| `git` | Local or remote git repositories |
| `filesystem` | Local file paths |
| `github` | GitHub repositories and organisations via API |
| `gitlab` | GitLab repositories |
| `s3` | Amazon S3 buckets |
| `gcs` | Google Cloud Storage buckets |
| `docker` | Docker image layers |
| `jenkins` | Jenkins build artefacts |
| `postman` | Postman collections and workspaces |
| `stdin` | Arbitrary piped input |

In CI, `git` is the primary subcommand. The official GitHub Action calls `trufflehog git` internally.

---

## Exit Codes

Understanding exit codes is critical for correct CI integration:

| Code | Meaning |
|------|---------|
| `0` | Scan completed, no findings |
| `183` | Scan completed, findings detected (only when `--fail` is active) |
| Any other non-zero | Scan error (authentication failure, I/O error, etc.) |

Without `--fail`, TruffleHog always exits `0`, even if secrets are found. The official GitHub Action **always injects `--fail`**.

If you need to distinguish findings from errors in shell:

```bash
trufflehog git --fail . ; EXIT=$?
if [ $EXIT -eq 183 ]; then
  echo "Findings detected"
elif [ $EXIT -ne 0 ]; then
  echo "Scan error: $EXIT"
fi
```

---

## CLI Flags Reference

### Output and Filtering

| Flag | Effect |
|------|--------|
| `--fail` | Exit 183 when findings exist |
| `--fail-on-scan-errors` | Exit non-zero on scan errors (default: continue) |
| `--json` | Output NDJSON (one JSON object per line) |
| `--github-actions` | Emit `::warning file=X,line=Y::` annotations |
| `--results=<list>` | Filter output by state: `verified`, `unverified`, `unknown`, `filtered_unverified` |
| `--only-verified` | Shorthand for `--results=verified` |
| `--no-verification` | Skip live API verification entirely |
| `--no-update` | Skip the auto-update check |

### Scope and Range

| Flag | Effect |
|------|--------|
| `--since-commit <SHA>` | Only scan commits after this SHA |
| `--branch <name>` | Limit scan to this branch |
| `--max-depth <n>` | Limit number of commits to traverse |
| `--exclude-paths <file>` | File containing regex patterns for paths to skip |
| `--include-detectors <list>` | Only run these detectors |
| `--exclude-detectors <list>` | Skip these detectors |
| `--force-skip-binaries` | Skip binary files (performance) |
| `--archive-max-size <size>` | Skip archives larger than this (e.g., `5MB`) |
| `--trust-local-git-config` | Allow reading local `.gitconfig` |

### Configuration and Runtime

| Flag | Effect |
|------|--------|
| `--config <path>` | Path to `config.yaml` for custom detectors |
| `--concurrency <n>` | Number of parallel detection goroutines |
| `--debug` | Verbose debug output |
| `--version` | Print version and exit |

---

## NDJSON Output Schema

When `--json` is active, each finding produces one line of JSON:

```json
{
  "SourceMetadata": {
    "Data": {
      "Git": {
        "commit": "a1b2c3d4e5f6...",
        "file": "config/database.yml",
        "line": 42,
        "email": "dev@example.com",
        "repository": "https://github.com/org/repo"
      }
    }
  },
  "DetectorType": 2,
  "DetectorName": "AWS",
  "Verified": true,
  "Raw": "AKIAIOSFODNN7EXAMPLE",
  "ExtraData": {
    "account": "123456789012",
    "arn": "arn:aws:iam::123456789012:user/ci-user"
  }
}
```

Key fields:

- `Verified: true` — live API confirmed this credential is active
- `Raw` — the matched credential string (handle with care in logs)
- `SourceMetadata.Data.Git` — location in the repository
- `DetectorName` — which built-in or custom detector matched

---

## License and Distribution

- **License**: AGPL-3.0. Running TruffleHog as a CI tool (as an external process) does not require you to open-source your own code. AGPL requirements apply only if you distribute a modified version of TruffleHog itself.
- **Container image**: `ghcr.io/trufflesecurity/trufflehog:<version>` (GitHub Container Registry)
- **Install script**: `https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh`

---

## See Also

- [detection-engine.md](./detection-engine.md) — How each pipeline stage works in detail
- [secret-scanning-fundamentals.md](./secret-scanning-fundamentals.md) — Result states and secret types
- [../guides/local-trufflehog-installation.md](../guides/local-trufflehog-installation.md) — Installation methods
- [../patterns/binary-install-vs-official-action.md](../patterns/binary-install-vs-official-action.md) — When to use the binary vs the action
