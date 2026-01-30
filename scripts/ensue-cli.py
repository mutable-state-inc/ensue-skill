#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# dependencies = [
#   "mcp>=1.0",
#   "click",
#   "rich",
# ]
# ///
"""
Ensue CLI - Command line interface for the Ensue Memory Network.

This self-contained script uses PEP 723 inline metadata for dependency management.
It auto-installs pipx if missing and uses it to manage dependencies.

Run: ./ensue-cli.py --help
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
import concurrent.futures
import json
from contextlib import asynccontextmanager
from typing import Any

import click
from mcp import ClientSession
from mcp.client.streamable_http import streamablehttp_client
from rich.console import Console
from rich.json import JSON

console = Console()

# ============================================================================
# MCP Client
# ============================================================================

DEFAULT_URL = "https://api.ensue-network.ai/"


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
# CLI Helpers
# ============================================================================


def run_async(coro):
    """Run async coroutine, handling nested event loops."""
    try:
        asyncio.get_running_loop()
    except RuntimeError:
        return asyncio.run(coro)
    # If there's already a running loop, create a new one in a thread
    with concurrent.futures.ThreadPoolExecutor() as pool:
        return pool.submit(asyncio.run, coro).result()


def get_config():
    """Get API configuration from environment, with .ensue-key fallback."""
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
            token = skill_key_file.read_text().strip()

    if not token:
        console.print("[red]Error:[/red] ENSUE_API_KEY or ENSUE_TOKEN environment variable required, "
                       "or place key in .ensue-key file")
        sys.exit(1)

    return url, token


def print_result(result):
    """Print MCP result with rich JSON formatting."""
    if hasattr(result, "content"):
        for item in result.content:
            if hasattr(item, "text"):
                try:
                    console.print(JSON(item.text))
                except Exception:
                    console.print(item.text)
    else:
        console.print(JSON(json.dumps(result, indent=2)))


# ============================================================================
# Dynamic Click CLI
# ============================================================================

TYPE_MAP = {
    "integer": click.INT,
    "number": click.FLOAT,
    "boolean": click.BOOL,
}


def parse_arg(value, schema_type):
    """Parse a CLI argument, handling JSON for complex types."""
    if schema_type in ("array", "object") and isinstance(value, str):
        try:
            return json.loads(value)
        except json.JSONDecodeError:
            pass
    return value


def build_command(tool):
    """Build a Click command from an MCP tool definition."""
    schema = tool.get("inputSchema", {})
    props = schema.get("properties", {})
    required = set(schema.get("required", []))

    params = [
        click.Option(
            [f"--{name.replace('_', '-')}"],
            type=TYPE_MAP.get(p.get("type"), click.STRING),
            required=name in required,
            help=p.get("description", ""),
        )
        for name, p in props.items()
    ]

    def callback(**kwargs):
        url, token = get_config()
        args = {
            k.replace("-", "_"): parse_arg(v, props.get(k.replace("-", "_"), {}).get("type"))
            for k, v in kwargs.items()
            if v is not None
        }
        result = run_async(call_tool(url, token, tool["name"], args))
        print_result(result)

    return click.Command(
        name=tool["name"],
        callback=callback,
        params=params,
        help=tool.get("description", ""),
    )


class MCPToolsCLI(click.Group):
    """CLI that loads commands dynamically from MCP server."""

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self._tools = None

    @property
    def tools(self):
        if self._tools is None:
            url, token = get_config()
            self._tools = {t["name"]: t for t in run_async(list_tools(url, token))}
        return self._tools

    def list_commands(self, ctx):
        try:
            return sorted(self.tools.keys())
        except Exception as e:
            console.print("[red]Connection error:[/red] Could not connect to MCP server")
            console.print(f"[dim]{e}[/dim]")
            return []

    def get_command(self, ctx, name):
        if name not in self.tools:
            return None
        return build_command(self.tools[name])


@click.group(cls=MCPToolsCLI)
@click.version_option()
def main():
    """Ensue Memory CLI - A distributed memory network for AI agents.

    Commands are loaded dynamically from the MCP server.
    Set ENSUE_API_KEY or save a file to .ensue-key that contains just the key to authenticate.
    """


if __name__ == "__main__":
    main()
