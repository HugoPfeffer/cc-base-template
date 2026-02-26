---
title: "Branch Protection Required Checks for TruffleHog"
tags: [example, branch-protection, required-checks, enforcement, github, rulesets, codeowners]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "examples"
---

# Example: Branch Protection Required Checks

A TruffleHog scan that is not enforced as a required check is advisory only — developers can merge code regardless of findings. This example shows how to configure GitHub branch protection to make the scan mandatory before any pull request can be merged.

## Prerequisites

The TruffleHog workflow must have run at least once against the target branch before GitHub will list its job as an available required check. Open a test PR or push a commit to trigger the first run.

## Step 1: Identify the Check Name

The required check name is the `name:` field of the job in your workflow YAML. If no `name:` field is present, the job key is used.

For this workflow:

```yaml
# .github/workflows/secret-scan.yml
name: Secret Scanning

jobs:
  trufflehog:
    name: TruffleHog Secret Scan   # <- This is the check name
    runs-on: ubuntu-latest
```

The check name that appears in GitHub's status checks list will be `TruffleHog Secret Scan`.

## Step 2: Configure Branch Protection via UI

1. Go to the repository **Settings > Branches**
2. Click **Add branch protection rule** (or edit an existing rule for `main`)
3. Set **Branch name pattern**: `main`
4. Enable the following settings:

| Setting | Value | Reason |
|---------|-------|--------|
| Require status checks to pass before merging | Enabled | Core requirement — blocks merge when scan fails |
| Require branches to be up to date before merging | Enabled | Prevents a stale-base bypass where the scan ran against an older version of `main` |
| Status checks — search and add | `TruffleHog Secret Scan` | The exact name of your scan job |
| Do not allow bypassing the above settings | Enabled | Prevents repository administrators from merging without a passing scan |

5. Click **Save changes**

## Step 3: Configure via GitHub CLI

The GitHub CLI provides a scriptable alternative to the UI, useful for automating branch protection across many repositories:

```bash
gh api repos/{owner}/{repo}/branches/main/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":["TruffleHog Secret Scan"]}'
```

For a complete protection configuration that also prevents direct pushes and enforces reviews:

```bash
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  /repos/{owner}/{repo}/branches/main/protection \
  -f required_status_checks='{"strict":true,"contexts":["TruffleHog Secret Scan"]}' \
  -f enforce_admins=true \
  -f required_pull_request_reviews=null \
  -f restrictions=null
```

Parameters:
- `strict: true` — requires the branch to be up to date with the base branch before merging. Without this, a PR that was scanned before a malicious push to `main` could slip through.
- `enforce_admins: true` — applies the protection rule to repository administrators. Without this, admins can bypass the required check.
- `contexts` — must exactly match the check name as it appears in the GitHub UI. Case-sensitive.

## Step 4: Verify the Configuration

After configuring branch protection, verify it is active:

```bash
gh api /repos/{owner}/{repo}/branches/main/protection \
  --jq '.required_status_checks'
```

Expected output:

```json
{
  "strict": true,
  "contexts": ["TruffleHog Secret Scan"],
  "checks": [
    {
      "context": "TruffleHog Secret Scan",
      "app_id": null
    }
  ]
}
```

Open a test pull request with a known-clean branch to confirm the check appears as pending, then passes.

## CODEOWNERS for Workflow File Protection

Branch protection prevents merging when the scan fails, but it does not prevent someone from modifying the workflow file itself to weaken the scan. Use CODEOWNERS to require security team review for any change to workflow files:

```
# .github/CODEOWNERS
# Security team must approve any change to GitHub Actions workflows
.github/workflows/ @your-org/security-team
```

With this in place:
- Any pull request that modifies `.github/workflows/` will require an approving review from a member of `@your-org/security-team`
- Combined with "Require status checks" and "Dismiss stale reviews", this prevents workflow tampering

For the CODEOWNERS rule to be enforced, enable "Require review from Code Owners" in the branch protection settings.

## GitHub Rulesets (Modern Alternative)

GitHub Rulesets (available in all plans as of 2024) are the recommended approach for organisation-wide enforcement. They supersede per-repository branch protection rules and can be managed centrally:

```json
{
  "name": "Require Secret Scan",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["~DEFAULT_BRANCH"],
      "exclude": []
    }
  },
  "rules": [
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          {
            "context": "TruffleHog Secret Scan"
          }
        ]
      }
    }
  ]
}
```

Apply the ruleset via GitHub CLI:

```bash
# Create as a repository ruleset
gh api \
  --method POST \
  /repos/{owner}/{repo}/rulesets \
  --input ruleset.json

# Or create as an organisation-wide ruleset (requires org admin)
gh api \
  --method POST \
  /orgs/{org}/rulesets \
  --input ruleset.json
```

Advantages of Rulesets over classic branch protection:
- Can be applied to all repositories in an organisation from one place
- Support bypass lists (specific actors can merge without the check)
- Can target multiple branch patterns in a single rule
- More granular audit logging

## See Also

- [../concepts/github-actions-security-model.md](../concepts/github-actions-security-model.md) — CODEOWNERS, permissions, and security model
- [../patterns/ci-scan-on-pull-request.md](../patterns/ci-scan-on-pull-request.md) — PR scan pattern that produces the required check
- [trufflehog-git-scan-workflow.md](./trufflehog-git-scan-workflow.md) — The workflow whose check is enforced here
