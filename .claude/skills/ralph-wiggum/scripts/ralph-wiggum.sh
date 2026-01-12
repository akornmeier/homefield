#!/bin/bash
#
# Ralph Wiggum Autonomous Loop
#
# Repeatedly calls Claude Code with the PRD until completion or stop condition.
#
# Usage:
#   ./ralph-wiggum.sh <change-id>
#   ./ralph-wiggum.sh add-browser-extension-ui
#   ./ralph-wiggum.sh add-browser-extension-ui --section 5
#   ./ralph-wiggum.sh add-browser-extension-ui --max-iterations 20
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Default settings
MAX_ITERATIONS=10
CHANGE_ID=""
TARGET_SECTION=""
ITERATION_TIMEOUT=600  # 10 minutes per iteration
MAX_CONSECUTIVE_FAILURES=3
SKIP_PREFLIGHT=false

# Tracking variables
CONSECUTIVE_FAILURES=0
LAST_TASK_ID=""
SAME_TASK_ATTEMPTS=0
MAX_SAME_TASK_ATTEMPTS=3

# Temp file for capturing output while streaming
OUTPUT_FILE=$(mktemp)
PID_FILE=$(mktemp)
trap "rm -f $OUTPUT_FILE $PID_FILE" EXIT

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --max-iterations|-m)
            MAX_ITERATIONS="$2"
            shift 2
            ;;
        --section|-s)
            TARGET_SECTION="$2"
            shift 2
            ;;
        --timeout|-t)
            ITERATION_TIMEOUT="$2"
            shift 2
            ;;
        --skip-preflight)
            SKIP_PREFLIGHT=true
            shift
            ;;
        --help|-h)
            echo "Usage: ralph-wiggum.sh <change-id> [options]"
            echo ""
            echo "Options:"
            echo "  --section, -s          Target section to complete (stops when section done)"
            echo "  --max-iterations, -m   Maximum iterations before pausing (default: 10)"
            echo "  --timeout, -t          Timeout per iteration in seconds (default: 600)"
            echo "  --skip-preflight       Skip pre-flight checks (not recommended)"
            echo "  --help, -h             Show this help"
            echo ""
            echo "Examples:"
            echo "  ralph-wiggum.sh add-browser-extension-ui                    # Run full PRD"
            echo "  ralph-wiggum.sh add-browser-extension-ui --section 5        # Complete section 5 only"
            echo "  ralph-wiggum.sh add-browser-extension-ui -s 5 -m 20         # Section 5, max 20 iterations"
            echo "  ralph-wiggum.sh add-browser-extension-ui --timeout 300      # 5 min timeout per iteration"
            exit 0
            ;;
        *)
            if [[ -z "$CHANGE_ID" ]]; then
                CHANGE_ID="$1"
            fi
            shift
            ;;
    esac
done

if [[ -z "$CHANGE_ID" ]]; then
    echo -e "${RED}Error: change-id is required${NC}"
    echo "Usage: ralph-wiggum.sh <change-id>"
    exit 1
fi

# Find project root (where openspec/ directory is)
find_project_root() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/openspec" ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    echo ""
    return 1
}

PROJECT_ROOT=$(find_project_root)
if [[ -z "$PROJECT_ROOT" ]]; then
    echo -e "${RED}Error: Could not find openspec directory${NC}"
    exit 1
fi

CHANGE_DIR="$PROJECT_ROOT/openspec/changes/$CHANGE_ID"
PRD_FILE="$CHANGE_DIR/prd.json"
PROGRESS_FILE="$CHANGE_DIR/progress.md"

# Verify PRD exists
if [[ ! -f "$PRD_FILE" ]]; then
    echo -e "${RED}Error: PRD not found at $PRD_FILE${NC}"
    echo "Run 'python3 .claude/skills/ralph/scripts/compile.py $CHANGE_ID' first"
    exit 1
fi

# Get script directory for prompt template
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPT_TEMPLATE="$SCRIPT_DIR/prompt.md"
QUOTES_FILE="$SCRIPT_DIR/ralph-quotes.txt"

if [[ ! -f "$PROMPT_TEMPLATE" ]]; then
    echo -e "${RED}Error: Prompt template not found at $PROMPT_TEMPLATE${NC}"
    exit 1
fi

# Get a random Ralph Wiggum quote (portable)
get_ralph_quote() {
    if [[ -f "$QUOTES_FILE" ]]; then
        # Use shuf if available, otherwise fall back to awk
        shuf -n 1 "$QUOTES_FILE" 2>/dev/null || \
        awk 'BEGIN{srand()} {lines[NR]=$0} END{print lines[int(rand()*NR)+1]}' "$QUOTES_FILE"
    else
        echo "I'm helping!"
    fi
}

# Format elapsed time as human-readable
format_elapsed() {
    local seconds=$1
    if [[ $seconds -lt 60 ]]; then
        echo "${seconds}s"
    elif [[ $seconds -lt 3600 ]]; then
        local mins=$((seconds / 60))
        local secs=$((seconds % 60))
        echo "${mins}m ${secs}s"
    else
        local hours=$((seconds / 3600))
        local mins=$(((seconds % 3600) / 60))
        echo "${hours}h ${mins}m"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# PRE-FLIGHT CHECKS
# Kill conflicting processes that may cause hangs or resource contention
# ═══════════════════════════════════════════════════════════════════════════

preflight_checks() {
    echo -e "${BLUE}── Pre-flight checks ──${NC}"
    local issues_found=false

    # 1. Check for and kill Storybook dev servers
    local storybook_pids=$(pgrep -f "storybook dev" 2>/dev/null || true)
    if [[ -n "$storybook_pids" ]]; then
        echo -e "${YELLOW}  ⚠ Found running Storybook dev server(s)${NC}"
        echo -e "${DIM}    PIDs: $storybook_pids${NC}"
        echo -e "${CYAN}    Killing to prevent test conflicts...${NC}"
        echo "$storybook_pids" | xargs kill -9 2>/dev/null || true
        sleep 1
        issues_found=true
    fi

    # 2. Check for processes on common dev ports (6006=Storybook, 5173=Vite)
    for port in 6006 5173; do
        local port_pid=$(lsof -ti:$port 2>/dev/null || true)
        if [[ -n "$port_pid" ]]; then
            local proc_name=$(ps -p "$port_pid" -o comm= 2>/dev/null || echo "unknown")
            echo -e "${YELLOW}  ⚠ Port $port in use by $proc_name (PID: $port_pid)${NC}"
            echo -e "${CYAN}    Killing to free port...${NC}"
            kill -9 "$port_pid" 2>/dev/null || true
            sleep 1
            issues_found=true
        fi
    done

    # 3. Check for orphaned Playwright/Chromium processes from previous test runs
    local orphan_chromium=$(pgrep -f "chromium.*--headless" 2>/dev/null | head -5 || true)
    if [[ -n "$orphan_chromium" ]]; then
        local count=$(echo "$orphan_chromium" | wc -l | tr -d ' ')
        echo -e "${YELLOW}  ⚠ Found $count orphaned headless Chromium process(es)${NC}"
        echo -e "${CYAN}    Killing to free resources...${NC}"
        echo "$orphan_chromium" | xargs kill -9 2>/dev/null || true
        sleep 1
        issues_found=true
    fi

    # 4. Check for stuck vitest processes
    local stuck_vitest=$(pgrep -f "vitest" 2>/dev/null | head -5 || true)
    if [[ -n "$stuck_vitest" ]]; then
        local count=$(echo "$stuck_vitest" | wc -l | tr -d ' ')
        echo -e "${YELLOW}  ⚠ Found $count vitest process(es) still running${NC}"
        echo -e "${CYAN}    Killing to prevent conflicts...${NC}"
        echo "$stuck_vitest" | xargs kill -9 2>/dev/null || true
        sleep 1
        issues_found=true
    fi

    # 5. Check available memory (warn if low)
    if command -v vm_stat &>/dev/null; then
        # macOS
        local free_pages=$(vm_stat | grep "Pages free" | awk '{print $3}' | tr -d '.')
        local free_mb=$((free_pages * 4096 / 1024 / 1024))
        if [[ $free_mb -lt 500 ]]; then
            echo -e "${YELLOW}  ⚠ Low memory: ~${free_mb}MB free${NC}"
            echo -e "${DIM}    Consider closing other applications${NC}"
            issues_found=true
        fi
    fi

    if [[ "$issues_found" == "true" ]]; then
        echo -e "${GREEN}  ✓ Pre-flight issues resolved${NC}"
    else
        echo -e "${GREEN}  ✓ No issues found${NC}"
    fi
    echo ""
}

# Run with timeout and capture exit status
# Returns: 0=success, 124=timeout, other=error
run_with_timeout() {
    local timeout_secs=$1
    shift

    # Use timeout command if available (GNU coreutils)
    if command -v timeout &>/dev/null; then
        timeout --signal=KILL "$timeout_secs" "$@"
        return $?
    elif command -v gtimeout &>/dev/null; then
        # macOS with coreutils installed via brew
        gtimeout --signal=KILL "$timeout_secs" "$@"
        return $?
    else
        # Fallback: run in background with manual timeout
        "$@" &
        local pid=$!
        echo "$pid" > "$PID_FILE"

        local elapsed=0
        while kill -0 "$pid" 2>/dev/null; do
            if [[ $elapsed -ge $timeout_secs ]]; then
                echo -e "${RED}  ⚠ Timeout after ${timeout_secs}s - killing process${NC}"
                kill -9 "$pid" 2>/dev/null || true
                wait "$pid" 2>/dev/null || true
                return 124
            fi
            sleep 1
            elapsed=$((elapsed + 1))
        done

        wait "$pid"
        return $?
    fi
}

# Calculate backoff delay based on consecutive failures
get_backoff_delay() {
    local failures=$1
    # Exponential backoff: 2, 4, 8, 16... capped at 60 seconds
    local delay=$((2 ** failures))
    if [[ $delay -gt 60 ]]; then
        delay=60
    fi
    echo $delay
}

# Get next task info from PRD
get_next_task_info() {
    python3 -c "
import json
import sys

with open('$PRD_FILE') as f:
    prd = json.load(f)

target_section = '$TARGET_SECTION' if '$TARGET_SECTION' else None

for section in prd.get('sections', []):
    if target_section and section['number'] != int(target_section):
        continue
    for task in section.get('tasks', []):
        if not task.get('passes', False):
            print(f\"{task['id']}: {task['description'][:60]}\")
            sys.exit(0)

print('All tasks complete')
" 2>/dev/null || echo "Unknown"
}

# Get section progress
get_section_progress() {
    python3 -c "
import json

with open('$PRD_FILE') as f:
    prd = json.load(f)

target = '$TARGET_SECTION' if '$TARGET_SECTION' else None

for section in prd.get('sections', []):
    if target and section['number'] != int(target):
        continue
    tasks = section.get('tasks', [])
    done = sum(1 for t in tasks if t.get('passes', False))
    total = len(tasks)
    print(f'{done}/{total}')
    break
" 2>/dev/null || echo "?/?"
}

# Display header
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Ralph Wiggum Autonomous Loop                              ║${NC}"
echo -e "${BLUE}╠════════════════════════════════════════════════════════════╣${NC}"
echo -e "${BLUE}║  Change:${NC} $CHANGE_ID"
if [[ -n "$TARGET_SECTION" ]]; then
    echo -e "${BLUE}║  Target section:${NC} $TARGET_SECTION (stop when complete)"
fi
echo -e "${BLUE}║  Max iterations:${NC} $MAX_ITERATIONS"
echo -e "${BLUE}║  Timeout per iteration:${NC} ${ITERATION_TIMEOUT}s"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Run pre-flight checks unless skipped
if [[ "$SKIP_PREFLIGHT" != "true" ]]; then
    preflight_checks
else
    echo -e "${YELLOW}⚠ Pre-flight checks skipped${NC}"
    echo ""
fi

# Build the prompt by injecting PRD and progress
build_prompt() {
    local prd_content=$(cat "$PRD_FILE")
    local progress_content=""
    if [[ -f "$PROGRESS_FILE" ]]; then
        progress_content=$(cat "$PROGRESS_FILE")
    fi

    # Add section target instruction if specified
    local section_instruction=""
    if [[ -n "$TARGET_SECTION" ]]; then
        section_instruction="

## Target Section

Focus ONLY on section $TARGET_SECTION. When all tasks in section $TARGET_SECTION have \`\"passes\": true\`, signal SECTION_COMPLETE and create PR.
"
    fi

    # Replace placeholders in template
    local prompt=$(cat "$PROMPT_TEMPLATE")
    prompt="${prompt//\{\{CHANGE_ID\}\}/$CHANGE_ID}"

    # Insert PRD content
    prompt="${prompt//\{\{PRD_JSON\}\}/$prd_content}"

    # Insert progress content
    prompt="${prompt//\{\{PROGRESS_MD\}\}/$progress_content}"

    # Add section instruction after the PRD if specified
    if [[ -n "$section_instruction" ]]; then
        prompt="$prompt$section_instruction"
    fi

    echo "$prompt"
}

# Check if target section is complete
check_section_complete() {
    if [[ -z "$TARGET_SECTION" ]]; then
        return 1  # No target section, never complete by this check
    fi

    # Use Python to check if all tasks in target section pass
    python3 -c "
import json
import sys

with open('$PRD_FILE') as f:
    prd = json.load(f)

for section in prd.get('sections', []):
    if section['number'] == $TARGET_SECTION:
        tasks = section.get('tasks', [])
        if all(t.get('passes', False) for t in tasks):
            sys.exit(0)  # Section complete
        else:
            sys.exit(1)  # Section not complete

sys.exit(1)  # Section not found
" 2>/dev/null
    return $?
}

# Main loop
iteration=0
TOTAL_START_TIME=$(date +%s)

while [[ $iteration -lt $MAX_ITERATIONS ]]; do
    iteration=$((iteration + 1))
    ITER_START_TIME=$(date +%s)

    # Get current progress info
    NEXT_TASK=$(get_next_task_info)
    SECTION_PROG=$(get_section_progress)

    # Extract task ID for stuck detection (format: "6.1: description")
    CURRENT_TASK_ID=$(echo "$NEXT_TASK" | cut -d: -f1 | tr -d ' ')

    # Check if we're stuck on the same task
    if [[ "$CURRENT_TASK_ID" == "$LAST_TASK_ID" ]]; then
        SAME_TASK_ATTEMPTS=$((SAME_TASK_ATTEMPTS + 1))
        if [[ $SAME_TASK_ATTEMPTS -ge $MAX_SAME_TASK_ATTEMPTS ]]; then
            echo ""
            echo -e "${RED}⚠ BLOCKED:HUNG - Same task attempted $SAME_TASK_ATTEMPTS times without progress${NC}"
            echo -e "${RED}  Task: $NEXT_TASK${NC}"
            echo -e "${RED}  This likely indicates a test or implementation issue.${NC}"
            echo -e "${YELLOW}  Review progress.md and fix manually.${NC}"
            break
        fi
        echo -e "${YELLOW}  ⚠ Retry attempt $SAME_TASK_ATTEMPTS/$MAX_SAME_TASK_ATTEMPTS for task $CURRENT_TASK_ID${NC}"
    else
        SAME_TASK_ATTEMPTS=1
        LAST_TASK_ID="$CURRENT_TASK_ID"
    fi

    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Iteration $iteration of $MAX_ITERATIONS${NC}"
    if [[ -n "$TARGET_SECTION" ]]; then
        echo -e "${YELLOW}Section $TARGET_SECTION progress: ${CYAN}$SECTION_PROG${NC}"
    fi
    echo -e "${YELLOW}Next task: ${CYAN}$NEXT_TASK${NC}"
    if [[ $CONSECUTIVE_FAILURES -gt 0 ]]; then
        echo -e "${RED}Consecutive failures: $CONSECUTIVE_FAILURES${NC}"
    fi
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Check if target section already complete (before iteration)
    if check_section_complete; then
        echo ""
        echo -e "${GREEN}✓ Section $TARGET_SECTION already complete!${NC}"
        break
    fi

    # Apply backoff delay if we've had failures
    if [[ $CONSECUTIVE_FAILURES -gt 0 ]]; then
        backoff_delay=$(get_backoff_delay $CONSECUTIVE_FAILURES)
        echo -e "${YELLOW}  Backing off for ${backoff_delay}s before retry...${NC}"
        sleep $backoff_delay
    fi

    # Build and execute prompt
    PROMPT=$(build_prompt)

    # Call Claude Code with the prompt
    # Stream output in real-time using tee, while also capturing to file
    echo -e "${DIM}── Claude output (streaming, timeout: ${ITERATION_TIMEOUT}s) ────${NC}"

    # Permission setup for autonomous operation:
    # - acceptEdits: auto-approve file edits (Read, Edit, Write, Glob, Grep, etc.)
    # - allowedTools: additionally allow git and gh bash commands for commits/PRs
    # - stream-json + verbose: show tool calls in real-time
    # - format-stream.py: converts JSON to human-readable output
    > "$OUTPUT_FILE"
    FORMATTER="$SCRIPT_DIR/format-stream.py"

    # Run Claude with timeout protection
    CLAUDE_EXIT_CODE=0
    if command -v gtimeout &>/dev/null; then
        # macOS with coreutils
        echo "$PROMPT" | gtimeout --signal=TERM --kill-after=30 "$ITERATION_TIMEOUT" \
            stdbuf -oL claude --print \
            --permission-mode=acceptEdits \
            --allowedTools "Bash(git:*)" "Bash(gh:*)" \
            --output-format=stream-json \
            --verbose \
            2>&1 | stdbuf -oL tee "$OUTPUT_FILE" | python3 "$FORMATTER" || CLAUDE_EXIT_CODE=$?
    elif command -v timeout &>/dev/null; then
        # Linux with coreutils
        echo "$PROMPT" | timeout --signal=TERM --kill-after=30 "$ITERATION_TIMEOUT" \
            stdbuf -oL claude --print \
            --permission-mode=acceptEdits \
            --allowedTools "Bash(git:*)" "Bash(gh:*)" \
            --output-format=stream-json \
            --verbose \
            2>&1 | stdbuf -oL tee "$OUTPUT_FILE" | python3 "$FORMATTER" || CLAUDE_EXIT_CODE=$?
    else
        # No timeout command available - run without timeout (with warning)
        echo -e "${YELLOW}  Warning: timeout command not found, running without timeout${NC}"
        echo "$PROMPT" | stdbuf -oL claude --print \
            --permission-mode=acceptEdits \
            --allowedTools "Bash(git:*)" "Bash(gh:*)" \
            --output-format=stream-json \
            --verbose \
            2>&1 | stdbuf -oL tee "$OUTPUT_FILE" | python3 "$FORMATTER" || CLAUDE_EXIT_CODE=$?
    fi

    echo -e "${DIM}───────────────────────────────────────────────────────────${NC}"

    # Check for timeout (exit code 124 for timeout, 137 for kill)
    if [[ $CLAUDE_EXIT_CODE -eq 124 ]] || [[ $CLAUDE_EXIT_CODE -eq 137 ]]; then
        echo ""
        echo -e "${RED}⚠ Iteration timed out after ${ITERATION_TIMEOUT}s${NC}"
        CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))

        if [[ $CONSECUTIVE_FAILURES -ge $MAX_CONSECUTIVE_FAILURES ]]; then
            echo -e "${RED}⚠ BLOCKED:TIMEOUT - $MAX_CONSECUTIVE_FAILURES consecutive timeouts${NC}"
            echo -e "${RED}  Something may be causing Claude to hang.${NC}"
            echo -e "${YELLOW}  Try running preflight_checks manually or investigate.${NC}"
            break
        fi

        echo -e "${YELLOW}  Will retry with backoff...${NC}"
        continue
    fi

    # Read captured output for signal detection
    OUTPUT=$(cat "$OUTPUT_FILE")

    # Show iteration timing
    ITER_END_TIME=$(date +%s)
    ITER_ELAPSED=$((ITER_END_TIME - ITER_START_TIME))
    TOTAL_ELAPSED=$((ITER_END_TIME - TOTAL_START_TIME))
    echo ""
    echo -e "${DIM}Iteration: $(format_elapsed $ITER_ELAPSED) | Total: $(format_elapsed $TOTAL_ELAPSED)${NC}"

    # Check for stop signals in output
    if echo "$OUTPUT" | grep -q "SECTION_COMPLETE"; then
        echo ""
        echo -e "${GREEN}✓ Section complete signal received${NC}"
        echo -e "${YELLOW}Ralph says: \"$(get_ralph_quote)\"${NC}"
        break
    fi

    if echo "$OUTPUT" | grep -q "BLOCKED:TESTS"; then
        echo ""
        echo -e "${RED}⚠ Blocked: Tests failing after multiple attempts${NC}"
        echo -e "${RED}  Review progress.md and fix manually.${NC}"
        break
    fi

    if echo "$OUTPUT" | grep -q "BLOCKED:CLARIFICATION"; then
        echo ""
        echo -e "${YELLOW}⚠ Blocked: Needs clarification${NC}"
        echo -e "${YELLOW}  Review progress.md for the question.${NC}"
        break
    fi

    if echo "$OUTPUT" | grep -q "ALL_TASKS_COMPLETE"; then
        echo ""
        echo -e "${GREEN}✓ All tasks complete!${NC}"
        echo -e "${YELLOW}Ralph says: \"$(get_ralph_quote)\"${NC}"
        break
    fi

    # Check if target section is now complete (after iteration)
    if check_section_complete; then
        echo ""
        echo -e "${GREEN}✓ Section $TARGET_SECTION tasks all pass${NC}"
        echo -e "${YELLOW}Ralph says: \"$(get_ralph_quote)\"${NC}"
        break
    fi

    # Task completed, output a Ralph quote and continue
    if echo "$OUTPUT" | grep -q "TASK_COMPLETE"; then
        echo ""
        echo -e "${YELLOW}Ralph says: \"$(get_ralph_quote)\"${NC}"
        # Reset failure counters on successful task completion
        CONSECUTIVE_FAILURES=0
    fi

    # Brief pause between iterations
    sleep 2
done

if [[ $iteration -ge $MAX_ITERATIONS ]]; then
    echo ""
    echo -e "${YELLOW}⏸ Paused: Reached max iterations ($MAX_ITERATIONS)${NC}"
    echo -e "${YELLOW}  Run again to continue, or increase --max-iterations${NC}"
fi

# ═══════════════════════════════════════════════════════════════════════════
# POST-LOOP VERIFICATION
# Claude may signal completion but fail to commit/push/PR. Verify and warn.
# ═══════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${BLUE}── Verifying work was committed and pushed ──${NC}"

# Check for uncommitted changes
UNCOMMITTED=$(git status --porcelain 2>/dev/null | grep -E "^\s*M|^\?\?" | head -20)
if [[ -n "$UNCOMMITTED" ]]; then
    echo ""
    echo -e "${RED}⚠ WARNING: Uncommitted changes detected!${NC}"
    echo -e "${RED}  Claude may have updated files but forgot to commit.${NC}"
    echo ""
    echo -e "${DIM}Uncommitted files:${NC}"
    echo "$UNCOMMITTED" | head -10
    if [[ $(echo "$UNCOMMITTED" | wc -l) -gt 10 ]]; then
        echo "  ... and more"
    fi
    echo ""
    echo -e "${YELLOW}To fix: Review changes, then run:${NC}"
    echo -e "${CYAN}  git add . && git commit -m \"feat(browser): complete section $TARGET_SECTION\"${NC}"
fi

# Check if section complete but no PR exists
if check_section_complete 2>/dev/null; then
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)
    PR_EXISTS=$(gh pr list --head "$CURRENT_BRANCH" --state open 2>/dev/null | head -1)

    if [[ -z "$PR_EXISTS" ]]; then
        echo ""
        echo -e "${RED}⚠ WARNING: Section complete but no PR found!${NC}"
        echo -e "${RED}  Claude signaled SECTION_COMPLETE but didn't create the PR.${NC}"
        echo ""
        echo -e "${YELLOW}To fix: Push branch and create PR:${NC}"
        echo -e "${CYAN}  git push -u origin $CURRENT_BRANCH${NC}"
        echo -e "${CYAN}  gh pr create --title \"[${CHANGE_ID}] Section ${TARGET_SECTION}\" --body \"Section ${TARGET_SECTION} complete\"${NC}"
    else
        echo -e "${GREEN}✓ PR exists: $PR_EXISTS${NC}"
    fi
else
    echo -e "${DIM}Section not complete, PR check skipped${NC}"
fi

# Final timing
FINAL_TIME=$(date +%s)
FINAL_ELAPSED=$((FINAL_TIME - TOTAL_START_TIME))

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Final status:${NC}"
echo -e "${BLUE}Total time: $(format_elapsed $FINAL_ELAPSED) | Iterations: $iteration${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
python3 "$SCRIPT_DIR/status.py" "$CHANGE_ID"
