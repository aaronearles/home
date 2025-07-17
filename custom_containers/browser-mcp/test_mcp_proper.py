#!/usr/bin/env python3
"""
Proper MCP test following the initialization sequence
"""

import json
import subprocess
import sys
import time

def run_docker_interactive():
    """Run docker container in interactive mode and test step by step"""
    
    print("🔧 Starting Puppeteer MCP Server...")
    
    # Start the docker container
    proc = subprocess.Popen([
        "docker", "run", "-i", "--rm", "--init",
        "-e", "DOCKER_CONTAINER=true",
        "mcp/puppeteer"
    ], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    
    try:
        # Step 1: Initialize
        init_msg = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "test-client", "version": "1.0.0"}
            }
        }
        
        print("📤 Sending initialize message...")
        proc.stdin.write(json.dumps(init_msg) + '\n')
        proc.stdin.flush()
        
        # Read response
        response = proc.stdout.readline()
        print(f"📥 Initialize response: {response.strip()}")
        
        # Step 2: Send initialized notification
        initialized_msg = {
            "jsonrpc": "2.0",
            "method": "notifications/initialized"
        }
        
        print("📤 Sending initialized notification...")
        proc.stdin.write(json.dumps(initialized_msg) + '\n')
        proc.stdin.flush()
        
        # Step 3: List tools
        tools_msg = {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/list"
        }
        
        print("📤 Requesting tools list...")
        proc.stdin.write(json.dumps(tools_msg) + '\n')
        proc.stdin.flush()
        
        # Read response
        response = proc.stdout.readline()
        print(f"📥 Tools response: {response.strip()}")
        
        if response:
            tools_data = json.loads(response.strip())
            if "result" in tools_data and "tools" in tools_data["result"]:
                tools = [tool["name"] for tool in tools_data["result"]["tools"]]
                print(f"✅ Available tools: {', '.join(tools)}")
                
                # Step 4: Test navigation
                nav_msg = {
                    "jsonrpc": "2.0",
                    "id": 3,
                    "method": "tools/call",
                    "params": {
                        "name": "puppeteer_navigate",
                        "arguments": {
                            "url": "https://httpbin.org/html"
                        }
                    }
                }
                
                print("📤 Testing navigation...")
                proc.stdin.write(json.dumps(nav_msg) + '\n')
                proc.stdin.flush()
                
                response = proc.stdout.readline()
                print(f"📥 Navigation response: {response.strip()}")
                
                return True
    
    except Exception as e:
        print(f"❌ Error: {e}")
        return False
    
    finally:
        proc.terminate()
        proc.wait()

if __name__ == "__main__":
    success = run_docker_interactive()
    print(f"\n{'🎉 Test completed successfully!' if success else '❌ Test failed'}")
    sys.exit(0 if success else 1)