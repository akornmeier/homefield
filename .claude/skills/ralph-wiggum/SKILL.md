---
name: ralph-wiggum
description: Autonomous execution workflow integrating OpenSpec with Ralph Wiggum methodology. Use when implementing approved OpenSpec changes with longer autonomous runs - compiles OpenSpec files (proposal.md, design.md, tasks.md) into a PRD.json for iterative execution with progress tracking. Invoked via /ralph-wiggum compile, /ralph-wiggum run, /ralph-wiggum status, or /ralph-wiggum resume.
---

# Ralph Wiggum

Autonomous execution workflow that compiles OpenSpec planning documents into a simple PRD format for extended, unattended task completion.

## Workflow Overview

```
┌─────────────────────────────────────────────────────────────┐
│  OPENSPEC (Source of Truth - Human-Friendly)                │
│  proposal.md + design.md + tasks.md + spec deltas           │
└─────────────────────────────────────────────────────────────┘
                              ↓
                    /ralph-wiggum compile [change-id]
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  PRD.json (Execution Format - Agent-Friendly)               │
│  All sections and tasks in one file                         │
└─────────────────────────────────────────────────────────────┘
                              ↓
                    /ralph-wiggum run [change-id]
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  EXECUTION LOOP                                             │
│  Read prd.json + progress.md → Do next task → Append log    │
│  Repeat until stop condition                                │
└─────────────────────────────────────────────────────────────┘
```

## Commands

### /ralph-wiggum compile [change-id] [--section N or N-M]

Generate PRD.json from OpenSpec files. Compile all sections or target specific ones.

```bash
# Compile ALL sections (full change)
/ralph-wiggum compile add-browser-extension-ui

# Compile single section (shorter iteration target)
/ralph-wiggum compile add-browser-extension-ui --section 5

# Compile section range
/ralph-wiggum compile add-browser-extension-ui --section 5-8
```

**Process:**

1. Read `openspec/changes/[change-id]/proposal.md` for context
2. Read `openspec/changes/[change-id]/design.md` for requirements (if exists)
3. Read `openspec/changes/[change-id]/tasks.md` and extract sections
4. Generate `openspec/changes/[change-id]/prd.json`
5. Create empty `progress.md` if not exists

**Output:**

```
✓ Compiled PRD for: add-browser-extension-ui (section 5)
✓ 1 sections, 8 tasks
✓ Progress: 6/8 (75.0%)
✓ Written to openspec/changes/add-browser-extension-ui/prd.json
```

### /ralph-wiggum run [change-id] [--section N] [--max-iterations N]

Execute the autonomous loop using the ralph-wiggum.sh script.

```bash
# Run through full PRD
.claude/skills/ralph-wiggum/scripts/ralph-wiggum.sh add-browser-extension-ui

# Complete specific section only (stop when section done)
.claude/skills/ralph-wiggum/scripts/ralph-wiggum.sh add-browser-extension-ui --section 5

# With custom iteration limit (default: 10)
.claude/skills/ralph-wiggum/scripts/ralph-wiggum.sh add-browser-extension-ui --max-iterations 20

# Section + iteration limit
.claude/skills/ralph-wiggum/scripts/ralph-wiggum.sh add-browser-extension-ui -s 5 -m 20
```

**The loop:**

1. Load `prd.json` and `progress.md`
2. Build prompt from template with current state
3. If `--section` specified, inject focus instruction
4. Call Claude with the prompt
5. Claude completes ONE task (test → implement → commit)
6. Claude updates `prd.json` and `progress.md`
7. Check for stop signals or section completion
8. Repeat until signal, section complete, or max iterations

### /ralph-wiggum status [change-id]

Display current progress summary.

```
/ralph-wiggum status add-browser-extension-ui
```

**Output:**

```
Change: add-browser-extension-ui
Progress: 35/108 tasks (32.4%)

Sections:
  ✓ 1. Design System Foundation (6/6)
  ✓ 2. Core Component Architecture (5/5)
  ◐ 5. Panel Component (6/8)
  ○ 6. Issues View (0/9)
  ...

Next task: 5.7 Implement panel expand/collapse animations
Section: 5. Panel Component

Status: Ready to continue
```

### /ralph-wiggum resume [change-id]

Continue from where the previous session stopped.

```
/ralph-wiggum resume add-browser-extension-ui
```

Reads `progress.md` to restore context before continuing execution.

## PRD.json Format

```json
{
  "change_id": "add-browser-extension-ui",
  "context": "Why this change exists...",
  "requirements": ["TDD", "Commit per task", "..."],
  "sections": [
    {
      "number": 5,
      "name": "Panel Component",
      "tasks": [
        {
          "id": "5.7",
          "category": "feature",
          "description": "Implement panel expand/collapse animations",
          "steps": ["Write test", "Implement", "Verify"],
          "passes": false
        }
      ]
    }
  ],
  "summary": {
    "total_sections": 16,
    "total_tasks": 108,
    "completed_tasks": 35,
    "progress_percent": 32.4
  },
  "success_criteria": {
    "tests_pass": "pnpm test",
    "lint_clean": "pnpm lint"
  }
}
```

## progress.md Format

Append-only log preserving context across sessions.

```markdown
# Progress: [change-id]

## Session: YYYY-MM-DD HH:MM

### Completed

- [x] 5.7 Implement panel expand/collapse animations

### Decisions

- Used motion-vue AnimatePresence for exit animations

### Blockers

- None

### Files Changed

- src/components/OculisPanel.vue
- src/composables/usePanel.ts

### Notes for Next Session

- Ready for 5.8 Storybook stories
```

## Stop Conditions

Halt execution and signal when:

| Condition             | Signal                  | Action                       |
| --------------------- | ----------------------- | ---------------------------- |
| All tasks complete    | `SECTION_COMPLETE`      | Create PR                    |
| Tests failing 3x      | `BLOCKED:TESTS`         | Log error, wait for human    |
| Ambiguous requirement | `BLOCKED:CLARIFICATION` | Log question, wait for human |
| 10 iterations reached | `PAUSED:LIMIT`          | Log progress, wait for human |

## Execution Discipline

### Commit Per Task (Mandatory)

Every completed task gets its own commit immediately:

```bash
git add .
git commit -m "type(scope): description [task-id]"
```

Example: `git commit -m "feat(browser): add panel animations [5.7]"`

Frequent commits allow recovery if something breaks and provide clear history.

### PR Per Section (Mandatory)

When ALL tasks in a section have `"passes": true`:

1. Push your branch
2. Create PR with title: `[change-id] Section N: Section Name`
3. Signal `SECTION_COMPLETE` and wait for review

```bash
git push -u origin feat/add-browser-extension-ui
gh pr create --title "[add-browser-extension-ui] Section 5: Panel Component" --body "..."
```

### Task Prioritization

When choosing the next task, prioritize:

1. **Architectural decisions and core abstractions** - Foundation work
2. **Integration points between modules** - Failures cascade
3. **Unknown unknowns and spike work** - Risky/unclear work
4. **Standard features** - Regular implementation
5. **Polish and quick wins** - Easy tasks last

**Fail fast on risky work. Save easy wins for later.**

### TDD Workflow

1. Write failing test first
2. Implement minimal code to pass
3. Refactor if needed
4. Never skip tests

### CI Green Rule

- Run `pnpm test` after each implementation
- Run `pnpm lint` before committing
- If tests fail 3x, stop and log blocker

### Progress Logging

- Append to `progress.md` after each task
- Include: completed tasks, decisions, blockers, files changed
- Keep entries concise (5-10 lines per session)

## Scripts

### scripts/ralph-wiggum.sh

The main execution loop. Repeatedly calls Claude with the PRD until completion or stop condition.

```bash
# Basic usage
.claude/skills/ralph-wiggum/scripts/ralph-wiggum.sh add-browser-extension-ui

# With custom iteration limit
.claude/skills/ralph-wiggum/scripts/ralph-wiggum.sh add-browser-extension-ui --max-iterations 20
```

**What it does:**

1. Loads PRD.json and progress.md
2. Builds prompt from template with current state
3. Calls `claude --print` with the prompt
4. Checks output for stop signals
5. Repeats until signal or max iterations

**Stop signals it watches for:**

- `TASK_COMPLETE` - Continue to next iteration
- `SECTION_COMPLETE` - Stop, create PR
- `ALL_TASKS_COMPLETE` - Stop, all done
- `BLOCKED:TESTS` - Stop, needs human help
- `BLOCKED:CLARIFICATION` - Stop, needs clarification

### scripts/prompt.md

The prompt template fed to Claude on each iteration. Contains placeholders:

- `{{CHANGE_ID}}` - The change being worked on
- `{{PRD_JSON}}` - Current PRD contents
- `{{PROGRESS_MD}}` - Current progress log

### scripts/compile.py

Compiles OpenSpec files into PRD.json format.

```bash
python3 .claude/skills/ralph-wiggum/scripts/compile.py [change-id]
python3 .claude/skills/ralph-wiggum/scripts/compile.py [change-id] --dry-run
```

### scripts/status.py

Displays current progress for a change.

```bash
python3 .claude/skills/ralph-wiggum/scripts/status.py [change-id]
```
