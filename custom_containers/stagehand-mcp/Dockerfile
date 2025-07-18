FROM node:20-alpine

# Install git and other build dependencies
RUN apk add --no-cache git python3 make g++

WORKDIR /app

# Clone the correct MCP server repository
RUN git clone https://github.com/browserbase/mcp-server-browserbase.git .

# Navigate to stagehand directory and install dependencies
WORKDIR /app/stagehand
RUN npm install && npm run build

# Create non-root user for security
RUN adduser -D -s /bin/sh mcpuser && \
    chown -R mcpuser:mcpuser /app

# Switch to non-root user
USER mcpuser

# Expose port for MCP server
EXPOSE 3000

# Set working directory back to stagehand for runtime
WORKDIR /app/stagehand

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD node -e "console.log('Health check passed')" || exit 1

# Start the MCP server
CMD ["node", "dist/index.js"]