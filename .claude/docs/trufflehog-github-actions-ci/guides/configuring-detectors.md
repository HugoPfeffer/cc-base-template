---
title: "Configuring TruffleHog Detectors"
tags: [guide, detectors, config-yaml, custom-detector, built-in, include, exclude, entropy, verification]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "guides"
---

# Guide: Configuring TruffleHog Detectors

TruffleHog ships with 700+ built-in detectors. This guide covers how to control which detectors run, how to specify detector versions, how to add custom detectors, and how to tune detector behaviour using both CLI flags and config files.

## Configuration Methods

TruffleHog detectors are configured via two mechanisms:

1. **CLI flags** — `--include-detectors`, `--exclude-detectors`, `--no-verification`, `--verify-detectors`
2. **config.yaml** — Custom detector definitions and exclusions, passed with `--config`

These two mechanisms can be combined in a single command.

---

## Controlling Built-in Detectors via CLI Flags

### Run All Detectors (Default)

```bash
trufflehog git file:///repo --fail
```

All 700+ built-in detectors run. This is the correct default for most situations.

### Run Only Specific Detectors

```bash
# Only AWS and GitHub detectors
trufflehog git file:///repo --include-detectors="AWS,GitHub"
```

Use this when you know exactly which services your codebase can access and want to reduce scan time. The detector names match those shown in the `DetectorName` field of JSON output.

### Skip Specific Detectors

```bash
# Run all detectors except Slack and JWT
trufflehog git file:///repo --exclude-detectors="Slack,JWT"
```

Use `--exclude-detectors` when specific detectors generate persistent false positives that cannot be addressed through config exclusions.

### Specify Detector Versions

Some detectors have multiple versions. Use the colon syntax to target a specific version:

```bash
# Run GitHub detector version 2 and NpmToken detector version 2
trufflehog git file:///repo --include-detectors="Github:2,NpmToken:2"
```

Omitting the version runs all available versions of that detector.

### Override Verification Per Detector

Disable global verification but re-enable it for only specific high-value detectors:

```bash
# Disable all verification, but still verify AWS and Buildkite
trufflehog git file:///repo \
  --no-verification \
  --verify-detectors="AWS,Buildkite"
```

This is useful when you want faster scans but still need live confirmation for the most critical credential types.

### Disable All Verification

```bash
# Faster scan — no API calls, all findings are reported as 'unverified'
trufflehog git file:///repo \
  --no-verification \
  --results=verified,unverified,unknown \
  --fail
```

Useful for air-gapped environments or initial audits where speed matters more than confirmation.

---

## Adding Custom Detectors via config.yaml

Create a `config.yaml` file and pass it with `--config`:

```bash
trufflehog git file:///repo \
  --config=config.yaml \
  --fail
```

### Custom Detector Progression

Start with the minimal form and add fields as needed.

**Step 1 — Minimal: name, keywords, and regex**

```yaml
# config.yaml
detectors:
  - name: MyDetector
    keywords:
      - "myapi_"
    regex:
      secret_name: "myapi_[a-zA-Z0-9]{32}"
```

This is sufficient to detect any string matching the pattern. No verification is performed; state will be `unknown`.

**Step 2 — With entropy filter**

```yaml
detectors:
  - name: MyDetector
    keywords:
      - "myapi_"
    regex:
      secret_name: "myapi_[a-zA-Z0-9]{32}"
    entropy: 3.5
```

An entropy value of 3.5 means the matched string must have at least 3.5 bits of randomness per character. Strings like `myapi_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa` score near 0 and are filtered out.

**Step 3 — With exclusions**

```yaml
detectors:
  - name: MyDetector
    keywords:
      - "myapi_"
    regex:
      secret_name: "myapi_[a-zA-Z0-9]{32}"
    entropy: 3.5
    exclude_words:
      - "myapi_00000000000000000000000000000000"
      - "myapi_examplekeyfordemopurposesonly01"
    exclude_regexes_capture:
      - "^myapi_test_"     # Test environment keys
      - "^myapi_example_"  # Documentation examples
    exclude_regexes_match:
      - "placeholder"      # Suppresses lines containing 'placeholder'
```

**Step 4 — With verification webhook**

```yaml
detectors:
  - name: MyDetector
    keywords:
      - "myapi_"
    regex:
      secret_name: "myapi_[a-zA-Z0-9]{32}"
    entropy: 3.5
    exclude_words:
      - "myapi_00000000000000000000000000000000"
    verify:
      - endpoint: https://auth.myservice.example.com/verify
        unsafe: false
        headers:
          Content-Type: application/json
```

TruffleHog POSTs the matched value to the endpoint. Respond `200` for verified, `401`/`403` for unverified.

### Full config.yaml Structure Reference

```yaml
detectors:
  - name: MyDetector           # Required: unique detector name
    keywords:                  # Required: pre-filter strings (fast path)
      - "myapi_"
    regex:                     # Required: one or more capture patterns
      secret_name: 'myapi_[a-zA-Z0-9]{32}'
    entropy: 3.5               # Optional: Shannon entropy minimum
    exclude_words:             # Optional: exact values to skip
      - "myapi_00000000000000000000000000000000"
    exclude_regexes_match:     # Optional: suppress if line matches
      - "placeholder"
    exclude_regexes_capture:   # Optional: suppress if captured value matches
      - "^myapi_test_"
    verify:                    # Optional: verification endpoint(s)
      - endpoint: https://...
        unsafe: false
```

---

## Combining config.yaml with CLI Flags

CLI flags and `config.yaml` work together. CLI flags are applied after the config is loaded:

```bash
trufflehog git file:///repo \
  --config=config.yaml \
  --exclude-detectors="GenericPassword" \
  --results=verified \
  --fail
```

In this example:
- `config.yaml` defines custom detectors and their exclusions
- `--exclude-detectors` additionally skips the `GenericPassword` built-in detector
- `--results=verified` limits output to only confirmed active credentials

---

## Discovering Detector Names

To find the exact name of a built-in detector for use with `--include-detectors` or `--exclude-detectors`:

```bash
# Run a scan and extract unique detector names from JSON output
trufflehog git \
  --json \
  --no-verification \
  file://. \
  2>/dev/null | jq -r '.DetectorName' | sort -u
```

Or check the `DetectorName` field in any existing finding from a previous scan.

---

## Using a Config File in CI

Pass the config file in the GitHub Actions workflow:

```yaml
# Using the official action
- uses: trufflesecurity/trufflehog@v3.93.4
  with:
    extra_args: --config .trufflehog/config.yaml

# Using the binary install
- run: |
    trufflehog git \
      --config .trufflehog/config.yaml \
      --exclude-detectors="GenericPassword" \
      --results=verified \
      --fail \
      file://"$GITHUB_WORKSPACE"
```

The config file path is relative to the working directory (the checked-out repository root). Store the config file at `.trufflehog/config.yaml` and commit it alongside your workflow files.

---

## See Also

- [../examples/config-yaml-with-allowlist.md](../examples/config-yaml-with-allowlist.md) — Full config.yaml with exclusions and allowlist
- [../examples/custom-detector-config.md](../examples/custom-detector-config.md) — Custom detector with verification webhook
- [../concepts/detection-engine.md](../concepts/detection-engine.md) — How detectors work internally
- [../guides/suppressing-false-positives.md](./suppressing-false-positives.md) — Suppression methods beyond detector config
