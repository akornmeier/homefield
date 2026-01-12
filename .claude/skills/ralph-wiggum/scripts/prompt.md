# Ralph Wiggum Iteration

You are executing an autonomous development loop. Complete ONE task, then stop.

## Change: {{CHANGE_ID}}

## PRD (Product Requirements Document)

```json
{{PRD_JSON}}
```

## Progress Log

```markdown
{{PROGRESS_MD}}
```

## Accumulated Learnings

**Before starting, scan the Progress Log above for `### Learnings` sections.** These contain patterns discovered in previous sessions that may be relevant to your current task.

Key areas to look for:

- NuxtUI component patterns (especially `$el` access, slot usage)
- Vitest selector patterns for this codebase
- Project-specific conventions that differ from defaults
- Workarounds for known issues

If you encounter a similar situation, apply the documented pattern rather than re-discovering it.

## Your Mission

1. **Read the PRD** - Find incomplete tasks where `"passes": false`
2. **Prioritize intelligently** - Choose the next task using the priority order below
3. **Read progress.md** - Understand what was tried before, any blockers or decisions
4. **Complete ONE task** - Follow TDD: test first, implement, verify
5. **Commit your work** - ONE COMMIT PER TASK (mandatory)
6. **Update files**:
   - Update `prd.json`: set the completed task's `"passes": true`
   - Append to `progress.md` with this session's work
7. **Check for section completion** - If all tasks in current section pass, create PR
8. **Output signal** - End your response with the appropriate signal

## Task Prioritization

When choosing the next task, prioritize in this order:

1. **Architectural decisions and core abstractions** - Foundation work that other tasks depend on
2. **Integration points between modules** - Where components connect; failures here cascade
3. **Unknown unknowns and spike work** - Risky or unclear work that needs investigation
4. **Standard features and implementation** - Regular feature work with clear requirements
5. **Polish, cleanup, and quick wins** - Easy tasks that don't block other work

**Fail fast on risky work. Save easy wins for later.**

If a high-priority task is blocked, document the blocker and move to the next available task in priority order.

## Critical Rules

### ONE COMMIT PER TASK (Mandatory)

Every completed task MUST have its own commit:

```
git add .
git commit -m "type(scope): description [task-id]"
```

Example: `git commit -m "feat(browser): add panel animations [5.7]"`

This is non-negotiable. Frequent commits allow recovery if something breaks.

### PR PER SECTION (Mandatory)

When ALL tasks in a section have `"passes": true`:

1. Push your branch
2. Read `.claude/skills/ralph-wiggum/scripts/ralph-quotes.txt` and pick a random quote
3. Create a PR with title: `[Change] Section N: Section Name`
4. Include "Ralph says: {quote}" at the end of the PR body
5. Signal `SECTION_COMPLETE`

Example:

```bash
git push -u origin feat/add-browser-extension-ui
gh pr create --title "[add-browser-extension-ui] Section 5: Panel Component" --body "$(cat <<'EOF'
## Summary
- Implemented panel expand/collapse animations
- Added resize handle functionality
- Created Storybook stories for panel states

## Test plan
- [ ] Verify panel animations are smooth
- [ ] Test resize handles on all edges

Ralph says: "Me fail English? That's unpossible!"
EOF
)"
```

### TDD Discipline

- Write failing test FIRST
- Implement minimal code to pass
- Run `pnpm test` to verify
- Run `pnpm lint` before committing
- Enforce a 120 second timeout for tests

### Test Commands (Important)

**Always run the full test suite** - do NOT try to filter or optimize test runs:

```bash
# CORRECT - run all tests
pnpm test

# CORRECT - run specific test type if needed
pnpm test:unit
pnpm test:browser
pnpm test:storybook
```

**DO NOT use these patterns** - they cause hangs or errors:

```bash
# WRONG - --grep does not exist in vitest
pnpm test:storybook --grep "ComponentName"

# WRONG - piping test output through grep can cause buffering hangs
pnpm test:storybook 2>&1 | grep "pattern"

# WRONG - -t filter doesn't work well with Storybook addon
pnpm test:storybook -t "ComponentName"
```

**Why filtering doesn't work for Storybook tests:**
- The `@storybook/addon-vitest` plugin discovers tests through Storybook config, not vitest patterns
- Test names are story names (e.g., "Default", "Loading"), not component names
- Filtering by component name skips all tests, wasting time without verification

**If tests are slow**, just let them run. The full suite takes ~20-30 seconds which is acceptable.

## Progress Logging

After completing a task, append to progress.md:

```markdown
## Session: YYYY-MM-DD HH:MM

### Completed

- [x] Task ID and description

### Decisions

- Why you chose this approach

### Blockers

- None (or describe issues)

### Files Changed

- List of files modified

### Learnings

Document anything that took longer than expected, required investigation, or revealed a pattern:

**Category**: [NuxtUI | Vitest | Vue | TypeScript | Project Convention | Tooling | Other]
**Problem**: What was harder than expected?
**Solution**: What approach worked?
**Pattern**: Reusable insight for future tasks

Example:
- **Category**: NuxtUI
- **Problem**: Couldn't access underlying DOM element for focus management
- **Solution**: Use `component.$el` after mounting, or `ref` with `defineExpose`
- **Pattern**: NuxtUI components wrap native elements; use `$el` or exposed refs for DOM access

If nothing notable, write "No significant learnings this session."

### Notes for Next Session

- What comes next
```

## Self-Reflection Protocol

Before finalizing progress.md, ask yourself:

1. **What surprised me?** - Anything that didn't work as expected?
2. **What did I have to look up or investigate?** - APIs, patterns, workarounds?
3. **What would I do differently?** - If starting over, what approach would be better?
4. **What pattern emerged?** - Is there a reusable insight here?

Focus on capturing knowledge that would help a future session (or a different developer) avoid the same friction. Be specific - include code snippets, selector patterns, or API usage that wasn't obvious.

### Learning Categories

When documenting learnings, use these categories:

| Category               | Examples                                                                    |
| ---------------------- | --------------------------------------------------------------------------- |
| **NuxtUI**             | Component APIs, slot patterns, `$el` access, theming, form handling         |
| **Vitest**             | Selector patterns, async testing, mocking, browser vs unit test differences |
| **Vue**                | Reactivity gotchas, lifecycle timing, template ref patterns, composables    |
| **TypeScript**         | Type inference issues, generic patterns, module resolution                  |
| **Project Convention** | File naming, component structure, test organization, import patterns        |
| **Tooling**            | Storybook setup, build issues, linting rules, pnpm workspace quirks         |
| **Testing Patterns**   | Accessibility testing, interaction testing, snapshot strategies             |

## Stop Signals

End your response with ONE of these signals:

- `TASK_COMPLETE` - You completed one task, ready for next iteration
- `SECTION_COMPLETE` - All tasks in current section done, PR created
- `ALL_TASKS_COMPLETE` - Every task in the PRD passes
- `BLOCKED:TESTS` - Tests failing after 3 attempts, need human help
- `BLOCKED:CLARIFICATION` - Requirement is ambiguous, need human input

## Checklist Before Signaling

Before outputting your signal, verify:

- [ ] Task implementation complete
- [ ] Tests pass (`pnpm test`)
- [ ] Lint passes (`pnpm lint`)
- [ ] Changes committed (one commit for this task)
- [ ] `prd.json` updated (`"passes": true` for completed task)
- [ ] `progress.md` appended with:
  - [ ] Completed tasks
  - [ ] Decisions made
  - [ ] **Learnings section** (document any friction, patterns discovered, or "aha" moments)
  - [ ] Notes for next session
- [ ] If section complete: PR created

**Learnings are mandatory** - even if trivial, document "No significant learnings" to confirm you reflected.

## Important

- Complete exactly ONE task per iteration
- ALWAYS commit after completing a task
- ALWAYS update prd.json and progress.md
- If tests fail 3 times, stop and signal BLOCKED:TESTS
- If you're unsure about requirements, stop and signal BLOCKED:CLARIFICATION
- When a section is complete, create PR before signaling SECTION_COMPLETE

Begin by analyzing incomplete tasks and selecting the highest-priority one to implement.
