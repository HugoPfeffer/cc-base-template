# CLAUDE.md

## What This Is

A devcontainer base template for spinning up isolated, AI-native development sandboxes. Clone or copy this repo to start a new project with a fully configured environment — no application code lives here by design.

## Environment

- **Container**: Node.js 20 (Debian-based), runs as `node` user
- **Workspace**: Bind-mounted at `/workspace`
- **Shell**: Bash with Starship prompt, fzf, direnv, git-delta, persistent history
- **Model**: `ANTHROPIC_MODEL=opus` by default

## Installed Tools

| Category | Tools |
|----------|-------|
| **AI/Agent** | Claude Code, Plannotator, OpenSpec, OpenCode, Spec-Kit (`specify`) |
| **Languages** | Node.js 20, Python 3 (pip, pipx, uv) |
| **Cloud/K8s** | kubectl, Helm 4, oc (OpenShift client) |
| **Git** | gh CLI, git-delta, pre-commit |
| **Security** | TruffleHog (pre-commit hook + CI workflow) |

## MCP Servers

Defined in `.mcp.json`:

- **context7** — library/framework documentation lookup (requires `CONTEXT7_API_KEY`)
- **firecrawl-mcp** — web scraping and search (requires `FIRECRAWL_LOCAL_API_URL`)
- **kubernetes** — read-only Kubernetes cluster interaction
- **github** — GitHub Copilot MCP API (requires `GITHUB_TOKEN`)

## Secrets & Environment Variables

Never hardcode secrets. Copy `.env.example` to `.env` and fill in real values:

- `CONTEXT7_API_KEY`
- `FIRECRAWL_LOCAL_API_URL`
- `GITHUB_TOKEN`

Git identity (`GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL`, `GIT_COMMITTER_NAME`, `GIT_COMMITTER_EMAIL`) is passed through from the host via `remoteEnv`.

## Security Rules

- **No secrets in code** — ever. Use environment variables or secret managers.
- **TruffleHog** runs at three layers: pre-commit hook, CI workflow, and is installed in the container.
- **GitHub Actions** must use SHA-pinned actions, minimal permissions, and `persist-credentials: false`.
- See `.claude/rules/` for detailed AI-specific security guidance.

## Spec-Driven Workflow

This template includes an OpenSpec configuration (`openspec/`) with a custom schema that enforces a structured development pipeline:

**proposal → research → spec → design → tasks → apply**

Each phase has quality gates. Research uses context7 and firecrawl MCP servers. Specs use GIVEN/WHEN/THEN format with traceability IDs (CAP-\*, REQ-\*, SCN-\*, DES-\*, TSK-\*).

## Shell Aliases

- `claude` — runs Claude Code with `--allow-dangerously-skip-permissions`
- `specify` — runs spec-kit via uvx
- `gen-guid` — generates a UUID
- `bashrc-open` / `bashrc-source` — edit and reload bash config

## Key Conventions

- Always use **context7 MCP** for official documentation lookups before relying on training data.
- Always use **firecrawl MCP** when searching for production patterns or web content.
- Do not create markdown files unless explicitly requested.
- Pre-commit hooks must pass before pushing — TruffleHog will block verified credential leaks.
- This is a template repo: extend it with your own application code, tests, and CI pipelines.
