#!/usr/bin/env python3
"""
Format Claude stream-json output into human-readable format.

Reads JSON lines from stdin and outputs formatted text showing:
- Tool calls (⏺ Read, Edit, Bash, etc.)
- Tool results (abbreviated)
- Assistant text responses
"""

import json
import signal
import sys
from typing import Any


def handle_signal(signum, frame):
    """Exit gracefully on interrupt signals."""
    sys.exit(0)


# Handle SIGINT (Ctrl+C) and SIGPIPE (broken pipe) gracefully
signal.signal(signal.SIGINT, handle_signal)
signal.signal(signal.SIGPIPE, signal.SIG_DFL)  # Default behavior: exit silently

# ANSI colors
DIM = "\033[2m"
CYAN = "\033[0;36m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
NC = "\033[0m"  # No color


def format_tool_input(name: str, input_data: dict) -> str:
    """Format tool input for display."""
    if name == "Read":
        return f'file_path: {input_data.get("file_path", "?")}'
    elif name == "Edit":
        path = input_data.get("file_path", "?")
        old = input_data.get("old_string", "")[:40]
        return f'{path} (replacing "{old}...")'
    elif name == "Write":
        path = input_data.get("file_path", "?")
        return f"file_path: {path}"
    elif name == "Bash":
        cmd = input_data.get("command", "?")[:60]
        return f'$ {cmd}'
    elif name == "Grep":
        pattern = input_data.get("pattern", "?")
        path = input_data.get("path", ".")
        return f'pattern: "{pattern}" in {path}'
    elif name == "Glob":
        pattern = input_data.get("pattern", "?")
        return f'pattern: {pattern}'
    elif name == "Task":
        desc = input_data.get("description", "?")
        agent = input_data.get("subagent_type", "?")
        return f'{agent}: {desc}'
    elif name == "TodoWrite":
        todos = input_data.get("todos", [])
        return f'{len(todos)} items'
    else:
        # Generic: show first few keys
        keys = list(input_data.keys())[:3]
        return ", ".join(f"{k}=..." for k in keys) if keys else ""


def process_line(line: str) -> None:
    """Process a single JSON line and print formatted output."""
    try:
        data = json.loads(line)
    except json.JSONDecodeError:
        # Not JSON, pass through
        print(line, end="")
        return

    msg_type = data.get("type")
    subtype = data.get("subtype")

    if msg_type == "assistant":
        message = data.get("message", {})
        content = message.get("content", [])

        for item in content:
            if item.get("type") == "tool_use":
                name = item.get("name", "?")
                input_data = item.get("input", {})
                formatted = format_tool_input(name, input_data)
                print(f"{CYAN}⏺ {name}({formatted}){NC}")
            elif item.get("type") == "text":
                text = item.get("text", "")
                # Print text content
                print(text)

    elif msg_type == "user":
        # Tool result - show abbreviated
        message = data.get("message", {})
        content = message.get("content", [])

        for item in content:
            if item.get("type") == "tool_result":
                result = item.get("content", "")
                if isinstance(result, str):
                    lines = result.split("\n")
                    if len(lines) > 5:
                        preview = "\n".join(lines[:3])
                        print(f"{DIM}  ⎿ {len(lines)} lines (showing 3):{NC}")
                        for line in lines[:3]:
                            print(f"{DIM}    {line[:80]}{NC}")
                    elif len(result) > 200:
                        print(f"{DIM}  ⎿ {result[:150]}...{NC}")

    elif msg_type == "result":
        # Final result
        if subtype == "success":
            duration = data.get("duration_ms", 0) / 1000
            cost = data.get("total_cost_usd", 0)
            print(f"\n{GREEN}✓ Complete in {duration:.1f}s (${cost:.4f}){NC}")
        elif subtype == "error":
            error = data.get("error", "Unknown error")
            print(f"\n{YELLOW}⚠ Error: {error}{NC}")

    elif msg_type == "system" and subtype == "init":
        # Session started
        model = data.get("model", "?")
        print(f"{DIM}Session started (model: {model}){NC}")


def main():
    """Main entry point."""
    try:
        for line in sys.stdin:
            line = line.rstrip("\n")
            if line:
                process_line(line)
                sys.stdout.flush()
    except (KeyboardInterrupt, BrokenPipeError):
        # Exit gracefully when interrupted or pipe closes
        pass


if __name__ == "__main__":
    main()
