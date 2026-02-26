---
title: "Custom Regex Detector with Verification Webhook"
tags: [example, custom-detector, regex, verification, webhook, entropy]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "examples"
---

# Example: Custom Regex Detector with Verification Webhook

This example shows a complete custom detector definition for an organisation-specific credential format, including live credential verification via a webhook server. This is the most advanced form of custom detection — equivalent in capability to TruffleHog's built-in AWS or GitHub detectors.

## Scenario

Your organisation issues internal API tokens with the format `hog<17 alphanumeric chars>` paired with a base64-encoded secret. You want TruffleHog to detect these tokens and verify whether they are still active by calling an internal service.

## The Custom Detector Config

```yaml
# .trufflehog/config.yaml

detectors:
  - name: HogTokenDetector
    keywords:
      - hog
    regex:
      hogid: '\b(hog[0-9a-z]{17})\b'
      hogtoken: '[^A-Za-z0-9+\/]{0,1}([A-Za-z0-9+\/]{40})[^A-Za-z0-9+\/]{0,1}'
    verify:
      - endpoint: http://localhost:8000/
        unsafe: true
        headers:
          - "Authorization: super secret authorization header"
```

### How the Detector Works

- `keywords: [hog]` — the Aho-Corasick pre-filter scans file content for the literal string `hog` before evaluating the regex. Files and chunks without this keyword are skipped entirely, making the scan much faster.
- `regex.hogid` — matches the token ID: `hog` followed by 17 lowercase alphanumeric characters, bounded by word boundaries (`\b`).
- `regex.hogtoken` — matches a 40-character base64-encoded value. The outer non-base64 character assertions (`[^A-Za-z0-9+\/]{0,1}`) anchor the match without consuming surrounding context.
- `verify.endpoint` — TruffleHog POSTs to this URL with the matched values for live verification.
- `unsafe: true` — allows HTTP (non-TLS) endpoints. In production, use an HTTPS endpoint and remove this flag.
- `headers` — custom HTTP headers added to every verification request. Use for authentication to the verification endpoint.

## Verification Webhook POST Format

When TruffleHog finds a match, it POSTs a JSON body to the verification endpoint:

```json
{
  "HogTokenDetector": {
    "hogid": "hog1234567890abcdefg",
    "hogtoken": "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmn"
  }
}
```

The body structure is:

```
{ "<DetectorName>": { "<regex_group_name>": "<matched_value>", ... } }
```

All named groups from the `regex` map are included in the POST body.

### Response Code Semantics

| HTTP Response | TruffleHog State | Meaning |
|---------------|-----------------|---------|
| `200` | `verified` | The credential is active. Report as a high-confidence finding. |
| `401` or `403` | `unverified` | The credential exists but is not valid (revoked, expired, or wrong). |
| Any other code or timeout | `unknown` | Cannot determine status. Depends on `--results` filter. |

## Minimal Verification Server (Python)

This server handles POST requests from TruffleHog and validates the extracted token value against an internal service:

```python
import json
from http.server import BaseHTTPRequestHandler, HTTPServer


def validate(request: dict) -> bool:
    """
    Validate the token extracted by HogTokenDetector.
    request['HogTokenDetector']['hogtoken'] contains the matched value.
    """
    token = request.get("HogTokenDetector", {}).get("hogtoken")
    if not token:
        return False
    # Replace with actual validation logic (database lookup, API call, etc.)
    return token.startswith("valid_prefix")


class Verifier(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers['Content-Length'])
        request = json.loads(self.rfile.read(length))
        # Return 200 if valid (verified), 403 if not (unverified)
        self.send_response(200 if validate(request) else 403)
        self.end_headers()

    def log_message(self, format, *args):
        # Suppress default access log output
        pass


if __name__ == "__main__":
    with HTTPServer(('', 8000), Verifier) as server:
        print("Verification server running on port 8000")
        server.serve_forever()
```

In production, replace the `validate` function with a real lookup against your credential store, an internal API, or a database.

## Testing with stdin

Test the detector without running a full git scan by piping content directly:

```bash
# Test that the detector fires on a matching string
echo "hog_token_value" | trufflehog stdin --config=.trufflehog/config.yaml

# Test with the full results filter to see all states
echo "token: hog1234567890abcdefg" | \
  trufflehog stdin \
    --config=.trufflehog/config.yaml \
    --results=verified,unverified,unknown \
    --json

# Test against a specific file
trufflehog filesystem ./test-file.txt \
  --config=.trufflehog/config.yaml \
  --results=verified,unverified,unknown \
  --json
```

The `stdin` source is useful during development to quickly iterate on regex patterns without committing test files.

## Testing Without a Running Verification Server

During development, you may not have the verification server running. Use `--no-verification` to collect matches without attempting to verify them:

```bash
trufflehog git "file://." \
  --config=.trufflehog/config.yaml \
  --no-verification \
  --results=verified,unverified,unknown \
  --json
```

With `--no-verification`, all matches are reported with state `unknown`.

## Using in a GitHub Actions Workflow

Reference the config file in your workflow:

```yaml
- name: TruffleHog Scan
  uses: trufflesecurity/trufflehog@main
  with:
    extra_args: >-
      --config .trufflehog/config.yaml
      --results=verified,unknown
```

Or with the binary install:

```yaml
- name: Scan
  run: |
    trufflehog git "file://$GITHUB_WORKSPACE" \
      --config .trufflehog/config.yaml \
      --results=verified,unknown \
      --json --no-update --github-actions
```

Note: In GitHub Actions CI, the verification webhook must be reachable from the runner. For internal endpoints, this typically requires a self-hosted runner on your network or a VPN/tunnel.

## See Also

- [../guides/configuring-detectors.md](../guides/configuring-detectors.md) — Complete detector configuration guide
- [config-yaml-with-allowlist.md](./config-yaml-with-allowlist.md) — Full config.yaml with allowlist and path exclusions
