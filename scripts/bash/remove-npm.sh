#!/usr/bin/env bash
# remove-npm.sh
# Removes Node.js and npm from the system.
# Supports: nvm, Homebrew (macOS), asdf, apt (Debian/Ubuntu), dnf (Fedora/RHEL)
#
# Safe to run after claude-migrate.sh — Claude Code's native binary
# has no dependency on Node.js.

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}║   Remove Node.js / npm                                       ║${RESET}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Guard: warn if npm-installed Claude Code is still present
if command -v claude &>/dev/null; then
  CLAUDE_PATH=$(which claude)
  if echo "$CLAUDE_PATH" | grep -qE 'npm|node_modules|\.npm|asdf'; then
    echo -e "${RED}  ✗ Claude Code still installed via npm at: $CLAUDE_PATH${RESET}"
    echo -e "${RED}    Run claude-migrate.sh first before removing Node.js.${RESET}"
    echo ""
    exit 1
  fi
fi

if ! command -v node &>/dev/null; then
  echo -e "  ${GREEN}✓ Node.js not found — nothing to remove${RESET}"
  echo ""
  exit 0
fi

NODE_VER=$(node --version 2>/dev/null || echo "unknown")
NODE_PATH=$(which node)
echo -e "  ${CYAN}Found: Node.js $NODE_VER at $NODE_PATH${RESET}"
echo ""

REMOVED=0

# ── nvm ──────────────────────────────────────────────────────────
if [[ -d "$HOME/.nvm" ]]; then
  echo -e "${BOLD}Removing nvm-managed Node.js...${RESET}"
  export NVM_DIR="$HOME/.nvm"
  # shellcheck disable=SC1091
  [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh" || true

  # Uninstall every version nvm knows about
  while IFS= read -r ver; do
    ver=$(echo "$ver" | tr -d ' *->')
    [[ -z "$ver" ]] && continue
    nvm uninstall "$ver" 2>/dev/null && echo -e "  ${GREEN}✓ nvm uninstalled node $ver${RESET}" || true
  done < <(nvm list --no-colors 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || true)

  nvm deactivate 2>/dev/null || true
  rm -rf "$HOME/.nvm"
  echo -e "  ${GREEN}✓ ~/.nvm removed${RESET}"

  # Strip nvm init lines from shell rc files
  for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.profile"; do
    [[ -f "$rc" ]] || continue
    cp "$rc" "${rc}.pre-remove-npm.bak"
    sed -i.tmp '/NVM_DIR/d; /nvm\.sh/d; /nvm\/bash_completion/d' "$rc" 2>/dev/null || true
    rm -f "${rc}.tmp"
    echo -e "  ${GREEN}✓ Removed nvm lines from $rc (backup: ${rc}.pre-remove-npm.bak)${RESET}"
  done

  REMOVED=1
fi

# ── Homebrew (macOS) ─────────────────────────────────────────────
if [[ $REMOVED -eq 0 ]] && command -v brew &>/dev/null; then
  if brew list node &>/dev/null 2>&1; then
    echo -e "${BOLD}Removing Homebrew Node.js...${RESET}"
    brew uninstall --ignore-dependencies node 2>/dev/null && \
      echo -e "  ${GREEN}✓ Homebrew node removed${RESET}" || true
    brew autoremove 2>/dev/null || true
    REMOVED=1
  fi
  # Also check node@xx formula variants
  for formula in $(brew list | grep '^node@' 2>/dev/null || true); do
    brew uninstall --ignore-dependencies "$formula" 2>/dev/null && \
      echo -e "  ${GREEN}✓ Homebrew $formula removed${RESET}" || true
    REMOVED=1
  done
fi

# ── asdf ─────────────────────────────────────────────────────────
if [[ $REMOVED -eq 0 ]] && command -v asdf &>/dev/null; then
  if asdf list nodejs &>/dev/null 2>&1; then
    echo -e "${BOLD}Removing asdf-managed Node.js versions...${RESET}"
    while IFS= read -r ver; do
      ver=$(echo "$ver" | tr -d ' *')
      [[ -z "$ver" ]] && continue
      asdf uninstall nodejs "$ver" 2>/dev/null && \
        echo -e "  ${GREEN}✓ asdf uninstalled nodejs $ver${RESET}" || true
    done < <(asdf list nodejs 2>/dev/null)
    asdf plugin remove nodejs 2>/dev/null && \
      echo -e "  ${GREEN}✓ asdf nodejs plugin removed${RESET}" || true
    REMOVED=1
  fi
fi

# ── apt (Debian / Ubuntu) ─────────────────────────────────────────
if [[ $REMOVED -eq 0 ]] && command -v apt-get &>/dev/null; then
  echo -e "${BOLD}Removing apt-installed Node.js/npm...${RESET}"
  sudo apt-get remove --purge -y nodejs npm 2>/dev/null && \
    echo -e "  ${GREEN}✓ nodejs and npm removed via apt${RESET}" || true
  sudo apt-get autoremove -y 2>/dev/null || true
  REMOVED=1
fi

# ── dnf (Fedora / RHEL / CentOS Stream) ──────────────────────────
if [[ $REMOVED -eq 0 ]] && command -v dnf &>/dev/null; then
  echo -e "${BOLD}Removing dnf-installed Node.js/npm...${RESET}"
  sudo dnf remove -y nodejs npm 2>/dev/null && \
    echo -e "  ${GREEN}✓ nodejs and npm removed via dnf${RESET}" || true
  REMOVED=1
fi

# ── Fallback ──────────────────────────────────────────────────────
if [[ $REMOVED -eq 0 ]]; then
  echo -e "${YELLOW}  ⚠ Could not detect install method for Node.js at: $NODE_PATH${RESET}"
  echo -e "${YELLOW}    Remove it manually based on how it was originally installed.${RESET}"
fi

# ── Clean up npm global cache ─────────────────────────────────────
echo ""
echo -e "${BOLD}Purging npm global cache...${RESET}"
if [[ -d "$HOME/.npm" ]]; then
  rm -rf "$HOME/.npm"
  echo -e "  ${GREEN}✓ ~/.npm removed${RESET}"
else
  echo -e "  ${GREEN}✓ ~/.npm not present — nothing to purge${RESET}"
fi

# ── Summary ───────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${RESET}"
if command -v node &>/dev/null; then
  echo -e "${BOLD}${YELLOW}  ⚠ node still found at: $(which node)${RESET}"
  echo -e "${YELLOW}    You may need to reload your shell: exec \$SHELL${RESET}"
else
  echo -e "${BOLD}${GREEN}  ✓ Node.js / npm removed${RESET}"
fi
echo -e "  ${CYAN}Reload shell to pick up PATH changes: exec \$SHELL${RESET}"
echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${RESET}"
echo ""
