FROM node:18-bullseye

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    vim \
    nano \
    python3 \
    python3-pip \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Create workspace directory
RUN mkdir -p /workspace
WORKDIR /workspace

# Install MCP server dependencies
COPY mcp-server/package.json /mcp-server/
WORKDIR /mcp-server
RUN npm install

# Copy MCP server code
COPY mcp-server/ /mcp-server/

# Set up git (these will be overridden by environment variables)
RUN git config --global user.name "Claude Dev" && \
    git config --global user.email "claude@dev.local"

# Expose MCP server port
EXPOSE 3000

# Start MCP server
CMD ["node", "/mcp-server/server.js"]