---
title: "Local TruffleHog Installation"
tags: [guide, installation, binary, docker, homebrew, pre-commit, version-pinning]
created: "2026-02-26"
domain: "trufflehog-github-actions-ci"
section: "guides"
---

# Guide: Local TruffleHog Installation

This guide covers all supported methods for installing TruffleHog v3 locally or in CI, with instructions for version pinning and a comparison table to help you choose the right method.

## Method 1: Install Script (Recommended for CI)

The official install script is the fastest method for CI environments and Linux/macOS developer machines. It downloads and installs a precompiled binary from the TruffleHog GitHub releases page.

```bash
# Install latest version to /usr/local/bin
curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh \
  | sh -s -- -b /usr/local/bin

# Verify installation
trufflehog --version
```

### Version Pinning (Always Use in CI)

Pinning a specific version ensures reproducible scans and prevents unexpected behaviour from new releases:

```bash
# Install specific pinned version — recommended for all CI environments
curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh \
  | sh -s -- -b /usr/local/bin v3.93.4

trufflehog --version
# Expected output: trufflehog 3.93.4
```

The `-b /usr/local/bin` flag sets the destination directory. For CI runners where `/usr/local/bin` is on `$PATH`, this works without any further configuration.

### GitHub Actions Step

```yaml
- name: Install TruffleHog
  run: |
    curl -sSfL \
      https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh \
      | sh -s -- -b /usr/local/bin v3.93.4
    trufflehog --version
```

Always specify a version in CI for reproducibility. Omitting the version installs the latest release, which can introduce breaking changes without warning.

---

## Method 2: Official GitHub Action

The official action is the simplest way to run TruffleHog in GitHub Actions without managing installation. It is a composite action that internally uses a Docker container (`ghcr.io/trufflesecurity/trufflehog`).

```yaml
- uses: trufflesecurity/trufflehog@main
  with:
    extra_args: --results=verified
```

For a specific pinned version (recommended for production):

```yaml
- uses: trufflesecurity/trufflehog@v3.93.4
  with:
    extra_args: --results=verified,unknown
```

This method:
- Handles base/head SHA detection automatically via `github.event.before` and `github.event.pull_request.base.sha`
- Always injects `--fail`, `--no-update`, `--github-actions` flags
- Requires Docker on the runner (available on all GitHub-hosted runners)
- Does not require a separate install step

Note: The official action is a **composite** action, not a Docker action. It uses `docker run` internally. This means it still requires Docker to be available on the runner.

See [../patterns/binary-install-vs-official-action.md](../patterns/binary-install-vs-official-action.md) for when to use this vs the binary install.

---

## Method 3: Docker (Manual)

Run TruffleHog directly via Docker without installing the binary. Images are available from both `ghcr.io` and `docker.io`. The image supports multiple architectures (amd64, arm64).

```bash
# Scan current directory with latest tag (not recommended for production)
docker run --rm -v "$(pwd)":/tmp -w /tmp \
  ghcr.io/trufflesecurity/trufflehog:latest \
  git file:///tmp/ --results=verified --json

# Scan with a pinned version (recommended)
docker run --rm -v "$(pwd)":/tmp -w /tmp \
  ghcr.io/trufflesecurity/trufflehog:v3.93.4 \
  git file:///tmp/ --results=verified --json

# With config file mounted
docker run --rm \
  -v "$(pwd)":/workspace \
  -w /workspace \
  ghcr.io/trufflesecurity/trufflehog:v3.93.4 \
  git \
    --config /workspace/.trufflehog/config.yaml \
    --fail \
    file:///workspace
```

Available registries:
- `ghcr.io/trufflesecurity/trufflehog` (GitHub Container Registry — primary)
- `docker.io/trufflesecurity/trufflehog` (Docker Hub — mirror)

Use a specific version tag rather than `latest` for reproducible scans.

---

## Method 4: Homebrew (macOS Developer Workstations)

Best for macOS developer workstations. This method is too slow for CI runners due to formula resolution overhead.

```bash
# Add the TruffleSecurity tap and install
brew install trufflehog/trufflehog/trufflehog

# Verify
trufflehog --version

# Update to latest release
brew upgrade trufflehog
```

The formula is maintained in a custom Homebrew tap (`trufflehog/trufflehog`). This installs the binary to the standard Homebrew prefix and keeps it managed by `brew upgrade`.

---

## Method 5: Pre-commit Framework

For developer workstations using the `pre-commit` framework, this method runs TruffleHog automatically before every commit.

Add to your `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/trufflesecurity/trufflehog
    rev: v3.93.4
    hooks:
      - id: trufflehog
```

Then install the hook:

```bash
# Install pre-commit if not present
pip install pre-commit

# Install the configured hooks
pre-commit install

# Run manually across all files (for initial audit)
pre-commit run trufflehog --all-files
```

This method does not install TruffleHog globally — the pre-commit framework manages an isolated environment. The `rev` field pins the version.

See [../patterns/pre-commit-to-ci-layered-defense.md](../patterns/pre-commit-to-ci-layered-defense.md) for the layered defence strategy combining pre-commit with CI scanning.

---

## Verifying Any Installation

After installing via any method, confirm the binary works:

```bash
# Check version
trufflehog --version
# Expected: trufflehog 3.93.4

# Quick smoke test — scan current directory without verification
trufflehog git \
  --no-verification \
  --results=verified,unverified,unknown \
  file://. \
  --max-depth 5
```

---

## Method Comparison

| Method | Speed | CI Suitability | Version Pinning | Docker Required |
|--------|-------|----------------|-----------------|-----------------|
| Install script | Fast | Excellent | `sh -s -- -b /usr/local/bin v3.93.4` | No |
| Official Action | Medium | Excellent | `trufflesecurity/trufflehog@v3.93.4` | Yes (internal) |
| Docker manual | Medium | Good | Image tag `v3.93.4` | Yes |
| Homebrew | Slow (resolution) | Poor | `brew pin trufflehog` (fragile) | No |
| pre-commit | Fast | Poor (commit hooks) | `rev: v3.93.4` | No |

**Recommendation summary:**
- CI pipelines on GitHub-hosted runners: use the **Official Action** for simplicity, or **Install script** for maximum flexibility
- Local development on macOS: use **Homebrew** or **pre-commit**
- Air-gapped or custom Docker environments: use **Docker manual**

---

## See Also

- [../patterns/binary-install-vs-official-action.md](../patterns/binary-install-vs-official-action.md) — Detailed comparison of binary install vs official action
- [../patterns/pre-commit-to-ci-layered-defense.md](../patterns/pre-commit-to-ci-layered-defense.md) — Pre-commit and CI layered defence pattern
- [../concepts/trufflehog-architecture.md](../concepts/trufflehog-architecture.md) — CLI flags and architecture reference
