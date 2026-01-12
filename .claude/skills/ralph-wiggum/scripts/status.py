#!/usr/bin/env python3
"""
Display current progress for a Ralph Wiggum execution.

Usage:
    python3 status.py <change-id>
    python3 status.py add-browser-extension-ui

Shows:
- Overall progress across all sections
- Current section being worked on
- Next incomplete task
- Any blockers from progress.md
"""

import argparse
import json
import re
import sys
from pathlib import Path


def find_openspec_dir() -> Path:
    """Find the openspec directory by walking up from current directory."""
    current = Path.cwd()
    while current != current.parent:
        openspec_path = current / "openspec"
        if openspec_path.is_dir():
            return openspec_path
        current = current.parent
    raise FileNotFoundError("Could not find openspec directory")


def read_file_if_exists(path: Path) -> str | None:
    """Read file contents if it exists, otherwise return None."""
    if path.exists():
        return path.read_text(encoding="utf-8")
    return None


def parse_progress_md(content: str) -> dict:
    """Parse progress.md to extract last session info."""
    info = {"last_session": None, "completed_tasks": [], "blockers": [], "notes": []}

    # Find last session header
    session_matches = re.findall(
        r"## Session: (\d{4}-\d{2}-\d{2} \d{2}:\d{2})", content
    )
    if session_matches:
        info["last_session"] = session_matches[-1]

    # Find blockers section in latest session
    blocker_match = re.search(r"### Blockers\s*\n(.*?)(?=\n###|\Z)", content, re.DOTALL)
    if blocker_match:
        blocker_text = blocker_match.group(1).strip()
        if blocker_text.lower() != "none":
            blockers = re.findall(r"^[\-\*]\s+(.+)$", blocker_text, re.MULTILINE)
            info["blockers"] = blockers

    # Find notes for next session
    notes_match = re.search(
        r"### Notes for Next Session\s*\n(.*?)(?=\n##|\Z)", content, re.DOTALL
    )
    if notes_match:
        notes_text = notes_match.group(1).strip()
        notes = re.findall(r"^[\-\*]\s+(.+)$", notes_text, re.MULTILINE)
        info["notes"] = notes

    return info


def find_next_task(prd: dict) -> tuple[dict | None, dict | None]:
    """Find the next incomplete task and its section."""
    for section in prd.get("sections", []):
        for task in section.get("tasks", []):
            if not task.get("passes", False):
                return section, task
    return None, None


def find_current_section(prd: dict) -> dict | None:
    """Find the current section being worked on (has incomplete tasks)."""
    for section in prd.get("sections", []):
        incomplete = sum(
            1 for t in section.get("tasks", []) if not t.get("passes", False)
        )
        if incomplete > 0:
            return section
    return None


def display_status(change_id: str):
    """Display status for a change."""
    openspec_dir = find_openspec_dir()
    change_dir = openspec_dir / "changes" / change_id

    if not change_dir.is_dir():
        print(f"Error: Change directory not found: {change_dir}", file=sys.stderr)
        sys.exit(1)

    # Read PRD.json
    prd_path = change_dir / "prd.json"
    prd_content = read_file_if_exists(prd_path)

    if not prd_content:
        print(f"Change: {change_id}")
        print("Status: Not compiled (run /ralph-wiggum compile first)")
        return

    prd = json.loads(prd_content)
    summary = prd.get("summary", {})

    # Read progress.md
    progress_path = change_dir / "progress.md"
    progress_content = read_file_if_exists(progress_path)
    progress_info = parse_progress_md(progress_content) if progress_content else {}

    # Display header
    print(f"Change: {change_id}")
    print(
        f"Progress: {summary.get('completed_tasks', 0)}/{summary.get('total_tasks', 0)} tasks ({summary.get('progress_percent', 0)}%)"
    )
    print()

    # Section overview
    print("Sections:")
    for section in prd.get("sections", []):
        tasks = section.get("tasks", [])
        completed = sum(1 for t in tasks if t.get("passes", False))
        total = len(tasks)

        if completed == total:
            marker = "✓"
        elif completed > 0:
            marker = "◐"  # In progress
        else:
            marker = "○"

        print(
            f"  {marker} {section['number']}. {section['name']} ({completed}/{total})"
        )

    print()

    # Current section and next task
    current_section = find_current_section(prd)
    next_section, next_task = find_next_task(prd)

    if next_task:
        print(f"Next task: {next_task['id']} {next_task['description']}")
        print(f"Section: {next_section['number']}. {next_section['name']}")
    else:
        print("All tasks complete!")

    print()

    # Last activity
    if progress_info.get("last_session"):
        print(f"Last activity: {progress_info['last_session']}")
    elif prd.get("compiled_at"):
        compiled = prd["compiled_at"][:16].replace("T", " ")
        print(f"Compiled: {compiled}")

    # Blockers
    if progress_info.get("blockers"):
        print()
        print("⚠ Blockers:")
        for blocker in progress_info["blockers"]:
            print(f"  - {blocker}")

    # Notes
    if progress_info.get("notes"):
        print()
        print("Notes for next session:")
        for note in progress_info["notes"]:
            print(f"  - {note}")

    # Status summary
    print()
    if summary.get("completed_tasks", 0) == summary.get("total_tasks", 0):
        print("Status: ✓ All tasks complete")
    elif progress_info.get("blockers"):
        print("Status: ⚠ Blocked - needs attention")
    else:
        print("Status: Ready to continue")


def main():
    parser = argparse.ArgumentParser(
        description="Display current progress for a Ralph Wiggum execution"
    )
    parser.add_argument(
        "change_id", help="The change ID (e.g., add-browser-extension-ui)"
    )

    args = parser.parse_args()

    try:
        display_status(args.change_id)
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error parsing PRD.json: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
