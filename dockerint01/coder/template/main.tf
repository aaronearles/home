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

variable "anthropic_api_key" {
  description = "Anthropic API key (leave blank if ANTHROPIC_BASE_URL is set on the server)"
  default     = ""
  sensitive   = true
}

variable "foundry_base_url" {
  description = "Azure AI Foundry endpoint (optional)"
  default     = ""
}

variable "workspace_image" {
  description = "Workspace container image"
  default     = "codercom/enterprise-base:ubuntu"
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
    var.foundry_base_url  != "" ? { ANTHROPIC_BASE_URL = var.foundry_base_url  } : {},
    var.anthropic_api_key != "" ? { ANTHROPIC_API_KEY  = var.anthropic_api_key } : {}
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
    for ip in $(getent hosts "$CODER_HOST" 2>/dev/null | awk '{print $1}'); do
      sudo iptables -A OUTPUT -d "$ip" -j ACCEPT
    done

    # Allow Foundry or direct Anthropic API
    if [ -n "${ANTHROPIC_BASE_URL:-}" ]; then
      ANTHROPIC_HOST=$(echo "$ANTHROPIC_BASE_URL" | sed 's|https\?://||' | cut -d/ -f1)
    else
      ANTHROPIC_HOST="api.anthropic.com"
    fi
    for ip in $(getent hosts "$ANTHROPIC_HOST" 2>/dev/null | awk '{print $1}'); do
      sudo iptables -A OUTPUT -d "$ip" -j ACCEPT
    done

    # Allow npm + https for initial Claude Code install
    # TODO: remove these two lines once Claude Code is baked into a custom image
    sudo iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
    sudo iptables -A OUTPUT -p tcp --dport 80  -j ACCEPT

    # TODO: uncomment once Claude Code is pre-baked in image (removes npm dependency):
    # sudo iptables -P OUTPUT DROP

    # ── 3. Install Claude Code (idempotent) ───────────────────────────────────
    if ! command -v claude &>/dev/null; then
      npm install -g @anthropic-ai/claude-code
    else
      echo "Claude Code already installed: $(claude --version 2>/dev/null)"
    fi

    # ── 4. code-server (VS Code in browser) ───────────────────────────────────
    if ! command -v code-server &>/dev/null; then
      curl -fsSL https://code-server.dev/install.sh | sh -s -- --method standalone
    fi
    code-server --bind-addr 0.0.0.0:13337 --auth none &
    disown
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
  item { key = "image";         value = var.workspace_image }
  item { key = "home volume";   value = docker_volume.home.name }
  item { key = "egress policy"; value = "allowlist: Foundry + Coder only" }
}
