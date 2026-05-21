#!/usr/bin/env bash
set -euo pipefail

REQUIRED_GODOT_MAJOR=4
REQUIRED_GODOT_MINOR=6
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

pass=0
fail=0
warn=0

ok()   { echo -e "  ${GREEN}[OK]${RESET}   $1"; pass=$((pass + 1)); }
fail() { echo -e "  ${RED}[FAIL]${RESET} $1"; fail=$((fail + 1)); }
skip() { echo -e "  ${YELLOW}[SKIP]${RESET} $1"; warn=$((warn + 1)); }

echo -e "${BOLD}Rokugan Persistent World — Project Setup${RESET}"
echo "========================================="
echo ""

# ── Godot ──────────────────────────────────────────────────────
echo -e "${BOLD}1. Godot Engine${RESET}"

GODOT_BIN="${GODOT_BIN:-godot}"
if ! command -v "$GODOT_BIN" &>/dev/null; then
    fail "Godot not found. Install Godot ${REQUIRED_GODOT_MAJOR}.${REQUIRED_GODOT_MINOR}+ or set GODOT_BIN."
else
    GODOT_VERSION=$("$GODOT_BIN" --version 2>/dev/null | head -1)
    MAJOR=$(echo "$GODOT_VERSION" | cut -d. -f1)
    MINOR=$(echo "$GODOT_VERSION" | cut -d. -f2)
    if [[ "$MAJOR" -ge "$REQUIRED_GODOT_MAJOR" && "$MINOR" -ge "$REQUIRED_GODOT_MINOR" ]]; then
        ok "Godot $GODOT_VERSION"
    else
        fail "Godot $GODOT_VERSION found, need ${REQUIRED_GODOT_MAJOR}.${REQUIRED_GODOT_MINOR}+"
    fi
fi
echo ""

# ── Project structure ──────────────────────────────────────────
echo -e "${BOLD}2. Project structure${RESET}"

REQUIRED_DIRS=(simulation shared tests gdd scripts/managers scripts/ui systems/npc_engine/data/tables addons/gut)
for dir in "${REQUIRED_DIRS[@]}"; do
    if [[ -d "$PROJECT_ROOT/$dir" ]]; then
        ok "$dir/"
    else
        fail "$dir/ missing"
    fi
done

if [[ -f "$PROJECT_ROOT/project.godot" ]]; then
    ok "project.godot"
else
    fail "project.godot missing"
fi

if [[ -f "$PROJECT_ROOT/.gutconfig.json" ]]; then
    ok ".gutconfig.json"
else
    fail ".gutconfig.json missing"
fi
echo ""

# ── JSON scoring tables ───────────────────────────────────────
echo -e "${BOLD}3. NPC scoring tables (JSON validation)${RESET}"

TABLES_DIR="$PROJECT_ROOT/systems/npc_engine/data/tables"
EXPECTED_TABLES=(objective_alignment personality_lean personality_filter action_skill_map competence_table disposition_tiers urgency_rules topic_position_alignment)

if command -v python3 &>/dev/null; then
    JSON_CHECKER="python3 -m json.tool"
elif command -v jq &>/dev/null; then
    JSON_CHECKER="jq empty"
else
    JSON_CHECKER=""
fi

for table in "${EXPECTED_TABLES[@]}"; do
    file="$TABLES_DIR/${table}.json"
    if [[ ! -f "$file" ]]; then
        fail "${table}.json missing"
    elif [[ -z "$JSON_CHECKER" ]]; then
        skip "${table}.json (no json validator — install python3 or jq)"
    elif $JSON_CHECKER < "$file" &>/dev/null; then
        ok "${table}.json"
    else
        fail "${table}.json — invalid JSON"
    fi
done
echo ""

# ── GDD reference ─────────────────────────────────────────────
echo -e "${BOLD}4. GDD reference files${RESET}"

GDD_COUNT=$(find "$PROJECT_ROOT/gdd" -name "*.md" | wc -l)
if [[ "$GDD_COUNT" -gt 0 ]]; then
    ok "$GDD_COUNT GDD files found"
else
    fail "No GDD files in gdd/"
fi

if [[ -f "$PROJECT_ROOT/gdd/00_INDEX.md" ]]; then
    ok "00_INDEX.md present"
else
    fail "00_INDEX.md missing"
fi
echo ""

# ── Tests ──────────────────────────────────────────────────────
echo -e "${BOLD}5. GUT test suite${RESET}"

TEST_COUNT=$(find "$PROJECT_ROOT/tests" -name "test_*.gd" | wc -l)
echo "   Found $TEST_COUNT test scripts"

if [[ "${1:-}" == "--skip-tests" ]]; then
    skip "Test run skipped (--skip-tests)"
elif [[ "$fail" -gt 0 ]]; then
    skip "Test run skipped — fix failures above first"
else
    echo "   Running tests (this takes ~90s)..."
    TEST_OUTPUT=$(timeout 300 "$GODOT_BIN" --headless -s res://addons/gut/gut_cmdln.gd -- -gdir=res://tests/ -gprefix=test_ -gexit 2>&1) || true

    if echo "$TEST_OUTPUT" | grep -q "All tests passed"; then
        PASSING=$(echo "$TEST_OUTPUT" | grep "Passing Tests" | awk '{print $NF}')
        TOTAL_TIME=$(echo "$TEST_OUTPUT" | grep "^Time" | awk '{print $NF}')
        ok "All $PASSING tests passed ($TOTAL_TIME)"
    else
        PASSING=$(echo "$TEST_OUTPUT" | grep "Passing Tests" | awk '{print $NF}')
        TOTAL=$(echo "$TEST_OUTPUT" | grep "^Tests " | awk '{print $NF}')
        FAILED=$((TOTAL - PASSING))
        fail "$FAILED of $TOTAL tests failed"
        echo ""
        echo "   Re-run with verbose output:"
        echo "   godot --headless -s res://addons/gut/gut_cmdln.gd -- -gdir=res://tests/ -gprefix=test_ -gexit"
    fi
fi
echo ""

# ── Summary ────────────────────────────────────────────────────
echo "========================================="
echo -e "${GREEN}Passed: $pass${RESET}  ${RED}Failed: $fail${RESET}  ${YELLOW}Skipped: $warn${RESET}"

if [[ "$fail" -gt 0 ]]; then
    echo -e "${RED}Setup incomplete — see failures above.${RESET}"
    exit 1
else
    echo -e "${GREEN}Project ready.${RESET}"
    exit 0
fi
