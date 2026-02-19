#!/bin/bash
# Claude Code Plugin Install Script
# Run this script after the container has started to install Claude Code plugins

set -e

echo "Installing Claude Code plugins..."

echo "Adding superpowers marketplace..."
claude plugin marketplace add obra/superpowers-marketplace

echo "Installing plugins..."
# claude plugin install superpowers@superpowers-marketplace --scope user
ralph-loop@claude-plugins-official
pyright-lsp@claude-plugins-official
typescript-lsp@claude-plugins-official
jdtls-lsp@claude-plugins-official
elements-of-style@superpowers-marketplace
episodic-memory@superpowers-marketplace
# claude plugin install double-shot-latte@superpowers-marketplace --scope user

echo "Claude Code plugins installed successfully!"