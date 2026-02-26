---
title: "Suppressing False Positives"
tags: [guide, false-positives, suppression, allowlist, exclude-paths, trufflehog-ignore, results-verified, force-skip-binaries]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "guides"
---

# Guide: Suppressing False Positives

TruffleHog minimises false positives through live verification — if a credential fails verification, it is reported as `unverified` or `filtered_unverified` rather than `verified`. However, some false positives still reach the output. This guide covers all available suppression methods, ordered from most surgical to broadest impact.

TruffleHog also maintains built-in false positive word lists that automatically exclude known placeholder values (example, sample, test, xxxxxx, 000000) without any configuration.

---

## Method 1: `trufflehog:ignore` Inline Comment

The most precise suppression: add `trufflehog:ignore` as a comment on the **exact line** containing the false positive.

```python
# Python
aws_key = "AKIAIOSFODNN7EXAMPLE"  # trufflehog:ignore

# Go
secretKey := "AKIAIOSFODNN7EXAMPLE" // trufflehog:ignore

# YAML
api_key: "AKIAIOSFODNN7EXAMPLE" # trufflehog:ignore

# JavaScript
const apiKey = "AKIAIOSFODNN7EXAMPLE"; // trufflehog:ignore

# Bash
export API_KEY="AKIAIOSFODNN7EXAMPLE" # trufflehog:ignore
```

The comment must be on the **same line** as the matched value. TruffleHog checks for this string during result processing and suppresses the finding regardless of detector type.

When to use: a specific line in a test file, documentation, or example that contains a safe fake credential.

---

## Method 2: `--exclude-paths` File

Exclude entire directories or file patterns from scanning. Pass a file containing one regex per line to `--exclude-paths`:

```
# .trufflehog/exclude-paths.txt
^test/fixtures/
^vendor/
^node_modules/
.*\.lock$
```

A more complete example for common project layouts:

```
# .trufflehog/exclude-paths.txt
^tests?/fixtures/
^spec/fixtures/
^testdata/
^vendor/
^node_modules/
^docs/
\.md$
_test\.go$
\.lock$
```

Use in workflow:

```yaml
- uses: trufflesecurity/trufflehog@v3.93.4
  with:
    extra_args: --exclude-paths .trufflehog/exclude-paths.txt
```

Or with the binary:

```bash
trufflehog git \
  --exclude-paths .trufflehog/exclude-paths.txt \
  --fail \
  file://.
```

When to use: entire directories that are known to contain safe test data, vendor code, or documentation with example credentials.

**Caution**: excluding broad paths like `^docs/` means real secrets accidentally committed there will not be detected.

---

## Method 3: `--results=verified` (Only Verified Results)

The most impactful single flag: only report credentials that have been confirmed active by the provider's API.

```bash
# CLI
trufflehog git file:///repo --results=verified --fail

# Official action
- uses: trufflesecurity/trufflehog@v3.93.4
  with:
    extra_args: --results=verified
```

This eliminates all `unverified` and `unknown` findings. It is the highest-signal configuration but will miss:
- Credentials for services without verification support
- Credentials that have already been revoked
- Air-gapped or internal service credentials

When to use: when you accept the trade-off of potentially missing unverifiable credentials in exchange for zero noise. Good for repositories in active development where CI noise is costly.

---

## Method 4: `--exclude-detectors`

Skip specific noisy detectors that cannot be addressed through other means:

```bash
trufflehog git file:///repo \
  --exclude-detectors="GenericPassword,JWT" \
  --fail
```

When to use: last resort. Document the reason for the exclusion in the workflow file or a comment. Review the exclusion list periodically to see if improvements in the detector have made it usable again.

---

## Method 5: Custom Detector Exclusions (config.yaml)

For custom detectors, use in-config exclusion fields:

```yaml
# .trufflehog/config.yaml
detectors:
  - name: MyAPIKey
    keywords: ["myapi_"]
    regex:
      key: "myapi_[a-zA-Z0-9]{32}"
    entropy: 3.5                   # Filters low-entropy placeholders
    exclude_words:                 # Specific known-safe values
      - "myapi_00000000000000000000000000000000"
      - "myapi_examplekeyfordemopurposesonly01"
    exclude_regexes_capture:       # Pattern-based suppression on captured value
      - "^myapi_test_"
      - "^myapi_example_"
    exclude_regexes_match:         # Suppresses if the surrounding line matches
      - "placeholder"
```

Available exclusion options:
- `entropy` — Filters low-entropy (likely placeholder) values
- `exclude_words` — Exact string values to skip
- `exclude_regexes_capture` — Suppress if the captured value matches the pattern
- `exclude_regexes_match` — Suppress if the full matched line contains the pattern

---

## Method 6: `--force-skip-binaries`

Prevents TruffleHog from attempting to scan binary files that cannot contain text secrets:

```bash
trufflehog git file:///repo \
  --force-skip-binaries \
  --fail
```

Binary files (images, compiled artifacts, archive files) sometimes produce false pattern matches because their binary content happens to match a credential regex. This flag skips them entirely.

When to use: repositories containing many binary assets where binary file false positives are occurring.

---

## Method 7: Built-in False Positive Word Lists

TruffleHog automatically excludes a built-in list of known placeholder values without any configuration. These include values like:
- example, sample, test, demo
- xxxxxx, 000000, aaaaaa
- placeholder, changeme, yoursecretkey

You do not need to add these to your own exclusions. If you are seeing findings suppressed as `filtered_unverified`, this is the built-in word list working correctly.

---

## Deciding Which Method to Use

| Scenario | Recommended Method |
|----------|--------------------|
| Single line in a test file or docs | `trufflehog:ignore` inline comment |
| Entire test fixtures or vendor directory | `--exclude-paths` file |
| Accept risk of missing unverifiable secrets | `--results=verified` |
| One built-in detector generates all false positives | `--exclude-detectors` |
| Custom detector matching low-entropy placeholders | `entropy` threshold in config |
| Custom detector with specific known-safe values | `exclude_words` in config |
| Custom detector with patterned safe values | `exclude_regexes_capture` in config |
| False positives from binary files | `--force-skip-binaries` |

---

## Auditing Suppressed Findings

To see what is being suppressed (useful for periodic review):

```bash
# Show all findings including filtered_unverified
trufflehog git \
  --results=verified,unverified,unknown,filtered_unverified \
  --json \
  file://. \
  2>/dev/null | jq '.DetectorName + ": " + .Raw[:20]'
```

Review `filtered_unverified` findings periodically to ensure the built-in word list is still appropriate for your codebase.

---

## See Also

- [../troubleshooting/false-positives-common-cases.md](../troubleshooting/false-positives-common-cases.md) — Specific false positive scenarios with solutions
- [../examples/config-yaml-with-allowlist.md](../examples/config-yaml-with-allowlist.md) — Complete config.yaml with exclusions
- [../concepts/secret-scanning-fundamentals.md](../concepts/secret-scanning-fundamentals.md) — Why false positives occur
- [../glossary.md](../glossary.md) — filtered_unverified, trufflehog:ignore, and other term definitions
