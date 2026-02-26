---
title: "Runner Permission Errors"
tags: [troubleshooting, docker, permissions, self-hosted-runner, github-token]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "troubleshooting"
---

# Troubleshooting: Runner Permission Errors

## Error: Docker Not Found

**Symptom**:

```
docker: command not found
```

or

```
Cannot connect to the Docker daemon at unix:///var/run/docker.sock
```

**Cause**: The official TruffleHog action (`trufflesecurity/trufflehog`) wraps a Docker container. It requires Docker to be installed and running on the runner.

**Note**: GitHub-hosted `ubuntu-latest` runners always have Docker pre-installed. This error appears on self-hosted runners without Docker.

**Fix — Option A: Use a GitHub-hosted runner**

```yaml
jobs:
  scan:
    runs-on: ubuntu-latest   # Docker is pre-installed
```

**Fix — Option B: Install Docker on the self-hosted runner**

```yaml
- name: Install Docker
  run: |
    apt-get update && apt-get install -y docker.io
    systemctl start docker
```

**Fix — Option C: Use the binary install method (no Docker required)**

```yaml
- name: Install TruffleHog binary
  run: |
    curl -sSfL \
      https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh \
      | sh -s -- -b /usr/local/bin v3.93.4

- name: Scan
  run: |
    trufflehog git \
      --fail \
      file://"$GITHUB_WORKSPACE"
```

See [../patterns/binary-install-vs-official-action.md](../patterns/binary-install-vs-official-action.md) for when to choose each approach.

---

## Error: Docker Permission Denied

**Symptom**:

```
docker: permission denied while trying to connect to the Docker daemon socket
```

or

```
Got permission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock
```

**Cause**: The user account running the GitHub Actions runner process does not have permission to access the Docker socket.

**Fix — Option A: Add the runner user to the `docker` group**

```bash
# Run on the self-hosted runner machine
sudo usermod -aG docker runner
# Log out and back in, or apply immediately with:
newgrp docker
```

**Fix — Option B: Temporarily chmod the Docker socket (less secure)**

```yaml
- name: Fix Docker socket permissions
  run: sudo chmod 666 /var/run/docker.sock
```

**Fix — Option C: Use rootless Docker** — configure the runner to use a rootless Docker daemon.

**Fix — Option D: Switch to binary install** — avoids Docker entirely.

---

## Error: Insufficient GITHUB_TOKEN Permissions

**Symptom**:

```
Error: Resource not accessible by integration
```

or

```
HttpError: Not Found
```

**Cause**: The workflow job is missing the `contents: read` permission. By default, GitHub Actions grants minimal permissions when `permissions` is explicitly defined.

**Fix**: Add an explicit permissions block to the job:

```yaml
jobs:
  scan:
    runs-on: ubuntu-latest
    permissions:
      contents: read   # Required to read repository contents
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
        with:
          fetch-depth: 0
      - uses: trufflesecurity/trufflehog@v3.93.4
```

If using the `github` subcommand to scan via API (not the cloned repo), pass the token explicitly:

```yaml
- name: Scan via GitHub API
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  run: |
    trufflehog github \
      --token "$GITHUB_TOKEN" \
      --org myorg \
      --fail
```

---

## Error: GITHUB_TOKEN Expired or Invalid

**Symptom**: TruffleHog fails during the verification phase with authentication errors against the GitHub API.

**Cause**: The `GITHUB_TOKEN` is valid only for the duration of the workflow job (up to 6 hours). It should not expire during a normal scan job, but custom PATs or organization tokens stored as secrets may expire separately.

**Diagnosis**:

```yaml
- name: Debug token
  run: gh auth status
  env:
    GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Fix**: For expired PATs, rotate the secret in the repository's Settings > Secrets. For the built-in `GITHUB_TOKEN`, check whether the job has been running for more than 6 hours — GitHub Actions kills jobs at that limit.

---

## Self-Hosted Runner Security Risks

Self-hosted runners introduce security concerns that GitHub-hosted runners do not have. These are particularly relevant for secret scanning workflows.

### Persistent State

Self-hosted runners retain files between jobs unless the runner is ephemeral. A malicious job (e.g., from a fork pull request) could write malicious scripts to the runner filesystem. These persist and can affect the next job on the same runner.

**The PyTorch incident**: Researchers demonstrated that persistent self-hosted runners used with public repositories can be exploited for long-term access, because a malicious PR can plant artifacts on the runner that execute during future legitimate jobs.

**Recommendation**: Never use self-hosted runners with public repositories. For private repositories, make runners ephemeral — torn down after each job using tools like:
- AWS EC2 with Auto Scaling
- Azure Container Instances
- GitHub's own larger hosted runners

### Write Token Risk

Self-hosted runners that also run production deployment jobs may have write-access tokens available in the environment. Do not run TruffleHog scans on runners that have deployment credentials — use separate dedicated runners for security scanning.

---

## Error: Reusable Workflow Not Accessible

**Symptom**:

```
Error: The called workflow 'org/.github/.github/workflows/engine.yml@main'
is not permitted to be used from 'org/other-repo'
```

**Cause**: The central engine repository has not been configured to allow access from other repositories in the organization.

**Fix**: In the engine repository, navigate to **Settings > Actions > General > Access** and select "Accessible from repositories in the organization."

See [../guides/creating-template-repository.md](../guides/creating-template-repository.md) for the full setup process.

---

## See Also

- [../patterns/binary-install-vs-official-action.md](../patterns/binary-install-vs-official-action.md) — When the binary avoids Docker issues
- [../concepts/github-actions-security-model.md](../concepts/github-actions-security-model.md) — Permissions model and token scopes
- [../guides/local-trufflehog-installation.md](../guides/local-trufflehog-installation.md) — Installation options including binary
