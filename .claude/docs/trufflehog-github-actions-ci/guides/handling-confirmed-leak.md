---
title: "Handling a Confirmed Secret Leak"
tags: [guide, incident-response, verified-finding, credential-revocation, remediation, howtorotate, blast-radius]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "guides"
---

# Guide: Handling a Confirmed Secret Leak

When TruffleHog reports a `verified` finding, a live credential is confirmed active in your git history. This is a security incident. This guide provides the step-by-step response.

## The Core Principle

**Do NOT delete the secret from code first — revoke it at the provider first.**

The credential is in git history. Anyone with access to the repository (past or present), any CI system that cloned it, and any backup service that mirrored it may have a copy. Deleting the file or commit does not invalidate the credential. The only effective immediate action is **credential revocation at the issuing provider**.

---

## Immediate Response (First 15 Minutes)

### Step 1: Identify the Credential Type

Read the TruffleHog JSON output to understand what was found:

```json
{
  "DetectorName": "AWS",
  "Verified": true,
  "Raw": "AKIAIOSFODNN7EXAMPLE",
  "ExtraData": {
    "account": "123456789012",
    "arn": "arn:aws:iam::123456789012:user/ci-user"
  },
  "SourceMetadata": {
    "Data": {
      "Git": {
        "commit": "a1b2c3d4",
        "file": "config/aws.yml",
        "line": 15
      }
    }
  }
}
```

Key fields:
- `DetectorName` — which service the credential belongs to
- `Raw` — the exposed credential value
- `ExtraData` — service-specific context (account ID, user ARN, etc.)
- `SourceMetadata.Data.Git` — exact location in git history

TruffleHog output also includes a `Rotation_guide` URL in `ExtraData` for many credential types — follow this URL for service-specific rotation instructions.

### Step 2: Revoke the Credential at the Provider

Go to the issuing service and revoke or rotate the credential **before doing anything else in the repository**.

| Service | Revocation Location |
|---------|-------------------|
| AWS Access Key | IAM Console > Users > Security credentials > Deactivate key |
| GitHub PAT | Settings > Developer settings > Personal access tokens > Delete |
| GitHub App Secret | Settings > Developer settings > GitHub Apps > Rotate secret |
| Stripe Key | Dashboard > Developers > API Keys > Roll key |
| Google API Key | Cloud Console > APIs & Services > Credentials > Delete key |
| Slack Bot Token | Slack API > App Management > OAuth & Permissions > Revoke |
| Generic service | `https://howtorotate.com` — guides for 70+ credential types |

**howtorotate.com** is maintained by the TruffleHog team and provides step-by-step instructions for rotating credentials across dozens of services.

### Step 3: Assess Blast Radius

With the credential revoked, determine what access it had and whether it was misused:

- **AWS**: Check CloudTrail for the access key ID over the past 90 days
- **GitHub**: Check the token's audit log at Settings > Security log
- **Other services**: Review the service's access logs for the compromised credential

Look for:
- Access from unusual IP addresses or geographic regions
- Access at unusual times (outside normal business hours for your team)
- Operations inconsistent with the credential's intended use (data exports, new resource creation, permission changes)

---

## After Revocation

### Step 4: Remove the Secret from Code

After the credential is revoked, create a pull request to remove the hardcoded value:

```diff
- api_key: "AKIAIOSFODNN7EXAMPLE"
+ api_key: ""  # Replaced with environment variable — see deployment docs
```

Configure the replacement using a proper secrets mechanism:
- GitHub Actions: `${{ secrets.MY_KEY }}`
- AWS Secrets Manager or HashiCorp Vault for runtime injection
- Environment variables set at deployment time (never committed)

### Step 5: History Rewrite Decision

Removing the credential from the current code does not remove it from git history. You must decide:

**Option A: git-filter-repo (Destructive — affects all clones)**

```bash
pip install git-filter-repo

git filter-repo \
  --replace-text <(echo "AKIAIOSFODNN7EXAMPLE==>REDACTED_REVOKED_KEY")
```

This rewrites all commits touching the file, changes all commit SHAs, and requires all collaborators to re-clone. It also invalidates any open pull requests.

**Option B: Accept the history (Recommended in most cases)**

Since the credential is now revoked, it can no longer be used by anyone who finds it in history. Leaving it in history is not a security risk if:
- Revocation was immediate and complete
- The credential had limited scope
- The blast radius assessment found no evidence of exploitation

This avoids disrupting the entire team and all forks.

**Decision factors:**
- Sensitivity of what the credential accessed
- Number of collaborators who would be disrupted
- Whether external forks or archive mirrors exist
- Compliance requirements that mandate history sanitisation

### Step 6: Deploy New Credential with Least-Privilege Scope

Issue a new credential and use this incident as an opportunity to reduce its scope:

- Instead of an AWS access key for a full admin user, create an IAM role with only the permissions the CI job actually needs
- Instead of a classic GitHub PAT with broad scopes, use a fine-grained token scoped to the specific repository and permissions
- Set an expiration date on the new credential

Update any CI secrets or environment variables that were using the old credential.

### Step 7: Update CI Secrets or Environment Variables

After deploying the new credential, update all places where it was referenced:

```bash
# Update GitHub Actions secret
gh secret set AWS_ACCESS_KEY_ID --body "NEWKEYVALUE" --repo org/repo
gh secret set AWS_SECRET_ACCESS_KEY --body "NEWSECRETVALUE" --repo org/repo
```

Verify the updated workflow runs successfully with the new credential.

### Step 8: Post-Incident Documentation

Create an internal post-mortem or incident report covering:
- How the credential was committed (root cause)
- How it was detected (TruffleHog, timing relative to commit)
- What access the credential had and for how long it was exposed
- Whether evidence of exploitation was found
- Process changes to prevent recurrence (pre-commit hooks, secrets manager adoption, etc.)

---

## Rotation Resources

- **howtorotate.com** — Service-specific rotation guides for 70+ credential types, maintained by TruffleHog team
- AWS access keys: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html
- GitHub tokens: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/token-expiration-and-revocation

---

## See Also

- [../concepts/secret-scanning-fundamentals.md](../concepts/secret-scanning-fundamentals.md) — Why removing code from the working tree is insufficient
- [./suppressing-false-positives.md](./suppressing-false-positives.md) — Suppressing the old value if it remains in test fixtures
- [../troubleshooting/false-positives-common-cases.md](../troubleshooting/false-positives-common-cases.md) — Distinguishing verified findings from false positives
- [../references/sources.md](../references/sources.md) — howtorotate.com and other rotation references
