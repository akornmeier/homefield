#!/usr/bin/env python3
"""
Compile OpenSpec change files into PRD.json format for Ralph Wiggum execution.

Usage:
    # Compile ALL sections
    python3 compile.py <change-id>
    python3 compile.py add-browser-extension-ui

    # Compile specific section(s) for targeted work
    python3 compile.py <change-id> --section 5
    python3 compile.py <change-id> --section 5-8

This script reads OpenSpec files (proposal.md, design.md, tasks.md) and generates
a PRD.json file for autonomous task execution.

Key features:
- Extracts component hierarchy from YAML blocks in design.md
- Parses mandatory constraints from Decision sections
- Extracts NuxtUI component requirements from task descriptions
- Auto-generates integration tasks based on component relationships
"""

import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path

# Optional YAML support - falls back to regex parsing if not available
try:
    import yaml

    HAS_YAML = True
except ImportError:
    HAS_YAML = False


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


def extract_context_from_proposal(proposal_content: str) -> str:
    """Extract the 'Why' section from proposal.md as context."""
    # Look for ## Why section
    why_match = re.search(r"## Why\s*\n(.*?)(?=\n## |\Z)", proposal_content, re.DOTALL)
    if why_match:
        return why_match.group(1).strip()

    # Fallback: first paragraph
    lines = [
        line.strip()
        for line in proposal_content.split("\n")
        if line.strip() and not line.startswith("#")
    ]
    return lines[0] if lines else "No context available"


# =============================================================================
# NEW: Component Hierarchy Extraction
# =============================================================================


def extract_component_hierarchy(design_content: str | None) -> dict:
    """
    Extract component hierarchy from YAML code block in design.md.

    Looks for a ```yaml block containing component_hierarchy key.
    Falls back to empty dict if not found.
    """
    if not design_content:
        return {}

    # Look for ```yaml ... ``` block
    yaml_match = re.search(r"```ya?ml\n(.*?)\n```", design_content, re.DOTALL)
    if not yaml_match:
        return {}

    yaml_content = yaml_match.group(1)

    if HAS_YAML:
        try:
            parsed = yaml.safe_load(yaml_content)
            if isinstance(parsed, dict):
                # If there's a component_hierarchy wrapper, unwrap it
                # Otherwise return the whole dict (components at top level)
                if "component_hierarchy" in parsed and len(parsed) == 1:
                    return parsed["component_hierarchy"]
                return parsed
        except yaml.YAMLError:
            pass

    # Fallback: basic regex parsing for component definitions
    hierarchy = {}
    # Match patterns like "ComponentName:" followed by indented content
    component_pattern = r"^(\w+):\s*\n((?:[ \t]+.*\n)*)"
    for match in re.finditer(component_pattern, yaml_content, re.MULTILINE):
        component_name = match.group(1)
        component_block = match.group(2)

        component_data = {}

        # Extract path
        path_match = re.search(r"path:\s*(.+)", component_block)
        if path_match:
            component_data["path"] = path_match.group(1).strip().strip("\"'")

        # Extract storybook
        storybook_match = re.search(r"storybook:\s*(.+)", component_block)
        if storybook_match:
            component_data["storybook"] = storybook_match.group(1).strip().strip("\"'")

        # Extract parent
        parent_match = re.search(r"parent:\s*(.+)", component_block)
        if parent_match:
            component_data["parent"] = parent_match.group(1).strip().strip("\"'")

        # Extract children (list format)
        children_match = re.search(
            r"children:\s*\n((?:[ \t]+-\s*.+\n)*)", component_block
        )
        if children_match:
            children_block = children_match.group(1)
            children = re.findall(r"-\s*(\w+)", children_block)
            if children:
                component_data["children"] = children

        # Extract integration
        integration_match = re.search(r"integration:\s*(.+)", component_block)
        if integration_match:
            component_data["integration"] = (
                integration_match.group(1).strip().strip("\"'")
            )

        if component_data:
            hierarchy[component_name] = component_data

    return hierarchy


# =============================================================================
# NEW: Constraint Extraction
# =============================================================================


def extract_constraints(design_content: str | None) -> dict:
    """
    Extract mandatory constraints from design.md Decision sections.

    Looks for key patterns indicating non-negotiable requirements.
    """
    constraints: dict = {"mandatory": [], "references": {}}

    if not design_content:
        # Default constraints when no design.md
        constraints["mandatory"] = [
            "Follow TDD: write failing test first, then implementation",
            "Commit after each completed task",
        ]
        return constraints

    # Check for NuxtUI-first constraint (Decision 6 pattern)
    if "non-negotiable" in design_content.lower() or "nuxtui-first" in design_content.lower():
        constraints["mandatory"].append(
            "Use NuxtUI components per Decision 6 component mapping - custom components only when no equivalent exists"
        )
        constraints["references"]["component_mapping"] = "design.md#decision-6"

    # Check for design tokens requirement
    if "--oculis-" in design_content or "design tokens" in design_content.lower():
        constraints["mandatory"].append(
            "All colors via --oculis-* CSS custom properties from tokens.css - never hardcoded hex values"
        )
        constraints["references"]["design_tokens"] = "src/assets/tokens.css"

    # Check for TooltipProvider requirement
    if "TooltipProvider" in design_content:
        constraints["mandatory"].append(
            "Wrap test/Storybook mounts with TooltipProvider for NuxtUI tooltip components"
        )

    # Check for Shadow DOM / CSS isolation
    if "shadow dom" in design_content.lower() or "css isolation" in design_content.lower():
        constraints["mandatory"].append(
            "Use Shadow DOM for panel components to prevent style leakage"
        )

    # Always add pattern-following constraint
    constraints["mandatory"].append(
        "Follow existing component patterns in the codebase before creating new approaches"
    )

    # Add design.md as general reference
    constraints["references"]["design_system"] = "design.md"

    return constraints


# =============================================================================
# NEW: NuxtUI Component Extraction from Task Descriptions
# =============================================================================


def extract_nuxtui_requirements(description: str) -> dict | None:
    """
    Extract NuxtUI component requirements from task description.

    Looks for patterns like:
    - "Use `UComponent`" or "use `UComponent`"
    - "— use `UComponent`"
    - Multiple components: "Use `UCard` for container - Use `UBadge` for indicator"

    Returns None if no NuxtUI requirements found.
    """
    # Find all UComponent references
    components = re.findall(r"`(U\w+)`", description)

    if components:
        # Remove duplicates while preserving order
        unique_components: list[str] = []
        seen: set[str] = set()
        for component in components:
            if component not in seen:
                seen.add(component)
                unique_components.append(component)
        return {"required": unique_components, "allowed_custom": False}

    # Check for explicit custom component allowance
    custom_indicators = [
        "custom",
        "no nuxtui",
        "no equivalent",
        "(custom)",
        "custom —",
    ]
    desc_lower = description.lower()
    for indicator in custom_indicators:
        if indicator in desc_lower:
            # Try to extract reason
            reason_match = re.search(r"\((custom[^)]*)\)", description, re.IGNORECASE)
            reason = reason_match.group(1) if reason_match else "No NuxtUI equivalent"
            return {"allowed_custom": True, "reason": reason}

    return None


def extract_design_tokens(description: str) -> list[str] | None:
    """
    Extract design token patterns that should be used for this task.

    Based on task description, infers which token families are relevant.
    """
    tokens = []
    desc_lower = description.lower()

    # Severity-related tasks
    if "severity" in desc_lower or "critical" in desc_lower or "serious" in desc_lower:
        tokens.append("--oculis-severity-*")

    # Background/surface tasks
    if any(word in desc_lower for word in ["card", "panel", "container", "background"]):
        tokens.append("--oculis-bg-*")

    # Text/typography tasks
    if any(word in desc_lower for word in ["text", "label", "title", "description"]):
        tokens.append("--oculis-text-*")

    # Border/outline tasks
    if any(word in desc_lower for word in ["border", "outline", "separator"]):
        tokens.append("--oculis-border")

    # Accent/interactive tasks
    if any(word in desc_lower for word in ["button", "link", "action", "hover", "focus"]):
        tokens.append("--oculis-accent")

    return tokens if tokens else None


# =============================================================================
# NEW: Integration Task Generation
# =============================================================================


def find_parent_component(section_name: str, hierarchy: dict) -> tuple[str, dict] | None:
    """
    Find the parent component for a section based on hierarchy.

    Normalizes section name (e.g., "Issues View" -> "IssuesView") and searches
    for it in component children lists.
    """
    # Normalize section name: "Issues View" -> "IssuesView"
    normalized = section_name.replace(" ", "")

    for component_name, config in hierarchy.items():
        children = config.get("children", [])
        if normalized in children:
            return (component_name, config)

    return None


def generate_integration_tasks(
    section: dict, hierarchy: dict, existing_task_count: int
) -> list[dict]:
    """
    Generate integration tasks when a section has a parent component.

    Creates tasks for:
    1. Integrating the component into its parent
    2. Updating parent's Storybook stories (if applicable)
    """
    tasks = []
    section_name = section["name"]
    normalized_name = section_name.replace(" ", "")

    parent_info = find_parent_component(section_name, hierarchy)
    if not parent_info:
        return tasks

    parent_name, parent_config = parent_info
    section_num = section["number"]

    # Integration task
    task_num = existing_task_count + 1
    integration_task: dict = {
        "id": f"{section_num}.{task_num}",
        "description": f"Integrate {normalized_name} into {parent_name}",
        "category": "integration",
        "auto_generated": True,
    }

    # Add files that need updating
    updates_required = []
    if parent_config.get("path"):
        updates_required.append(parent_config["path"])
    if parent_config.get("storybook"):
        updates_required.append(parent_config["storybook"])

    if updates_required:
        integration_task["updates_required"] = updates_required

    # Add integration mechanism hint if available
    if parent_config.get("integration"):
        integration_task["integration_mechanism"] = parent_config["integration"]

    tasks.append(integration_task)

    return tasks


# =============================================================================
# Task Extraction (Updated)
# =============================================================================


def extract_all_sections(
    tasks_content: str, hierarchy: dict
) -> list[dict]:
    """Extract all sections from tasks.md with component hierarchy awareness."""
    sections = []

    # Find all section headers: ## N. Section Name or ## N Section Name
    section_pattern = r"## (\d+)\.?\s+([^\n]+)\n(.*?)(?=\n## \d|\Z)"
    matches = re.findall(section_pattern, tasks_content, re.DOTALL)

    for section_num_str, section_name, section_content in matches:
        section_num = int(section_num_str)
        tasks = extract_tasks_from_section(section_num, section_content)

        section_data: dict = {
            "number": section_num,
            "name": section_name.strip(),
            "tasks": tasks,
        }

        # Add parent reference if found in hierarchy
        parent_info = find_parent_component(section_name.strip(), hierarchy)
        if parent_info:
            section_data["parent"] = parent_info[0]

        # Generate and append integration tasks
        integration_tasks = generate_integration_tasks(
            section_data, hierarchy, len(tasks)
        )
        if integration_tasks:
            section_data["tasks"].extend(integration_tasks)

        sections.append(section_data)

    return sections


def extract_tasks_from_section(section_num: int, section_content: str) -> list[dict]:
    """
    Extract tasks from a section's content.

    Now includes:
    - NuxtUI component requirements
    - Design token hints
    - Removes generic TDD steps (TDD is implicit via workflow.tdd_required)
    """
    # Extract tasks: - [ ] N.M Description or - [x] N.M Description
    task_pattern = rf"- \[([ x])\]\s+({section_num}\.\d+)\s+(.+?)(?=\n- \[|\n\n|\Z)"
    task_matches = re.findall(task_pattern, section_content, re.DOTALL)

    tasks = []
    for checked, task_id, description in task_matches:
        # Clean up description (remove any sub-bullets for now, keep first line)
        desc_lines = description.strip().split("\n")
        main_desc = desc_lines[0].strip()

        # Determine category from description
        category = categorize_task(main_desc)

        task_data: dict = {
            "id": task_id,
            "category": category,
            "description": main_desc,
            "passes": checked == "x",
        }

        # Extract NuxtUI requirements
        nuxtui = extract_nuxtui_requirements(main_desc)
        if nuxtui:
            task_data["nuxtui"] = nuxtui

        # Extract design token hints
        tokens = extract_design_tokens(main_desc)
        if tokens:
            task_data["tokens"] = tokens

        tasks.append(task_data)

    return tasks


def categorize_task(description: str) -> str:
    """Categorize task based on description."""
    desc_lower = description.lower()

    if any(word in desc_lower for word in ["test", "story", "storybook", "spec"]):
        return "testing"
    elif any(
        word in desc_lower for word in ["refactor", "clean", "reorganize", "rename"]
    ):
        return "refactor"
    elif any(word in desc_lower for word in ["integrate", "connect", "wire"]):
        return "integration"
    else:
        return "feature"


# =============================================================================
# PRD Compilation (Updated)
# =============================================================================


def parse_section_arg(section_arg: str) -> tuple[int, int]:
    """Parse section argument like '5' or '5-8' into (start, end) range."""
    if "-" in section_arg:
        parts = section_arg.split("-")
        return int(parts[0]), int(parts[1])
    else:
        num = int(section_arg)
        return num, num


def filter_sections(sections: list[dict], start: int, end: int) -> list[dict]:
    """Filter sections to only include those in the range [start, end]."""
    return [s for s in sections if start <= s["number"] <= end]


def compile_prd(change_id: str, section_range: tuple[int, int] | None = None) -> dict:
    """Compile OpenSpec files into PRD.json format with enhanced structure."""
    openspec_dir = find_openspec_dir()
    change_dir = openspec_dir / "changes" / change_id

    if not change_dir.is_dir():
        raise FileNotFoundError(f"Change directory not found: {change_dir}")

    # Read source files
    proposal = read_file_if_exists(change_dir / "proposal.md")
    design = read_file_if_exists(change_dir / "design.md")
    tasks = read_file_if_exists(change_dir / "tasks.md")

    if not proposal:
        raise FileNotFoundError(f"proposal.md not found in {change_dir}")
    if not tasks:
        raise FileNotFoundError(f"tasks.md not found in {change_dir}")

    # Extract components with new functions
    context = extract_context_from_proposal(proposal)
    constraints = extract_constraints(design)
    hierarchy = extract_component_hierarchy(design)
    all_sections = extract_all_sections(tasks, hierarchy)

    # Filter sections if range specified
    if section_range:
        sections = filter_sections(all_sections, section_range[0], section_range[1])
        if not sections:
            raise ValueError(
                f"No sections found in range {section_range[0]}-{section_range[1]}"
            )
    else:
        sections = all_sections

    # Calculate totals
    total_tasks = sum(len(s["tasks"]) for s in sections)
    completed_tasks = sum(sum(1 for t in s["tasks"] if t.get("passes")) for s in sections)

    # Build PRD with new structure
    prd: dict = {
        "change_id": change_id,
        "context": context,
        # NEW: Workflow section - TDD is implicit for all tasks
        "workflow": {
            "tdd_required": True,
            "commit_per_task": True,
            "note": "TDD workflow is mandatory for ALL tasks. Write failing test first, then implement. Do not include TDD steps in individual task descriptions.",
        },
        # NEW: Constraints section
        "constraints": constraints,
        # NEW: Component hierarchy (if available)
        "component_hierarchy": hierarchy if hierarchy else None,
        "sections": sections,
        "summary": {
            "total_sections": len(sections),
            "total_tasks": total_tasks,
            "completed_tasks": completed_tasks,
            "progress_percent": round(completed_tasks / total_tasks * 100, 1)
            if total_tasks > 0
            else 0,
        },
        "success_criteria": {"tests_pass": "pnpm test", "lint_clean": "pnpm lint"},
        "compiled_at": datetime.now().isoformat(),
    }

    # Remove None values for cleaner output, but always keep component_hierarchy key
    prd = {k: v for k, v in prd.items() if v is not None or k == "component_hierarchy"}

    # Add section range info if filtered
    if section_range:
        prd["section_range"] = {"start": section_range[0], "end": section_range[1]}

    return prd


def main():
    parser = argparse.ArgumentParser(
        description="Compile OpenSpec change files into PRD.json format"
    )
    parser.add_argument(
        "change_id", help="The change ID (e.g., add-browser-extension-ui)"
    )
    parser.add_argument(
        "--section", "-s", help="Section number or range (e.g., '5' or '5-8')"
    )
    parser.add_argument(
        "--output", "-o", help="Output file path (default: in change directory)"
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="Print PRD without writing file"
    )

    args = parser.parse_args()

    # Parse section argument if provided
    section_range = None
    if args.section:
        try:
            section_range = parse_section_arg(args.section)
        except ValueError:
            print(
                f"Error: Invalid section format '{args.section}'. Use '5' or '5-8'",
                file=sys.stderr,
            )
            sys.exit(1)

    try:
        prd = compile_prd(args.change_id, section_range)

        if args.dry_run:
            print(json.dumps(prd, indent=2))
            return

        # Write PRD.json
        openspec_dir = find_openspec_dir()
        change_dir = openspec_dir / "changes" / args.change_id

        output_path = Path(args.output) if args.output else change_dir / "prd.json"
        output_path.write_text(json.dumps(prd, indent=2), encoding="utf-8")

        summary = prd["summary"]
        section_info = ""
        if section_range:
            if section_range[0] == section_range[1]:
                section_info = f" (section {section_range[0]})"
            else:
                section_info = f" (sections {section_range[0]}-{section_range[1]})"

        print(f"✓ Compiled PRD for: {args.change_id}{section_info}")
        print(f"✓ {summary['total_sections']} sections, {summary['total_tasks']} tasks")
        print(
            f"✓ Progress: {summary['completed_tasks']}/{summary['total_tasks']} ({summary['progress_percent']}%)"
        )

        # Show new features used
        if prd.get("component_hierarchy"):
            print(f"✓ Component hierarchy loaded ({len(prd['component_hierarchy'])} components)")
        if prd.get("constraints", {}).get("mandatory"):
            print(f"✓ {len(prd['constraints']['mandatory'])} mandatory constraints")

        print(f"✓ Written to {output_path}")

        # Create progress.md if not exists
        progress_path = change_dir / "progress.md"
        if not progress_path.exists():
            progress_content = f"# Progress: {args.change_id}\n"
            progress_path.write_text(progress_content, encoding="utf-8")
            print(f"✓ Created {progress_path}")

    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
