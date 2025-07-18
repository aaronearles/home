# Browser Automation for Claude Code: Remote Setup Guide

## Overview

This guide provides comprehensive instructions for setting up browser automation capabilities for Claude Code on headless Docker hosts. The **recommended approach is now Stagehand/Browserbase**, which provides cloud-based browser automation specifically designed for Claude Code. Legacy Docker-based options are included for reference.

**⚠️ IMPORTANT UPDATE**: The official Puppeteer MCP server has been archived and is no longer maintained. Stagehand/Browserbase is now the recommended solution for browser automation with Claude Code.

## Table of Contents

1. [Recommended: Stagehand/Browserbase MCP](#option-1-stagehundbrowserbase-mcp-recommended)
2. [Legacy: Archived Puppeteer MCP](#option-2-archived-puppeteer-mcp-not-recommended)  
3. [Custom Selenium Setup](#option-3-custom-selenium-mcp-server)
4. [Playwright Alternative](#option-4-playwright-mcp-server)
5. [Implementation Details](#implementation-details)
6. [Integration Examples](#integration-with-fortinet-api-crawler)
7. [Troubleshooting](#troubleshooting)
8. [Configuration Examples](#configuration-examples)

## Option 1: Stagehand/Browserbase MCP (Recommended)

**AI-powered cloud browser automation designed specifically for Claude Code**

### Prerequisites
- Claude Code CLI installed
- Browserbase API key (sign up at browserbase.com)
- Anthropic API key for AI-powered actions

### Setup Steps

1. **Clone and Build Stagehand MCP Server**

   ```bash
   git clone https://github.com/browserbase/stagehand
   cd stagehand/mcp-server
   npm install
   npm run build
   ```

2. **Configure Claude Desktop MCP**

   Add the following to your `claude_desktop_config.json` file:

   ```json
   {
     "mcpServers": {
       "stagehand": {
         "command": "node",
         "args": ["path/to/stagehand/mcp-server/dist/index.js"],
         "env": {
           "BROWSERBASE_API_KEY": "your_browserbase_api_key",
           "ANTHROPIC_API_KEY": "your_anthropic_api_key"
         }
       }
     }
   }
   ```

3. **Project-specific Setup (Recommended)**

   Create `.mcp.json` in your project root:

   ```json
   {
     "mcpServers": {
       "stagehand": {
         "command": "node",
         "args": ["./stagehand-mcp/dist/index.js"],
         "env": {
           "BROWSERBASE_API_KEY": "your_browserbase_api_key",
           "ANTHROPIC_API_KEY": "your_anthropic_api_key"
         }
       }
     }
   }
   ```

### Benefits
- ✅ AI-powered browser interactions using natural language
- ✅ Cloud-based execution (no local Docker/Chrome needed)
- ✅ Built for Claude Code integration
- ✅ Automatic screenshot and logging capabilities
- ✅ Handles complex dynamic web applications
- ✅ No infrastructure management required
- ✅ Perfect for headless server deployment

### Capabilities
- **stagehand_navigate**: Navigate to URLs with intelligent waiting
- **stagehand_act**: Perform actions using natural language descriptions
- **stagehand_extract**: Extract structured data from web pages
- **stagehand_observe**: Identify available interactions on current page
- Advanced form filling and complex user workflows
- Dynamic content handling with AI-powered element detection

### Network Deployment for Headless Servers

For deploying Stagehand MCP on headless Docker hosts with Traefik:

1. **Create Docker Container for Stagehand MCP**

   ```dockerfile
   FROM node:20-alpine
   
   WORKDIR /app
   
   # Clone and build Stagehand MCP
   RUN apk add --no-cache git
   RUN git clone https://github.com/browserbase/stagehand.git .
   RUN cd mcp-server && npm install && npm run build
   
   # Create non-root user
   RUN adduser -D -s /bin/sh mcpuser
   USER mcpuser
   
   WORKDIR /app/mcp-server
   EXPOSE 3000
   
   CMD ["node", "dist/index.js"]
   ```

2. **Docker Compose Setup**

   ```yaml
   services:
     stagehand-mcp:
       build: .
       container_name: stagehand-mcp-server
       restart: unless-stopped
       environment:
         - BROWSERBASE_API_KEY=${BROWSERBASE_API_KEY}
         - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
         - PORT=3000
       networks:
         - traefik
       labels:
         - traefik.enable=true
         - traefik.docker.network=traefik
         - traefik.http.routers.stagehand.rule=Host(`browser.lab.earles.io`)
         - traefik.http.routers.stagehand.entrypoints=websecure
         - traefik.http.routers.stagehand.tls.certresolver=production
         - traefik.http.services.stagehand.loadbalancer.server.port=3000
   
   networks:
     traefik:
       external: true
   ```

3. **Environment Configuration**

   ```bash
   # .env file
   BROWSERBASE_API_KEY=your_browserbase_api_key_here
   ANTHROPIC_API_KEY=your_anthropic_api_key_here
   ```

4. **Claude Code Remote Configuration**

   ```json
   {
     "mcpServers": {
       "stagehand-remote": {
         "command": "curl",
         "args": [
           "-X", "POST",
           "-H", "Content-Type: application/json",
           "https://browser.lab.earles.io/mcp",
           "-d", "@-"
         ]
       }
     }
   }
   ```

## Option 2: Archived Puppeteer MCP (Not Recommended)

**⚠️ DEPRECATED: This option is archived and no longer maintained**

The official Puppeteer MCP server has been moved to the archived servers repository and is no longer receiving updates or security patches. **Do not use this option for new deployments.**

### Why It Was Archived
- Security vulnerabilities in outdated dependencies
- Maintenance burden of Docker-based browser automation
- Better cloud-based alternatives now available (Stagehand/Browserbase)
- Limited AI integration capabilities

### Migration Path
If you're currently using the Puppeteer MCP server, migrate to **Stagehand/Browserbase** for:
- Better reliability and performance
- AI-powered browser interactions
- No infrastructure management
- Active maintenance and support

## Option 3: Custom Selenium MCP Server

**More control and customization for specific needs**

### Custom Dockerfile

```dockerfile
# Dockerfile for Custom Selenium MCP Server
FROM selenium/standalone-chrome:4.34.0

# Switch to root to install dependencies
USER root

# Install Python and pip
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Create working directory
WORKDIR /app

# Copy requirements
COPY requirements.txt .

# Install Python dependencies
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy MCP server code
COPY mcp_selenium_server.py .
COPY config.json .

# Create non-root user for security
RUN useradd -m -u 1000 mcpuser && chown -R mcpuser:mcpuser /app
USER mcpuser

# Expose MCP server port
EXPOSE 8080

# Set environment variables
ENV DISPLAY=:99
ENV CHROME_BIN=/usr/bin/google-chrome
ENV CHROME_PATH=/usr/bin/google-chrome

# Start command
CMD ["python3", "mcp_selenium_server.py"]
```

### Requirements.txt

```txt
selenium==4.15.0
webdriver-manager==4.0.1
mcp==0.4.0
asyncio-mqtt==0.11.0
beautifulsoup4==4.12.2
requests==2.31.0
```

### Custom MCP Server Implementation

```python
#!/usr/bin/env python3
"""
Custom Selenium MCP Server for Claude Code
Provides browser automation capabilities through Selenium WebDriver
"""

import asyncio
import json
import logging
from typing import Any, Sequence
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from mcp.server import Server, NotificationOptions
from mcp.server.models import InitializationOptions
import mcp.server.stdio
import mcp.types as types

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("selenium-mcp-server")

class SeleniumMCPServer:
    def __init__(self):
        self.driver = None
        self.server = Server("selenium-mcp-server")
        
    def setup_chrome_driver(self):
        """Initialize Chrome WebDriver with headless configuration"""
        chrome_options = Options()
        
        # Essential options for Docker containers
        chrome_options.add_argument("--headless=new")  # Use new headless mode
        chrome_options.add_argument("--no-sandbox")
        chrome_options.add_argument("--disable-dev-shm-usage")
        chrome_options.add_argument("--disable-gpu")
        chrome_options.add_argument("--disable-extensions")
        chrome_options.add_argument("--disable-plugins")
        chrome_options.add_argument("--disable-images")
        chrome_options.add_argument("--disable-javascript")  # Enable if needed
        chrome_options.add_argument("--window-size=1920,1080")
        chrome_options.add_argument("--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
        
        # Memory and performance optimizations
        chrome_options.add_argument("--memory-pressure-off")
        chrome_options.add_argument("--max_old_space_size=4096")
        chrome_options.add_argument("--disable-background-timer-throttling")
        chrome_options.add_argument("--disable-renderer-backgrounding")
        
        try:
            self.driver = webdriver.Chrome(options=chrome_options)
            self.driver.set_page_load_timeout(30)
            logger.info("Chrome WebDriver initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize Chrome WebDriver: {e}")
            raise

    async def navigate_to_url(self, url: str) -> dict:
        """Navigate to a specific URL"""
        try:
            if not self.driver:
                self.setup_chrome_driver()
            
            self.driver.get(url)
            await asyncio.sleep(2)  # Wait for page to load
            
            return {
                "success": True,
                "url": self.driver.current_url,
                "title": self.driver.title,
                "message": f"Successfully navigated to {url}"
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "message": f"Failed to navigate to {url}"
            }

    async def take_screenshot(self, filename: str = "screenshot.png") -> dict:
        """Take a screenshot of the current page"""
        try:
            if not self.driver:
                return {"success": False, "error": "WebDriver not initialized"}
            
            screenshot_path = f"/tmp/{filename}"
            self.driver.save_screenshot(screenshot_path)
            
            return {
                "success": True,
                "screenshot_path": screenshot_path,
                "message": f"Screenshot saved to {screenshot_path}"
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "message": "Failed to take screenshot"
            }

    async def get_page_source(self) -> dict:
        """Get the current page's HTML source"""
        try:
            if not self.driver:
                return {"success": False, "error": "WebDriver not initialized"}
            
            return {
                "success": True,
                "page_source": self.driver.page_source,
                "url": self.driver.current_url,
                "title": self.driver.title
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "message": "Failed to get page source"
            }

    async def find_elements(self, selector: str, by_type: str = "css") -> dict:
        """Find elements on the page"""
        try:
            if not self.driver:
                return {"success": False, "error": "WebDriver not initialized"}
            
            by_map = {
                "css": By.CSS_SELECTOR,
                "xpath": By.XPATH,
                "id": By.ID,
                "class": By.CLASS_NAME,
                "tag": By.TAG_NAME
            }
            
            if by_type not in by_map:
                return {"success": False, "error": f"Invalid selector type: {by_type}"}
            
            elements = self.driver.find_elements(by_map[by_type], selector)
            
            return {
                "success": True,
                "count": len(elements),
                "elements": [
                    {
                        "text": elem.text,
                        "tag_name": elem.tag_name,
                        "attributes": elem.get_property("attributes")
                    } for elem in elements
                ]
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "message": f"Failed to find elements with selector: {selector}"
            }

    def cleanup(self):
        """Clean up WebDriver resources"""
        if self.driver:
            self.driver.quit()
            logger.info("WebDriver cleaned up")

# MCP Server setup and tool registration
selenium_server = SeleniumMCPServer()

@selenium_server.server.list_tools()
async def handle_list_tools() -> list[types.Tool]:
    """List available tools"""
    return [
        types.Tool(
            name="navigate_to_url",
            description="Navigate to a specific URL",
            inputSchema={
                "type": "object",
                "properties": {
                    "url": {
                        "type": "string",
                        "description": "The URL to navigate to"
                    }
                },
                "required": ["url"]
            }
        ),
        types.Tool(
            name="take_screenshot",
            description="Take a screenshot of the current page",
            inputSchema={
                "type": "object",
                "properties": {
                    "filename": {
                        "type": "string",
                        "description": "Filename for the screenshot (optional)",
                        "default": "screenshot.png"
                    }
                }
            }
        ),
        types.Tool(
            name="get_page_source",
            description="Get the HTML source of the current page",
            inputSchema={
                "type": "object",
                "properties": {}
            }
        ),
        types.Tool(
            name="find_elements",
            description="Find elements on the current page",
            inputSchema={
                "type": "object",
                "properties": {
                    "selector": {
                        "type": "string",
                        "description": "The selector to find elements"
                    },
                    "by_type": {
                        "type": "string",
                        "description": "Selector type (css, xpath, id, class, tag)",
                        "default": "css"
                    }
                },
                "required": ["selector"]
            }
        )
    ]

@selenium_server.server.call_tool()
async def handle_call_tool(name: str, arguments: dict | None) -> list[types.TextContent]:
    """Handle tool calls"""
    try:
        if name == "navigate_to_url":
            result = await selenium_server.navigate_to_url(arguments.get("url"))
        elif name == "take_screenshot":
            result = await selenium_server.take_screenshot(arguments.get("filename", "screenshot.png"))
        elif name == "get_page_source":
            result = await selenium_server.get_page_source()
        elif name == "find_elements":
            result = await selenium_server.find_elements(
                arguments.get("selector"),
                arguments.get("by_type", "css")
            )
        else:
            result = {"success": False, "error": f"Unknown tool: {name}"}
        
        return [types.TextContent(type="text", text=json.dumps(result, indent=2))]
    
    except Exception as e:
        error_result = {"success": False, "error": str(e)}
        return [types.TextContent(type="text", text=json.dumps(error_result, indent=2))]

async def main():
    """Main server function"""
    try:
        async with mcp.server.stdio.stdio_server() as (read_stream, write_stream):
            await selenium_server.server.run(
                read_stream,
                write_stream,
                InitializationOptions(
                    server_name="selenium-mcp-server",
                    server_version="1.0.0",
                    capabilities=selenium_server.server.get_capabilities(
                        notification_options=NotificationOptions(),
                        experimental_capabilities={}
                    )
                )
            )
    except KeyboardInterrupt:
        logger.info("Server interrupted")
    finally:
        selenium_server.cleanup()

if __name__ == "__main__":
    asyncio.run(main())
```

### Build and Run Commands

```bash
# Build the Docker image
docker build -t custom-selenium-mcp .

# Run the container
docker run -it --rm \
  --shm-size=2g \
  --cap-add=SYS_ADMIN \
  -p 8080:8080 \
  custom-selenium-mcp
```

## Option 4: Playwright MCP Server

**Modern browser automation with multi-browser support**

### Playwright Dockerfile

```dockerfile
FROM mcr.microsoft.com/playwright:v1.54.0-noble

# Install Python and dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements
COPY requirements-playwright.txt .
RUN pip3 install --no-cache-dir -r requirements-playwright.txt

# Install Playwright browsers
RUN playwright install

# Copy MCP server code
COPY mcp_playwright_server.py .

# Create non-root user
RUN useradd -m -u 1000 mcpuser && chown -R mcpuser:mcpuser /app
USER mcpuser

# Expose port
EXPOSE 8080

CMD ["python3", "mcp_playwright_server.py"]
```

### Playwright Requirements

```txt
playwright==1.54.0
mcp==0.4.0
asyncio==3.4.3
beautifulsoup4==4.12.2
```

## Implementation Details

### Docker Configuration Best Practices

#### Resource Limits
```bash
# Standard MCP resource limits
docker run \
  --memory=2g \
  --cpus=1.0 \
  --shm-size=2g \
  your-browser-mcp-server
```

#### Security Configuration
```bash
# Production security settings
docker run \
  --read-only \
  --tmpfs /tmp \
  --tmpfs /var/tmp \
  --cap-drop=ALL \
  --cap-add=SYS_ADMIN \
  --security-opt no-new-privileges \
  your-browser-mcp-server
```

#### Network Configuration
```bash
# Isolated network for MCP servers
docker network create mcp-network
docker run --network=mcp-network your-browser-mcp-server
```

### Claude Code Configuration

#### claude_desktop_config.json
```json
{
  "mcpServers": {
    "selenium-custom": {
      "command": "docker",
      "args": [
        "run",
        "-i",
        "--rm",
        "--init",
        "--shm-size=2g",
        "custom-selenium-mcp"
      ]
    },
    "playwright-custom": {
      "command": "docker",
      "args": [
        "run",
        "-i",
        "--rm",
        "--init",
        "--ipc=host",
        "custom-playwright-mcp"
      ]
    }
  }
}
```

#### Project .mcp.json
```json
{
  "mcpServers": {
    "browser-automation": {
      "command": "docker",
      "args": [
        "run",
        "-i",
        "--rm",
        "--init",
        "--shm-size=2g",
        "--volume", "${PWD}/screenshots:/app/screenshots",
        "custom-selenium-mcp"
      ]
    }
  }
}
```

## Integration with Fortinet API Crawler

### Enhanced Crawler Architecture

```python
"""
Enhanced Fortinet API Crawler with Browser Automation
Combines existing BeautifulSoup extraction with browser automation for JS-heavy pages
"""

import asyncio
from typing import Dict, Any
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
import requests
from bs4 import BeautifulSoup

class EnhancedFortinetCrawler:
    def __init__(self, use_browser: bool = False):
        self.use_browser = use_browser
        self.driver = None
        self.session = requests.Session()
        
    def setup_browser(self):
        """Initialize browser for JavaScript-heavy pages"""
        if self.use_browser and not self.driver:
            chrome_options = Options()
            chrome_options.add_argument("--headless=new")
            chrome_options.add_argument("--no-sandbox")
            chrome_options.add_argument("--disable-dev-shm-usage")
            self.driver = webdriver.Chrome(options=chrome_options)
    
    async def crawl_with_browser(self, url: str) -> str:
        """Use browser automation for dynamic content"""
        self.setup_browser()
        
        try:
            self.driver.get(url)
            await asyncio.sleep(3)  # Wait for JS to load
            
            # Wait for specific elements to load
            from selenium.webdriver.support.ui import WebDriverWait
            from selenium.webdriver.support import expected_conditions as EC
            from selenium.webdriver.common.by import By
            
            wait = WebDriverWait(self.driver, 10)
            wait.until(EC.presence_of_element_located((By.CLASS_NAME, "api-content")))
            
            return self.driver.page_source
        except Exception as e:
            print(f"Browser automation failed: {e}")
            return None
    
    async def extract_fortios_api_enhanced(self, api_type: str) -> Dict[str, Any]:
        """Enhanced FortiOS extraction with fallback to browser automation"""
        url = f"https://fndn.fortinet.net/fortiapi/1-fortios/7.2.11/{api_type}/"
        
        # Try traditional method first
        try:
            response = self.session.get(url)
            soup = BeautifulSoup(response.content, 'html.parser')
            
            # Check if content loaded properly
            main_content = soup.find('div', class_='ipsType_richText')
            if main_content and len(main_content.get_text().strip()) > 100:
                return self.process_traditional_extraction(soup, api_type)
        except Exception as e:
            print(f"Traditional extraction failed: {e}")
        
        # Fallback to browser automation
        print(f"Falling back to browser automation for {api_type}")
        html_content = await self.crawl_with_browser(url)
        
        if html_content:
            soup = BeautifulSoup(html_content, 'html.parser')
            return self.process_browser_extraction(soup, api_type)
        
        return {"error": "Both extraction methods failed"}
    
    def process_traditional_extraction(self, soup: BeautifulSoup, api_type: str) -> Dict[str, Any]:
        """Process content extracted via requests/BeautifulSoup"""
        # Existing extraction logic
        content_areas = [
            soup.find('div', class_='ipsType_richText'),
            soup.find('div', class_='ipsApp_content'),
            soup.find('main'),
            soup.find('article')
        ]
        
        extracted_content = []
        for area in content_areas:
            if area:
                # Remove navigation and unwanted elements
                for unwanted in area.find_all(['nav', 'script', 'style', 'aside']):
                    unwanted.decompose()
                
                text = area.get_text(separator='\n', strip=True)
                if text and len(text) > 50:
                    extracted_content.append(text)
        
        return {
            "method": "traditional",
            "api_type": api_type,
            "content": '\n\n'.join(extracted_content),
            "success": True
        }
    
    def process_browser_extraction(self, soup: BeautifulSoup, api_type: str) -> Dict[str, Any]:
        """Process content extracted via browser automation"""
        # Enhanced extraction for dynamically loaded content
        content_selectors = [
            '.api-documentation',
            '.endpoint-details',
            '.parameter-list',
            '.response-examples',
            '.ipsType_richText',
            '.main-content'
        ]
        
        extracted_content = []
        for selector in content_selectors:
            elements = soup.select(selector)
            for element in elements:
                text = element.get_text(separator='\n', strip=True)
                if text and len(text) > 50:
                    extracted_content.append(text)
        
        return {
            "method": "browser_automation",
            "api_type": api_type,
            "content": '\n\n'.join(extracted_content),
            "success": True
        }
    
    def cleanup(self):
        """Clean up resources"""
        if self.driver:
            self.driver.quit()
        self.session.close()

# Usage example
async def main():
    crawler = EnhancedFortinetCrawler(use_browser=True)
    
    try:
        # Extract FortiOS APIs with browser fallback
        for api_type in ['configuration', 'monitor', 'log']:
            result = await crawler.extract_fortios_api_enhanced(api_type)
            
            if result.get('success'):
                # Save to file
                filename = f"fortios_{api_type}_enhanced.md"
                with open(filename, 'w') as f:
                    f.write(f"# FortiOS {api_type.title()} API\n\n")
                    f.write(f"Extraction method: {result['method']}\n\n")
                    f.write(result['content'])
                
                print(f"Successfully extracted {api_type} API using {result['method']}")
            else:
                print(f"Failed to extract {api_type} API: {result.get('error')}")
    
    finally:
        crawler.cleanup()

if __name__ == "__main__":
    asyncio.run(main())
```

### Integration Benefits

1. **Fallback Strategy**: Try traditional extraction first, use browser automation for JS-heavy pages
2. **Dynamic Content**: Handle pages that load content via JavaScript
3. **Enhanced Debugging**: Screenshot capabilities for troubleshooting failed extractions
4. **Authentication Handling**: Browser automation can handle complex login flows
5. **Session Management**: Maintain authenticated sessions across multiple page requests

## Troubleshooting

### Common Issues and Solutions

#### 1. Chrome/Chromium Crashes in Docker
```bash
# Symptoms: Browser crashes with "unknown error: Chrome failed to start"
# Solution: Add proper flags and increase shared memory

docker run --shm-size=2g \
  --cap-add=SYS_ADMIN \
  your-container

# Additional Chrome flags:
--disable-dev-shm-usage
--no-sandbox
--disable-gpu
```

#### 2. MCP Server Connection Issues
```bash
# Debug MCP connections
claude --mcp-debug

# Check MCP server status
docker logs container-name

# Verify configuration
claude mcp list
```

#### 3. Memory Issues
```bash
# Monitor container resources
docker stats container-name

# Increase memory limits
docker run --memory=4g --shm-size=2g your-container
```

#### 4. Network Connectivity
```bash
# Test container network access
docker run --rm your-container curl -I https://fndn.fortinet.net

# Check DNS resolution
docker run --rm your-container nslookup fndn.fortinet.net
```

#### 5. Permission Issues
```bash
# Run with proper user permissions
docker run --user $(id -u):$(id -g) your-container

# Or create proper user in Dockerfile:
RUN useradd -m -u 1000 mcpuser
USER mcpuser
```

### Debug Commands

```bash
# Test Puppeteer MCP server
docker run -it --rm mcp/puppeteer --version

# Test custom Selenium server
docker run -it --rm custom-selenium-mcp python3 -c "import selenium; print(selenium.__version__)"

# Check Chrome installation
docker run -it --rm selenium/standalone-chrome:latest google-chrome --version

# Test MCP server directly
echo '{"method": "tools/list"}' | docker run -i --rm custom-selenium-mcp
```

## Configuration Examples

### Environment Variables

```bash
# Docker environment configuration
export DOCKER_BUILDKIT=1
export MCP_LOG_LEVEL=debug
export CHROME_BIN=/usr/bin/google-chrome
export DISPLAY=:99

# Security settings
export MCP_CONTAINER_MEMORY_LIMIT=2g
export MCP_CONTAINER_CPU_LIMIT=1.0
export MCP_ENABLE_SCREENSHOTS=true
```

### Docker Compose Setup

```yaml
# docker-compose.yml for browser automation stack
version: '3.8'

services:
  selenium-mcp:
    build: .
    container_name: selenium-mcp-server
    ports:
      - "8080:8080"
    environment:
      - DISPLAY=:99
      - CHROME_BIN=/usr/bin/google-chrome
    volumes:
      - ./screenshots:/app/screenshots
      - ./data:/app/data
    shm_size: 2g
    mem_limit: 2g
    cpus: 1.0
    cap_add:
      - SYS_ADMIN
    security_opt:
      - no-new-privileges:true
    restart: unless-stopped

  playwright-mcp:
    image: mcr.microsoft.com/playwright:v1.54.0-noble
    container_name: playwright-mcp-server
    ports:
      - "8081:8080"
    volumes:
      - ./playwright-server:/app
    command: python3 /app/mcp_playwright_server.py
    mem_limit: 2g
    cpus: 1.0
    restart: unless-stopped

networks:
  default:
    name: mcp-browser-network
```

### Production Deployment

```bash
#!/bin/bash
# deploy-browser-automation.sh

set -e

echo "Deploying Browser Automation MCP Servers..."

# Build images
docker build -t selenium-mcp:latest .
docker build -f Dockerfile.playwright -t playwright-mcp:latest .

# Create network
docker network create mcp-network 2>/dev/null || true

# Deploy Selenium MCP
docker run -d \
  --name selenium-mcp-server \
  --network mcp-network \
  --restart unless-stopped \
  --memory=2g \
  --cpus=1.0 \
  --shm-size=2g \
  --cap-add=SYS_ADMIN \
  --security-opt no-new-privileges \
  -v $(pwd)/screenshots:/app/screenshots \
  -v $(pwd)/logs:/app/logs \
  -e LOG_LEVEL=info \
  -e ENABLE_SCREENSHOTS=true \
  selenium-mcp:latest

# Deploy Playwright MCP
docker run -d \
  --name playwright-mcp-server \
  --network mcp-network \
  --restart unless-stopped \
  --memory=2g \
  --cpus=1.0 \
  --ipc=host \
  -v $(pwd)/playwright-data:/app/data \
  -e LOG_LEVEL=info \
  playwright-mcp:latest

echo "Browser automation MCP servers deployed successfully!"
echo "Configure Claude Code to use these servers in your .mcp.json file"
```

## Security Considerations

### Container Security
- Run containers with non-root users
- Use read-only filesystems where possible
- Implement proper resource limits
- Disable unnecessary capabilities
- Use security profiles (AppArmor/SELinux)

### Network Security
- Isolate MCP containers in dedicated networks
- Use firewalls to restrict outbound connections
- Monitor network traffic for suspicious activity
- Implement proper logging and auditing

### Data Protection
- Encrypt sensitive configuration data
- Use Docker secrets for API keys
- Implement proper backup strategies
- Monitor file system changes

## Next Steps

1. **Choose Your Approach**: Start with Puppeteer MCP for immediate results
2. **Test Integration**: Verify browser automation works with your Fortinet crawler
3. **Optimize Performance**: Tune Docker settings for your specific use case
4. **Scale Up**: Consider orchestration with Docker Swarm or Kubernetes
5. **Monitor**: Implement logging and monitoring for production deployments

## Additional Resources

- [Official MCP Documentation](https://modelcontextprotocol.io/)
- [Docker MCP Toolkit](https://docs.docker.com/ai/mcp-catalog-and-toolkit/toolkit/)
- [Selenium Docker Documentation](https://github.com/SeleniumHQ/docker-selenium)
- [Playwright Docker Guide](https://playwright.dev/docs/docker)
- [Claude Code MCP Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices)

This guide provides a comprehensive foundation for implementing browser automation with Claude Code. Start with the Puppeteer option for quick results, then consider custom implementations as your needs grow more sophisticated.