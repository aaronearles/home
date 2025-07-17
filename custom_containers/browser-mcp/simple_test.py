#!/usr/bin/env python3
"""
Simple MCP test for Puppeteer server
"""

import json
import subprocess

def test_mcp():
    # Initialize the server
    init_cmd = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "test-client", "version": "1.0.0"}
        }
    }
    
    # Send commands via subprocess
    docker_cmd = [
        "docker", "run", "-i", "--rm", "--init",
        "-e", "DOCKER_CONTAINER=true",
        "mcp/puppeteer"
    ]
    
    # Test initialization
    print("Testing MCP initialization...")
    result = subprocess.run(
        docker_cmd,
        input=json.dumps(init_cmd),
        text=True,
        capture_output=True
    )
    
    print(f"Return code: {result.returncode}")
    print(f"Output: {result.stdout}")
    print(f"Error: {result.stderr}")

if __name__ == "__main__":
    test_mcp()