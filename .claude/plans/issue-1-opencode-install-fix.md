# Implementation Plan: Fix Issue #1 — "opencode install as root"

**GitHub Issue**: https://github.com/HugoPfeffer/cc-base-template/issues/1
**Status**: Planned, ready to implement
**Date**: 2026-02-20

## Problem

OpenCode was previously installed in the Dockerfile as root, creating `/home/node/.config/opencode` owned by `root:root`. The `node` user couldn't access its config directory at runtime. The install was removed; this plan adds it back correctly.

## The Fix (single line addition)

**File**: `/workspace/.devcontainer/Dockerfile`
**Location**: After line 128 (OpenSpec install), before line 130 (Spec-Kit install)

Insert:

```dockerfile
# Install OpenCode
RUN npm install -g opencode-ai@latest
```

Resulting context:

```dockerfile
# Install OpenSpec
RUN npm install -g @fission-ai/openspec@latest

# Install OpenCode
RUN npm install -g opencode-ai@latest

# Install Spec-Kit
RUN uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
```

## Why This Works

- Runs **after** `USER node` (line 61), so everything is owned by `node:node`
- Uses `npm install -g` consistent with OpenSpec on line 128
- Binary goes to `/usr/local/share/npm-global/bin/` (already in PATH, owned by node:node per lines 30-31, 67-68)
- Parent dir `/home/node/.config/` already exists as `node:node` (line 78)
- No need to pre-create config dir or add version ARG

## Key Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Install method | `npm install -g` | Consistent with OpenSpec pattern; uses existing NPM_CONFIG_PREFIX |
| Version | `@latest` | Matches OpenSpec pattern; easy to pin later |
| Pre-create config dir | No | Parent already owned by node:node |
| Placement | After OpenSpec, before Spec-Kit | Groups npm installs together |

## Branch & PR Strategy

1. Create branch from `main`: `fix/issue-1-opencode-install`
2. Apply the Dockerfile edit
3. Commit: `fix: install opencode as node user to fix config dir ownership`
4. Push and create PR against `main` with `Fixes #1`

## Steps to Execute

```bash
# 1. Create branch
git checkout main
git pull origin main
git checkout -b fix/issue-1-opencode-install

# 2. Edit Dockerfile (add the two lines after line 128)

# 3. Commit
git add .devcontainer/Dockerfile
git commit -m "$(cat <<'EOF'
fix: install opencode as node user to fix config dir ownership

Install opencode-ai via npm after USER node directive to ensure
/home/node/.config/opencode is owned by node:node at runtime.

Fixes #1
EOF
)"

# 4. Push and PR
git push -u origin fix/issue-1-opencode-install
gh pr create \
  --base main \
  --title "fix: install opencode as node user (fixes #1)" \
  --body "$(cat <<'EOF'
## Summary
- Adds opencode-ai npm install to Dockerfile after USER node (line 61)
- Ensures config directory ownership is node:node instead of root:root
- Uses npm install method consistent with existing OpenSpec install

## Root Cause
OpenCode was previously installed as root, causing /home/node/.config/opencode
to be owned by root:root. The node user could not access its own config directory.

## Fix
Install opencode-ai after the USER node directive, alongside other user-space tools.

Fixes #1
EOF
)"
```

## Testing

1. Rebuild container, run `opencode --version`
2. Check `ls -la /home/node/.config/opencode/` shows `node:node`
3. Run `opencode` interactively to confirm no permission errors

## Reference

- OpenCode repo: https://github.com/anomalyco/opencode (107k stars, v1.2.10)
- npm package: `opencode-ai`
- Install docs: https://opencode.ai/docs
