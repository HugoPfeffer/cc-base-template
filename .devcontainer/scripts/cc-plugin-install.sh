#!/bin/bash
# Claude Code Plugin Install Script
# Run this script after the container has started to install Claude Code plugins

set -e

echo "Installing Claude Code plugins..."

echo "Adding superpowers marketplace..."
claude plugin marketplace add obra/superpowers-marketplace

echo "Installing plugins..."
claude plugin install superpowers@superpowers-marketplace --scope user
claude plugin install ralph-loop@claude-plugins-official --scope user
claude plugin install pyright-lsp@claude-plugins-official --scope user
claude plugin install typescript-lsp@claude-plugins-official --scope user
claude plugin install jdtls-lsp@claude-plugins-official --scope user
claude plugin install elements-of-style@superpowers-marketplace --scope user
claude plugin install episodic-memory@superpowers-marketplace --scope user
claude plugin install double-shot-latte@superpowers-marketplace --scope user

echo "Claude Code plugins installed successfully!"