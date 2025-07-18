# Multi-stage build for MCP Playwright server
FROM node:20-alpine AS builder

# Install build dependencies 
RUN apk add --no-cache \
    python3 \
    make \
    g++

# Set the working directory
WORKDIR /app

# Copy package files
COPY mcp-playwright/package.json mcp-playwright/package-lock.json ./

# Install dependencies without browser downloads
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
RUN npm ci --ignore-scripts

# Copy source code
COPY mcp-playwright/src ./src
COPY mcp-playwright/tsconfig.json ./

# Build the project
RUN npm run build

# Production stage - Use Ubuntu for better Playwright support
FROM node:20-slim AS runtime

# Install runtime dependencies for Playwright
RUN apt-get update && apt-get install -y \
    chromium \
    firefox-esr \
    fonts-liberation \
    fonts-noto-color-emoji \
    libnss3 \
    libatk-bridge2.0-0 \
    libdrm2 \
    libgtk-3-0 \
    libgbm1 \
    libasound2 \
    libxss1 \
    libxrandr2 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set playwright to use system browsers
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
ENV PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium
ENV PLAYWRIGHT_FIREFOX_EXECUTABLE_PATH=/usr/bin/firefox-esr

# Create non-root user for security
RUN groupadd -r mcpuser -g 1001 && \
    useradd -r -g mcpuser -u 1001 mcpuser

# Set working directory
WORKDIR /app

# Copy built files from builder stage
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/package-lock.json ./package-lock.json

# Copy HTTP MCP server and browser configuration
COPY mcp-http-server.js ./mcp-http-server.js
COPY browser-config.js ./browser-config.js
COPY toolHandler-patch.js ./toolHandler-patch.js
COPY playwright-override.js ./playwright-override.js

# Install production dependencies
RUN npm ci --ignore-scripts --omit=dev && \
    npm cache clean --force

# Change ownership to non-root user
RUN chown -R mcpuser:mcpuser /app

# Switch to non-root user
USER mcpuser

# Expose port for network access
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Set entrypoint
ENTRYPOINT ["node", "mcp-http-server.js"]