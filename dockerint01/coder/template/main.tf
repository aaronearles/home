terraform {
  required_providers {
    coder  = { source = "coder/coder" }
    docker = { source = "kreuzwerker/docker" }
  }
}

provider "coder"  {}
provider "docker" {}

data "coder_workspace"       "me" {}
data "coder_workspace_owner" "me" {}

# ── Variables ──────────────────────────────────────────────────────────────────

# Azure AI Foundry Configuration
variable "claude_code_use_foundry" {
  description = "Enable Azure AI Foundry mode for Claude Code (uses az login for authentication)"
  default     = ""
}

variable "anthropic_foundry_base_url" {
  description = "Azure AI Foundry base URL (authentication via az login)"
  default     = ""
}

# Model Configuration
variable "anthropic_default_sonnet_model" {
  description = "Default Sonnet model version"
  default     = ""
}

variable "anthropic_default_haiku_model" {
  description = "Default Haiku model version"
  default     = ""
}

variable "anthropic_default_opus_model" {
  description = "Default Opus model version"
  default     = ""
}

# Legacy variables (deprecated, use Foundry variables above)
variable "anthropic_api_key" {
  description = "Direct Anthropic API key (deprecated, use Foundry variables)"
  default     = ""
  sensitive   = true
}

variable "foundry_base_url" {
  description = "Legacy Foundry base URL (deprecated, use anthropic_foundry_base_url)"
  default     = ""
}

variable "workspace_image" {
  description = "Workspace container image (use custom image with Node.js + Claude Code pre-baked for faster startup and locked-down egress)"
  default     = "codercom/enterprise-base:ubuntu"
  # TODO: Build custom image with Dockerfile:
  #   FROM codercom/enterprise-base:ubuntu
  #   USER root
  #   RUN apt-get update \
  #       && apt-get install -y nano vim less jq wget ca-certificates gnupg \
  #       && curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
  #       && apt-get install -y nodejs \
  #       && curl -fsSL https://aka.ms/InstallAzureCLIDeb | bash \
  #       && npm install -g @anthropic-ai/claude-code \
  #       && chmod u-s /usr/bin/sudo /bin/su /usr/bin/su \
  #       && rm -rf /var/lib/apt/lists/*
  #   USER coder
  #   RUN curl -fsSL https://code-server.dev/install.sh | sh -s -- --method standalone \
  #       && ln -s ~/.local/bin/code-server ~/.local/bin/code \
  #       && echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
  # Then update default to: "your-registry/coder-claude:latest"
}

# ── Persistent home volume ─────────────────────────────────────────────────────

resource "docker_volume" "home" {
  name = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}-home"
  lifecycle { ignore_changes = all }
}

# ── Coder agent ────────────────────────────────────────────────────────────────

resource "coder_agent" "main" {
  arch = "amd64"
  os   = "linux"
  dir  = "/home/coder"

  display_apps {
    web_terminal    = true
    ssh_helper      = true
    vscode          = false
    vscode_insiders = false
  }

  env = merge(
    # Azure AI Foundry Configuration (auth via az login)
    var.claude_code_use_foundry != "" ? { CLAUDE_CODE_USE_FOUNDRY = var.claude_code_use_foundry } : {},
    var.anthropic_foundry_base_url != "" ? { ANTHROPIC_FOUNDRY_BASE_URL = var.anthropic_foundry_base_url } : {},

    # Model Configuration
    var.anthropic_default_sonnet_model != "" ? { ANTHROPIC_DEFAULT_SONNET_MODEL = var.anthropic_default_sonnet_model } : {},
    var.anthropic_default_haiku_model != "" ? { ANTHROPIC_DEFAULT_HAIKU_MODEL = var.anthropic_default_haiku_model } : {},
    var.anthropic_default_opus_model != "" ? { ANTHROPIC_DEFAULT_OPUS_MODEL = var.anthropic_default_opus_model } : {},

    # Legacy variables (for backwards compatibility)
    var.foundry_base_url != "" ? { ANTHROPIC_BASE_URL = var.foundry_base_url } : {},
    var.anthropic_api_key != "" ? { ANTHROPIC_API_KEY = var.anthropic_api_key } : {}
  )

  startup_script = <<-EOT
    #!/bin/bash
    set -euo pipefail

    # ── 1. managed-settings.json ──────────────────────────────────────────────
    # Deployed to /etc/claude-code/ — the Linux managed path.
    # Cannot be overridden by user or project settings.
    sudo mkdir -p /etc/claude-code
    sudo tee /etc/claude-code/managed-settings.json > /dev/null <<'SETTINGS'
    {
      "env": {
        "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": 1,
        "DISABLE_TELEMETRY": 1,
        "DISABLE_ERROR_REPORTING": 1
      },
      "cleanupPeriodDays": 7,
      "permissions": {
        "disableBypassPermissionsMode": "disable",
        "defaultMode": "default",
        "deny": [
          "Read(**/.env)",
          "Read(**/*.key)",
          "Read(**/*.pem)",
          "Read(**/*.pfx)",
          "Read(**/*.p12)",
          "Bash(sudo:*)",
          "Bash(su:*)",
          "Bash(curl:*)",
          "Bash(wget:*)",
          "Bash(ssh:*)",
          "Bash(nc:*)",
          "Bash(socat:*)",
          "WebFetch",
          "WebSearch"
        ],
        "ask": [
          "Bash(rm:*)",
          "Bash(git push:*)",
          "Bash(git commit:*)"
        ],
        "allow": [
          "Bash(git diff:*)",
          "Bash(git log:*)",
          "Bash(git status:*)",
          "Bash(git checkout:*)",
          "Bash(git branch:*)"
        ]
      }
    }
    SETTINGS
    sudo chmod 644 /etc/claude-code/managed-settings.json

    # ── 2. Egress firewall ────────────────────────────────────────────────────
    # Proxmox privileged LXC note: iptables rules set here manipulate the
    # LXC's network namespace (shared host kernel). This correctly isolates
    # per-workspace egress. NET_ADMIN capability is required (set in main.tf).

    sudo iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    sudo iptables -A OUTPUT -o lo -j ACCEPT
    sudo iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
    sudo iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

    # Allow Coder control plane (agent heartbeat)
    CODER_HOST=$(echo "$CODER_AGENT_URL" | sed 's|https\?://||' | cut -d/ -f1 | cut -d: -f1)
    for ip in $(getent ahostsv4 "$CODER_HOST" 2>/dev/null | awk '{print $1}' | sort -u); do
      sudo iptables -A OUTPUT -d "$ip" -j ACCEPT
    done

    # Allow Foundry or direct Anthropic API
    if [ -n "$${ANTHROPIC_BASE_URL:-}" ]; then
      ANTHROPIC_HOST=$(echo "$ANTHROPIC_BASE_URL" | sed 's|https\?://||' | cut -d/ -f1)
    else
      ANTHROPIC_HOST="api.anthropic.com"
    fi
    for ip in $(getent ahostsv4 "$ANTHROPIC_HOST" 2>/dev/null | awk '{print $1}' | sort -u); do
      sudo iptables -A OUTPUT -d "$ip" -j ACCEPT
    done

    # Allow npm + https for Node.js and Claude Code install
    # TODO: remove these two lines once Claude Code is baked into a custom image
    sudo iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
    sudo iptables -A OUTPUT -p tcp --dport 80  -j ACCEPT

    # TODO: uncomment once Claude Code is pre-baked in image (removes npm dependency):
    # sudo iptables -P OUTPUT DROP

    # ── 3. Install Node.js (if missing) ───────────────────────────────────────
    if ! command -v npm &>/dev/null; then
      curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
      sudo apt-get install -y nodejs
    fi

    # ── 4. Install Azure CLI (for Foundry authentication) ────────────────────
    if ! command -v az &>/dev/null; then
      curl -fsSL https://aka.ms/InstallAzureCLIDeb | sudo bash
      echo "Azure CLI installed. Run 'az login' to authenticate for Foundry access."
    fi

    # ── 5. Install essential tools (before sudo removal) ─────────────────────
    sudo apt-get update -qq
    sudo apt-get install -y -qq \
      nano \
      vim \
      less \
      jq \
      wget \
      ca-certificates \
      gnupg

    # ── 6. Install Claude Code (idempotent) ───────────────────────────────────
    if ! command -v claude &>/dev/null; then
      sudo npm install -g @anthropic-ai/claude-code
    else
      echo "Claude Code already installed: $(claude --version 2>/dev/null)"
    fi

    # ── 7. code-server (VS Code in browser) ───────────────────────────────────
    if [ ! -x "$HOME/.local/bin/code-server" ]; then
      curl -fsSL https://code-server.dev/install.sh | sh -s -- --method standalone
    fi

    # Symlink code-server to 'code' so Claude Code CLI can find it
    ln -sf "$HOME/.local/bin/code-server" "$HOME/.local/bin/code"

    # Add ~/.local/bin to PATH permanently
    if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc"; then
      echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    fi
    export PATH="$HOME/.local/bin:$PATH"

    # Install VS Code extensions
    echo "Installing VS Code extensions..."
    # GitHub extensions (from Open VSX)
    "$HOME/.local/bin/code-server" --install-extension github.vscode-pull-request-github 2>/dev/null || echo "GitHub PR extension not available in Open VSX"
    "$HOME/.local/bin/code-server" --install-extension eamodio.gitlens 2>/dev/null || echo "GitLens not available in Open VSX"

    # Claude Code extension - may not be in Open VSX, Claude Code CLI will try to install it
    "$HOME/.local/bin/code-server" --install-extension anthropic.claude-code 2>/dev/null || echo "Claude Code extension will be installed by Claude CLI on first run"

    # Start code-server in background with nohup for persistence
    mkdir -p "$HOME/.local/share/code-server"
    nohup "$HOME/.local/bin/code-server" \
      --bind-addr 0.0.0.0:13337 \
      --auth none \
      --disable-telemetry \
      --disable-update-check \
      "$HOME" \
      > "$HOME/.local/share/code-server/code-server.log" 2>&1 &

    echo "code-server started on port 13337 (PID: $!)"

    # ── 8. Remove sudo access ─────────────────────────────────────────────────
    # All setup is complete - remove sudo to prevent bypassing managed settings

    # Remove from sudo group
    sudo deluser coder sudo 2>/dev/null || true

    # Remove all sudoers configurations for coder user
    sudo rm -f /etc/sudoers.d/coder* 2>/dev/null || true
    sudo rm -f /etc/sudoers.d/90-cloud-init-users 2>/dev/null || true

    # Remove any coder entries from main sudoers file
    sudo sed -i '/^coder/d' /etc/sudoers 2>/dev/null || true

    # Most effective: remove setuid bit from sudo binary (prevents execution as root)
    sudo chmod u-s /usr/bin/sudo

    # Also remove setuid from su for completeness
    sudo chmod u-s /bin/su 2>/dev/null || true
    sudo chmod u-s /usr/bin/su 2>/dev/null || true

    echo "Workspace security hardened: sudo/su access fully disabled"
    echo "Managed settings enforced at /etc/claude-code/managed-settings.json"
  EOT
}

resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "VS Code"
  url          = "http://localhost:13337/?folder=/home/coder"
  icon         = "/icon/code.svg"
  subdomain    = false
  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 5
    threshold = 6
  }
}

resource "docker_container" "workspace" {
  count   = data.coder_workspace.me.start_count
  name    = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
  image   = var.workspace_image
  command = ["sh", "-c", coder_agent.main.init_script]
  env     = ["CODER_AGENT_TOKEN=${coder_agent.main.token}"]

  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home.name
    read_only      = false
  }

  user = "1000:1000"

  # NET_ADMIN + NET_RAW: required for iptables in startup_script.
  # In a Proxmox privileged LXC, containers can manipulate the LXC's
  # network namespace — these capabilities are available because the LXC
  # itself is privileged.
  capabilities {
    add = ["NET_ADMIN", "NET_RAW"]
  }

  network_mode = "bridge"
  must_run     = true
  rm           = false

  lifecycle {
    ignore_changes = [image, command]
  }
}

resource "coder_metadata" "container" {
  count       = data.coder_workspace.me.start_count
  resource_id = docker_container.workspace[0].id
  item {
    key   = "image"
    value = var.workspace_image
  }
  item {
    key   = "home volume"
    value = docker_volume.home.name
  }
  item {
    key   = "egress policy"
    value = "allowlist: Foundry + Coder only"
  }
}
