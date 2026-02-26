---
title: "False Positives — Common Cases"
tags: [troubleshooting, false-positives, test-fixtures, documentation, vendor]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "troubleshooting"
---

# Troubleshooting: False Positives — Common Cases

## Overview

A false positive is a TruffleHog finding that does not represent a real, dangerous secret. Before suppressing any finding, verify it is actually false: confirm the credential is not real and does not grant access. Never suppress a `verified` finding — if TruffleHog confirms a credential is live, treat it as a real incident.

For suppression methods, see [../guides/suppressing-false-positives.md](../guides/suppressing-false-positives.md).

---

## Case 1: Test Fixtures with Fake Credentials

**Symptom**: TruffleHog reports findings in `test/fixtures/`, `spec/fixtures/`, or similar test data directories. The credentials are clearly fake (e.g., `AKIAIOSFODNN7EXAMPLE`, `sk_test_fake`).

**Cause**: TruffleHog scans all files in git history, including test data. Fake credentials that match real key patterns are flagged.

**Fix — Option A: Inline ignore (most surgical)**

```python
# tests/fixtures/aws_response.py
AWS_KEY = "AKIAIOSFODNN7EXAMPLE"  # trufflehog:ignore
```

**Fix — Option B: Exclude the fixtures directory**

```
# .trufflehog/exclude-paths.txt
^tests?/fixtures/
^spec/fixtures/
```

Pass the file to the scan:
```bash
trufflehog git --exclude-paths=.trufflehog/exclude-paths.txt file://.
```

---

## Case 2: Documentation with Example Keys

**Symptom**: Findings in `README.md`, `docs/`, or inline code examples in Markdown files. Example: a quickstart guide shows `export API_KEY="sk_live_your_key_here"`.

**Cause**: Documentation examples use realistic-looking key formats to help readers identify where to paste their own key.

**Note**: TruffleHog's built-in word list catches many known placeholder patterns (e.g., strings containing `EXAMPLE`, `YOUR_KEY_HERE`). If verification shows the key is not active (`unverified`), it is likely already handled. Only suppress if you have confirmed it is a false positive.

**Fix**:

```
# .trufflehog/exclude-paths.txt
^docs/
\.md$
```

Or inline suppression in Markdown:

```markdown
export API_KEY="sk_live_your_key_here"  <!-- trufflehog:ignore -->
```

Note: Markdown inline suppression is less reliable than exclude-paths for documentation directories.

---

## Case 3: Vendored Third-Party Code

**Symptom**: Findings in `vendor/`, `node_modules/`, or any vendored dependency directory. The credentials belong to example code in a library, not your application.

**Cause**: Vendored code is committed into the repository and is therefore scanned. Third-party libraries frequently contain example credentials in their test suites and documentation.

**Fix**:

```
# .trufflehog/exclude-paths.txt
^vendor/
^node_modules/
^.*/vendor/
```

This is typically one of the first exclusions to add to any new configuration.

---

## Case 4: Credential Rotation and Migration Scripts

**Symptom**: A finding references a revoked key in a migration or rotation script committed historically. The credential is `unverified` (no longer active) but continues appearing in full-history scans.

**Cause**: The script was a legitimate operational tool when committed. The key it references has since been rotated, but the script remains in git history.

**Fix — Option A: Inline suppression in the script**

```bash
# scripts/migrations/2023-rotate-aws-key.sh
OLD_KEY="AKIAOLDKEY000000000" # trufflehog:ignore
```

**Fix — Option B: Exclude the migration directory**

```
# .trufflehog/exclude-paths.txt
^scripts/migrations/
```

---

## Case 5: Same Finding on Every PR

**Symptom**: The same finding appears on every PR, even PRs that do not modify the affected file.

**Root cause**: The file containing the false positive exists in the base branch. On each PR, TruffleHog scans from the base commit SHA to the head commit SHA. If the false-positive file falls within that diff range (even unchanged), it is reported.

**Important**: If the credential is `verified` (live), this is not a false positive — the credential must be revoked. Removing it from the code does not help because it persists in git history.

**Diagnosis**:

```bash
git log --oneline --follow -p -- <file-from-finding>
```

**Fix**: Suppress the specific line using an inline `# trufflehog:ignore` comment, or exclude the path. Once the suppression is committed to the base branch, it will no longer appear in future PRs.

---

## Case 6: High-Entropy Generated or Encoded Content

**Symptom**: Random-looking strings in generated code, compiled output, or base64-encoded content match a detector pattern. Common in protobuf-generated code, minified JavaScript, or binary data embedded as strings.

**Cause**: High-entropy strings are a primary signal for secrets. Generated code often produces similarly high-entropy strings for non-secret purposes (hashes, UUIDs, encoded payloads).

**Fix — Use `--results=verified` to only fail on confirmed-live secrets**:

```bash
trufflehog git --results=verified --fail file://.
```

**Fix — Exclude generated file patterns**:

```
# .trufflehog/exclude-paths.txt
_generated\.go$
_pb2\.py$
\.pb\.go$
_gen\.go$
\.min\.js$
\.wasm$
```

---

## Case 7: Third-Party SDK or Framework Example Code

**Symptom**: The repository contains SDK source code or framework code. Test files include comprehensive credential pattern examples for documentation purposes.

**Cause**: Some repositories (AWS SDK implementations, Stripe client libraries) intentionally contain realistic credential patterns in their test suites to exercise their own parsing logic.

**Fix**: Use `--exclude-detectors` to skip specific noisy detectors:

```bash
trufflehog git --exclude-detectors="SomeNoisyDetector" file://.
```

Or create a comprehensive exclude-paths file targeting the test and example directories. Document why scanning is excluded in configuration file comments.

---

## Confirming a False Positive vs a Real Secret

Before suppressing any finding, work through this checklist:

1. **Is `Verified: true`?** — If yes, this is not a false positive. Revoke the credential immediately and treat as an incident.
2. **Is `--results=verified` already in use?** — If so, only confirmed-live secrets reach you. Investigate all findings.
3. **Examine the `Raw` value** — Does it look like a real key (high entropy, correct format, meaningful service prefix) or a placeholder (contains the word `EXAMPLE`, `TEST`, `FAKE`, `YOUR`)?
4. **Check the commit history** — When was it introduced? By whom? Does the commit message suggest intentional placeholder use?
5. **Test the credential manually** — For low-risk credentials, verify against the provider's API whether the credential grants access.
6. **Document the suppression decision** — Record why the finding was suppressed so future reviewers understand the rationale.

---

## See Also

- [../guides/suppressing-false-positives.md](../guides/suppressing-false-positives.md) — All suppression methods in detail
- [../concepts/detection-engine.md](../concepts/detection-engine.md) — Why false positives occur and how verification reduces them
- [../guides/handling-confirmed-leak.md](../guides/handling-confirmed-leak.md) — What to do if the finding is real
