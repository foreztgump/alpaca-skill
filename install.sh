#!/usr/bin/env bash
# install.sh — Install alpaca-skill as a Claude Code skill
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly SKILL_NAME="alpaca-skill"
readonly TARGET_DIR="${HOME}/.claude/skills/${SKILL_NAME}"

echo "Installing ${SKILL_NAME}..."

# Create target directory
mkdir -p "${TARGET_DIR}/scripts" "${TARGET_DIR}/references"

# Copy skill manifest
cp "${SCRIPT_DIR}/SKILL.md" "${TARGET_DIR}/SKILL.md"

# Copy scripts
cp "${SCRIPT_DIR}/scripts/"*.sh "${TARGET_DIR}/scripts/"
chmod +x "${TARGET_DIR}/scripts/"*.sh

# Copy references
if [[ -d "${SCRIPT_DIR}/references" ]] && ls "${SCRIPT_DIR}/references/"*.md &>/dev/null; then
  cp "${SCRIPT_DIR}/references/"*.md "${TARGET_DIR}/references/"
fi

echo "Installed to ${TARGET_DIR}"
echo ""
echo "Required environment variables:"
echo "  APCA_API_KEY_ID=your_api_key"
echo "  APCA_API_SECRET_KEY=your_api_secret"
echo "  APCA_PAPER=true  (default: paper trading)"
echo ""
echo "Restart Claude Code to activate the skill."
