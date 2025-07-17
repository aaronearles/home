#!/usr/bin/env python3
"""
Test script for Browser MCP Server
Tests basic browser automation functionality
"""

import json
import subprocess
import sys

def run_mcp_command(method, params):
    """Run an MCP command via Docker"""
    command = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": method,
        "params": params
    }
    
    cmd = [
        "docker", "run", "-i", "--rm", "--init",
        "-e", "DOCKER_CONTAINER=true",
        "mcp/puppeteer"
    ]
    
    try:
        result = subprocess.run(
            cmd,
            input=json.dumps(command),
            text=True,
            capture_output=True,
            timeout=30
        )
        
        if result.returncode == 0:
            # Handle multi-line output, get the JSON response line
            lines = result.stdout.strip().split('\n')
            for line in lines:
                if line.startswith('{"'):
                    return json.loads(line)
            return {"error": f"No JSON response found in output: {result.stdout}"}
        else:
            return {"error": f"Command failed: {result.stderr}"}
    except subprocess.TimeoutExpired:
        return {"error": "Command timed out"}
    except Exception as e:
        return {"error": f"Exception: {str(e)}"}

def test_browser_automation():
    """Test browser automation capabilities"""
    print("Testing Browser MCP Server...")
    
    # Test 1: List available tools
    print("\n1. Testing tools list...")
    result = run_mcp_command("tools/list", {})
    if "result" in result and "tools" in result["result"]:
        tools = [tool["name"] for tool in result["result"]["tools"]]
        print(f"✅ Available tools: {', '.join(tools)}")
    else:
        print(f"❌ Failed to list tools: {result}")
        return False
    
    # Test 2: Navigate to a test page
    print("\n2. Testing navigation...")
    nav_result = run_mcp_command("tools/call", {
        "name": "puppeteer_navigate",
        "arguments": {
            "url": "https://httpbin.org/html",
            "allowDangerous": True
        }
    })
    
    if "result" in nav_result:
        print("✅ Successfully navigated to test page")
    else:
        print(f"❌ Navigation failed: {nav_result}")
        return False
    
    # Test 3: Take a screenshot
    print("\n3. Testing screenshot...")
    screenshot_result = run_mcp_command("tools/call", {
        "name": "puppeteer_screenshot",
        "arguments": {
            "name": "test_page",
            "width": 800,
            "height": 600
        }
    })
    
    if "result" in screenshot_result:
        print("✅ Successfully took screenshot")
    else:
        print(f"❌ Screenshot failed: {screenshot_result}")
    
    # Test 4: Execute JavaScript
    print("\n4. Testing JavaScript execution...")
    js_result = run_mcp_command("tools/call", {
        "name": "puppeteer_evaluate",
        "arguments": {
            "script": "document.title"
        }
    })
    
    if "result" in js_result:
        print("✅ Successfully executed JavaScript")
    else:
        print(f"❌ JavaScript execution failed: {js_result}")
    
    print("\n🎉 Browser automation testing completed!")
    return True

if __name__ == "__main__":
    success = test_browser_automation()
    sys.exit(0 if success else 1)