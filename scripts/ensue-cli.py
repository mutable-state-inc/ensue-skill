#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# dependencies = [
#   "mcp>=1.0",
# ]
# ///
"""
Ensue CLI - Command line interface for the Ensue Memory Network.

This self-contained script uses PEP 723 inline metadata for dependency management.
It auto-installs pipx if missing and uses it to manage dependencies.

Run: ./ensue-cli.py <command> '<json_args>'

Example:
    ./ensue-cli.py list_keys '{"limit":5}'
"""

import os
import subprocess
import sys
from pathlib import Path


def ensure_pipx():
    """Ensure pipx zipapp is available, download if missing."""
    script_dir = Path(__file__).parent
    pipx_pyz = script_dir / "pipx.pyz"

    # Check if pipx.pyz exists locally
    if pipx_pyz.exists():
        return str(pipx_pyz)

    # Download pipx standalone zipapp
    print("Downloading pipx standalone zipapp...", file=sys.stderr)
    try:
        import urllib.request
        url = "https://github.com/pypa/pipx/releases/latest/download/pipx.pyz"
        urllib.request.urlretrieve(url, pipx_pyz)
        pipx_pyz.chmod(0o755)
        return str(pipx_pyz)
    except Exception as e:
        print(f"Failed to download pipx: {e}", file=sys.stderr)
        print("Trying with curl...", file=sys.stderr)
        try:
            subprocess.run(
                ["curl", "-LsSf", url, "-o", str(pipx_pyz)],
                check=True,
                capture_output=True
            )
            pipx_pyz.chmod(0o755)
            return str(pipx_pyz)
        except Exception as e2:
            print(f"Failed to download pipx with curl: {e2}", file=sys.stderr)
            sys.exit(1)


def main_wrapper():
    """Wrapper that ensures pipx is available and re-executes with it."""
    # If we're already running via pipx, skip the wrapper
    if os.environ.get("PIPX_RUNNING"):
        return False

    pipx_pyz = ensure_pipx()
    script_path = Path(__file__).resolve()
    script_dir = script_path.parent

    # Re-execute with pipx run using isolated PIPX_HOME
    env = os.environ.copy()
    env["PIPX_RUNNING"] = "1"
    env["PIPX_HOME"] = str(script_dir / ".pipx")

    cmd = [sys.executable, pipx_pyz, "run", str(script_path)] + sys.argv[1:]

    result = subprocess.run(cmd, env=env)
    sys.exit(result.returncode)


# Run wrapper first (will re-exec if needed)
if not os.environ.get("PIPX_RUNNING"):
    main_wrapper()

# ============================================================================
# Main script starts here (runs under pipx with dependencies available)
# ============================================================================

import asyncio
import json
from contextlib import asynccontextmanager
from typing import Any

from mcp import ClientSession
from mcp.client.streamable_http import streamablehttp_client


# ============================================================================
# MCP Client (embedded from ensue-cli/ensue_cli/client.py)
# ============================================================================

@asynccontextmanager
async def create_session(url: str, token: str):
    """Create an MCP client session connected to the Ensue service."""
    headers = {"Authorization": f"Bearer {token}"}
    async with streamablehttp_client(url, headers=headers) as (read_stream, write_stream, _):
        async with ClientSession(read_stream, write_stream) as session:
            await session.initialize()
            yield session


async def list_tools(url: str, token: str) -> list[dict[str, Any]]:
    """Fetch the list of available tools from the MCP server."""
    async with create_session(url, token) as session:
        result = await session.list_tools()
        return [
            {
                "name": tool.name,
                "description": tool.description,
                "inputSchema": tool.inputSchema,
            }
            for tool in result.tools
        ]


async def call_tool(url: str, token: str, name: str, arguments: dict[str, Any]) -> Any:
    """Call a tool on the MCP server."""
    async with create_session(url, token) as session:
        result = await session.call_tool(name, arguments)
        return result


# ============================================================================
# CLI Implementation
# ============================================================================

DEFAULT_URL = "https://api.ensue-network.ai/"


def get_config():
    """Get API configuration from environment."""
    url = os.environ.get("ENSUE_URL", DEFAULT_URL)
    token = os.environ.get("ENSUE_API_KEY") or os.environ.get("ENSUE_TOKEN")

    if not token:
        # Try reading from .ensue-key file (fallback for subagents)
        script_dir = Path(__file__).parent
        repo_root = script_dir.parent
        plugin_key_file = repo_root / ".claude-plugin" / ".ensue-key"
        skill_key_file = repo_root / ".ensue-key"
        if plugin_key_file.exists():
            token = plugin_key_file.read_text().strip()
        if skill_key_file.exists():
            token = skil_key_file.read_text().strip()

    if not token:
        print(json.dumps({"error": f"ENSUE_API_KEY or ENSUE_TOKEN env var not set, and {plugin_key_file} and {skill_key_file}"}), file=sys.stderr)
        sys.exit(1)

    return url, token


def format_result(result):
    """Format MCP result as JSON string for output."""
    if hasattr(result, "content"):
        # MCP response object - extract text content
        for item in result.content:
            if hasattr(item, "text"):
                # Return the text content (should be JSON from server)
                return item.text
    # Fallback to JSON serialization
    return json.dumps(result, default=str)


async def main_async():
    """Main async entry point."""
    if len(sys.argv) < 2:
        print(json.dumps({
            "error": "Usage: ensue-cli.py <command> [json_args]",
            "example": "./ensue-cli.py list_keys '{\"limit\":5}'"
        }), file=sys.stderr)
        sys.exit(1)

    command = sys.argv[1]
    args_str = sys.argv[2] if len(sys.argv) > 2 else "{}"

    # Parse JSON arguments
    try:
        arguments = json.loads(args_str)
    except json.JSONDecodeError as e:
        print(json.dumps({
            "error": f"Invalid JSON arguments: {e}",
            "received": args_str
        }), file=sys.stderr)
        sys.exit(1)

    # Get configuration
    try:
        url, token = get_config()
    except SystemExit:
        raise
    except Exception as e:
        print(json.dumps({"error": f"Configuration error: {e}"}), file=sys.stderr)
        sys.exit(1)

    # Call the tool
    try:
        result = await call_tool(url, token, command, arguments)
        output = format_result(result)
        print(output)
    except Exception as e:
        print(json.dumps({
            "error": str(e),
            "command": command,
            "arguments": arguments
        }), file=sys.stderr)
        sys.exit(1)


def main():
    """Main entry point."""
    asyncio.run(main_async())


if __name__ == "__main__":
    main()
