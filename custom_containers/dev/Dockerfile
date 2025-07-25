FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set up user and workspace
ARG USERNAME=developer
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    sudo \
    openssh-client \
    vim \
    nano \
    tmux \
    htop \
    tree \
    jq \
    zip \
    locales \
    && rm -rf /var/lib/apt/lists/*

# Generate locales
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Install Node.js 20.x LTS
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs

# Install Docker CLI (for Docker-in-Docker scenarios)
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Install Terraform
RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update \
    && apt-get install -y terraform \
    && rm -rf /var/lib/apt/lists/*

# Install OpenTofu
RUN TOFU_VERSION="1.6.0" \
    && curl -fsSL "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_linux_amd64.zip" -o tofu.zip \
    && unzip tofu.zip \
    && mv tofu /usr/local/bin/tofu \
    && chmod +x /usr/local/bin/tofu \
    && rm tofu.zip

# Install Ansible
RUN python3 -m pip install --upgrade pip \
    && pip3 install --timeout=120 --retries=5 ansible-core \
    && pip3 install --timeout=120 --retries=5 ansible \
    && pip3 install --timeout=120 --retries=5 hvac requests jmespath netaddr

# Install VS Code Server (code-server)
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Install Node.js global packages (including Claude CLI)
RUN npm install -g \
    @anthropic-ai/claude-code \
    yarn \
    pm2 \
    @angular/cli \
    @vue/cli \
    create-react-app \
    typescript \
    ts-node \
    nodemon \
    eslint \
    prettier

# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip aws

# Install PowerShell
RUN curl -L https://github.com/PowerShell/PowerShell/releases/download/v7.4.0/powershell_7.4.0-1.deb_amd64.deb -o powershell.deb \
    && dpkg -i powershell.deb \
    && apt-get install -f -y \
    && rm powershell.deb

# Install Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
RUN curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list \
    && apt-get update \
    && apt-get install -y helm \
    && rm -rf /var/lib/apt/lists/*

# Install additional Python packages for development
RUN pip3 install --timeout=120 --retries=5 \
    black \
    flake8 \
    pytest \
    requests \
    pyyaml \
    jinja2 \
    paramiko \
    cryptography \
    linode-cli

# Create docker group and non-root user
RUN groupadd docker || true \
    && (groupadd --gid $USER_GID $USERNAME || groupadd $USERNAME) \
    && useradd --uid $USER_UID --gid $USERNAME -m $USERNAME \
    && usermod -aG docker $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Set up workspace directory
RUN mkdir -p /workspace \
    && chown -R $USERNAME:$USERNAME /workspace

# Install MCP server dependencies and setup
COPY mcp-server/package.json /tmp/mcp-server/
WORKDIR /tmp/mcp-server
RUN npm install
RUN mkdir -p /home/$USERNAME/mcp-server \
    && cp -r node_modules /home/$USERNAME/mcp-server/ \
    && chown -R $USERNAME:$USERNAME /home/$USERNAME/mcp-server

# Switch to non-root user
USER $USERNAME

# Copy MCP server files
COPY --chown=$USERNAME:$USERNAME mcp-server/ /home/$USERNAME/mcp-server/

# Set up user environment and npm configuration
RUN echo 'export PATH=$PATH:/home/$USERNAME/.local/bin' >> /home/$USERNAME/.bashrc \
    && echo 'alias ll="ls -la"' >> /home/$USERNAME/.bashrc \
    && echo 'alias k="kubectl"' >> /home/$USERNAME/.bashrc \
    && echo 'alias tf="terraform"' >> /home/$USERNAME/.bashrc \
    && echo 'alias tofu="tofu"' >> /home/$USERNAME/.bashrc \
    && echo 'alias linode="linode-cli"' >> /home/$USERNAME/.bashrc \
    && mkdir -p /home/$USERNAME/.npm-global \
    && npm config set prefix '/home/$USERNAME/.npm-global' \
    && echo 'export PATH=$PATH:/home/$USERNAME/.npm-global/bin' >> /home/$USERNAME/.bashrc


# Copy startup script
COPY start.sh /home/$USERNAME/start.sh
RUN sudo chmod +x /home/$USERNAME/start.sh

# Set working directory
WORKDIR /workspace

# Expose ports for VS Code Server and development servers
EXPOSE 8080 3000 4200 8000 9000

# Default command
CMD ["/home/developer/start.sh"]