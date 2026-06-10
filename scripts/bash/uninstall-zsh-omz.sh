#!/usr/bin/env bash
# Uninstall oh-my-zsh and zsh on Debian, restoring bash as the default shell.
# Safe to run as a regular user (will sudo when needed).
# Tested on Debian 12 with zsh 5.9 + oh-my-zsh.

set -euo pipefail

###############################################################################
# helpers
###############################################################################

info()  { printf '\033[1;34m[info]\033[0m  %s\n' "$*"; }
ok()    { printf '\033[1;32m[ ok ]\033[0m  %s\n' "$*"; }
warn()  { printf '\033[1;33m[warn]\033[0m  %s\n' "$*"; }
die()   { printf '\033[1;31m[err ]\033[0m  %s\n' "$*" >&2; exit 1; }

confirm() {
    local prompt="$1"
    read -r -p "$prompt [y/N] " reply
    [[ "${reply,,}" == "y" ]]
}

###############################################################################
# preflight
###############################################################################

if [[ "$EUID" -eq 0 ]]; then
    die "Run this as your regular user, not root. It will sudo when needed."
fi

TARGET_USER="${1:-$USER}"
TARGET_HOME="$(eval echo "~$TARGET_USER")"

info "Uninstalling zsh + oh-my-zsh for user: $TARGET_USER (home: $TARGET_HOME)"
echo

###############################################################################
# 1. restore default shell to bash
###############################################################################

CURRENT_SHELL="$(getent passwd "$TARGET_USER" | cut -d: -f7)"
BASH_PATH="$(command -v bash)"

if [[ "$CURRENT_SHELL" == *zsh* ]]; then
    info "Changing default shell from $CURRENT_SHELL to $BASH_PATH ..."
    sudo chsh -s "$BASH_PATH" "$TARGET_USER"
    ok "Default shell changed to $BASH_PATH"
else
    ok "Default shell is already $CURRENT_SHELL — skipping chsh"
fi

###############################################################################
# 2. run oh-my-zsh's own uninstall script (if present)
###############################################################################

OMZ_DIR="${ZSH:-$TARGET_HOME/.oh-my-zsh}"

if [[ -d "$OMZ_DIR" ]]; then
    if [[ -f "$OMZ_DIR/tools/uninstall.sh" ]]; then
        info "Running oh-my-zsh uninstall script from $OMZ_DIR ..."
        # The upstream script is interactive; env vars suppress its prompts.
        env ZSH="$OMZ_DIR" bash "$OMZ_DIR/tools/uninstall.sh" || true
        ok "oh-my-zsh uninstall script finished"
    fi

    # Remove whatever remains
    if [[ -d "$OMZ_DIR" ]]; then
        info "Removing leftover oh-my-zsh directory: $OMZ_DIR"
        rm -rf "$OMZ_DIR"
        ok "Removed $OMZ_DIR"
    fi
else
    ok "No oh-my-zsh directory found — skipping"
fi

###############################################################################
# 3. restore pre-oh-my-zsh .zshrc (if it exists) or remove zsh dotfiles
###############################################################################

PRE_OMZ="$TARGET_HOME/.zshrc.pre-oh-my-zsh"
ZSHRC="$TARGET_HOME/.zshrc"

if [[ -f "$PRE_OMZ" ]]; then
    info "Restoring $PRE_OMZ → $ZSHRC"
    mv "$PRE_OMZ" "$ZSHRC"
    ok "Restored pre-oh-my-zsh .zshrc"
fi

# Offer to remove remaining zsh config files
ZSH_FILES=()
for f in \
    "$TARGET_HOME/.zshrc" \
    "$TARGET_HOME/.zshrc~" \
    "$TARGET_HOME/.zshrc.bck" \
    "$TARGET_HOME/.zshrc.pre-remove-npm.bak" \
    "$TARGET_HOME/.zsh_history" \
    "$TARGET_HOME/.zsh_sessions" \
    "$TARGET_HOME/.zshenv" \
    "$TARGET_HOME/.zprofile" \
    "$TARGET_HOME/.zlogin" \
    "$TARGET_HOME/.zlogout" \
    "$TARGET_HOME/.config/zsh"; do
    [[ -e "$f" ]] && ZSH_FILES+=("$f")
done

if [[ ${#ZSH_FILES[@]} -gt 0 ]]; then
    echo
    warn "The following zsh config files remain:"
    for f in "${ZSH_FILES[@]}"; do printf '    %s\n' "$f"; done
    echo
    if confirm "Delete all of the above?"; then
        for f in "${ZSH_FILES[@]}"; do
            rm -rf "$f"
            ok "Removed $f"
        done
    else
        warn "Skipped — files left in place"
    fi
fi

###############################################################################
# 4. remove zsh package
###############################################################################

if dpkg -s zsh &>/dev/null 2>&1; then
    echo
    if confirm "Remove the zsh package (apt purge zsh)?"; then
        sudo apt-get purge -y zsh
        ok "zsh package removed"

        # Show what autoremove would clean up and ask before proceeding.
        AUTOREMOVE_LIST="$(apt-get --dry-run autoremove 2>/dev/null \
            | awk '/^Remv /{print "    "$2}' | sort)"
        if [[ -n "$AUTOREMOVE_LIST" ]]; then
            echo
            warn "apt autoremove would also remove these orphaned packages:"
            echo "$AUTOREMOVE_LIST"
            echo
            if confirm "Run apt autoremove to remove the above?"; then
                sudo apt-get autoremove -y
                ok "Orphaned packages removed"
            else
                warn "Skipped autoremove — orphaned packages left in place"
            fi
        else
            ok "No orphaned packages to remove"
        fi
    else
        warn "Skipped apt removal — zsh binary is still installed"
    fi
else
    ok "zsh package not found in dpkg — nothing to purge"
fi

###############################################################################
# done
###############################################################################

echo
ok "All done. Open a new terminal (or run: exec bash) to use bash."
