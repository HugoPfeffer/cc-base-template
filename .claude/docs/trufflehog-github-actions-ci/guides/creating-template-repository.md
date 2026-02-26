---
title: "Creating a Template Repository for Org-Wide TruffleHog Scanning"
tags: [guide, template-repository, reusable-workflow, organisation, setup, dependabot, branch-protection]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "guides"
---

# Guide: Creating a Template Repository for Organisation-Wide Scanning

This guide walks through setting up a central repository that enforces TruffleHog secret scanning across every repository in your organisation. After following these steps, each project repo calls the engine workflow with approximately 8 lines of YAML.

## What You Will Build

```
org/.github (repository)
├── .github/
│   ├── CODEOWNERS
│   ├── dependabot.yml
│   └── workflows/
│       └── trufflehog-engine.yml   <- Reusable engine (workflow_call)
└── workflow-templates/
    ├── secret-scan.yml             <- Starter template (optional)
    └── secret-scan.properties.json
```

---

## Step 1: Create the Security Workflows Repository

Create or use the organisation `.github` repository. This special repository provides workflow templates and reusable workflows for the entire organisation.

If it does not exist:

```bash
gh repo create org/.github \
  --public \
  --description "Organization-wide GitHub Actions workflows and templates"
```

If it already exists, clone it:

```bash
git clone https://github.com/org/.github.git
cd .github
```

---

## Step 2: Create the Reusable Engine Workflow

```bash
mkdir -p .github/workflows
```

Create `.github/workflows/secret-scan.yml` as the reusable engine. This workflow must use the `workflow_call` trigger:

```yaml
# .github/workflows/secret-scan.yml
name: TruffleHog Secret Scan (Engine)
on:
  workflow_call: {}

permissions: {}

jobs:
  scan:
    name: TruffleHog Secret Scan
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - name: Checkout
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
        with:
          fetch-depth: 0
          persist-credentials: false

      - name: TruffleHog OSS
        uses: trufflesecurity/trufflehog@v3.93.4
        with:
          extra_args: --results=verified,unknown
```

Key elements to verify:
- `on: workflow_call:` is present (not `workflow_dispatch` or `push`)
- `permissions: {}` at workflow level (denies all by default)
- `fetch-depth: 0` in the checkout step (required for git history scanning)
- `persist-credentials: false` in the checkout step (security hardening)
- TruffleHog action is version-pinned

For the full annotated engine YAML, see [../examples/reusable-called-workflow.md](../examples/reusable-called-workflow.md).

---

## Step 3: Enable Organisation-Wide Access

By default, only the `.github` repository itself can call the engine workflow. Expand access so any repository in the organisation can use it:

1. Navigate to `https://github.com/org/.github` (the repository, not the org profile page)
2. Go to **Settings > Actions > General**
3. Under **"Access"**, select **"Accessible from repositories in the organization"**
4. Click **Save**

Without this step, callers in other repositories receive this error:

```
Error: The called workflow "org/.github/.github/workflows/secret-scan.yml@main"
is not permitted to be used from "org/some-repo"
```

---

## Step 4: Create the Starter Workflow Template

Starter workflows appear in the "New workflow" dialog for every repository in the organisation. They are copied into the calling repo (not invoked remotely), which is useful when teams need to customise the scan.

Create `workflow-templates/secret-scan.yml`:

```yaml
name: Secret Scan
on:
  push: {}
  pull_request: {}

jobs:
  scan:
    uses: org/.github/.github/workflows/secret-scan.yml@main
    secrets: inherit
```

Create the matching `workflow-templates/secret-scan.properties.json`:

```json
{
    "name": "TruffleHog Secret Scan",
    "description": "Scan for secrets on every push and pull request",
    "iconName": "security",
    "categories": [],
    "filePatterns": []
}
```

Commit both files:

```bash
git add workflow-templates/
git commit -m "chore: add TruffleHog starter workflow template"
git push
```

---

## Step 5: Tag the Engine Workflow for Versioning

After the initial release, tag the repository so callers can pin to a stable version:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Callers can now reference a specific version, preventing unexpected breaking changes when the engine is updated:

```yaml
uses: org/.github/.github/workflows/secret-scan.yml@v1.0.0
```

Update the tag when making breaking changes to inputs or behaviour.

---

## Step 6: Create the Thin Caller in Each Project Repository

For each repository that should be scanned, add a minimal caller workflow:

```bash
# Create the caller workflow in the project repository
mkdir -p /path/to/app-repo/.github/workflows

cat > /path/to/app-repo/.github/workflows/secret-scan.yml << 'EOF'
name: Secret Scan
on:
  push: {}
  pull_request: {}

jobs:
  scan:
    uses: org/.github/.github/workflows/secret-scan.yml@main
    secrets: inherit
EOF

cd /path/to/app-repo
git add .github/workflows/secret-scan.yml
git commit -m "chore: add org-wide TruffleHog secret scanning"
git push
```

For bulk onboarding across many repositories, use the GitHub API or `gh` CLI to automate committing the caller workflow.

---

## Step 7: Set Up Branch Protection with Required Status Checks

After the workflow has run at least once in an application repository, require it to pass before merging:

```bash
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/org/APP_REPO/branches/main/protection" \
  -f required_status_checks='{"strict":true,"contexts":["TruffleHog Secret Scan"]}' \
  -f enforce_admins=true \
  -f required_pull_request_reviews=null \
  -f restrictions=null
```

The context string `"TruffleHog Secret Scan"` must exactly match the job name shown in the GitHub Actions UI.

---

## Step 8: Add CODEOWNERS to Protect the Engine

Add CODEOWNERS so the security team must approve any changes to the engine workflow:

```bash
cat >> .github/CODEOWNERS << 'EOF'
# Security team must approve changes to the scanning engine
.github/workflows/secret-scan.yml @org/security-team
workflow-templates/ @org/security-team
EOF

git add .github/CODEOWNERS
git commit -m "chore: require security team review for engine workflow changes"
git push
```

---

## Step 9: Configure Dependabot for Automatic Action Updates

Add Dependabot configuration to the central repository to automatically receive pull requests when new TruffleHog versions are released:

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    labels:
      - "security"
      - "dependencies"
```

Commit this file:

```bash
git add .github/dependabot.yml
git commit -m "chore: configure Dependabot for weekly GitHub Actions updates"
git push
```

Dependabot will open pull requests to bump `trufflesecurity/trufflehog` when new releases are published. Because the engine workflow is centralised, a single PR updates the version for all organisation repositories.

---

## Maintenance

### Updating TruffleHog Version Manually

Edit the engine workflow's `uses: trufflesecurity/trufflehog@v3.93.4` line. All callers automatically pick up the new version on their next run — no changes needed in individual project repositories.

### Checking the Engine is Accessible

```bash
# Verify the workflow appears in the org's available reusable workflows
gh api /orgs/org/actions/workflows
```

---

## See Also

- [../examples/reusable-called-workflow.md](../examples/reusable-called-workflow.md) — Complete annotated engine YAML
- [../examples/reusable-caller-workflow.md](../examples/reusable-caller-workflow.md) — Complete caller YAML
- [../patterns/reusable-workflow-pattern.md](../patterns/reusable-workflow-pattern.md) — Pattern overview and rationale
- [../concepts/template-repository-model.md](../concepts/template-repository-model.md) — Concepts and architectural trade-offs
- [../examples/branch-protection-required-checks.md](../examples/branch-protection-required-checks.md) — Branch protection detailed setup
