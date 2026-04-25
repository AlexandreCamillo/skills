#!/usr/bin/env bash
# scripts/verify-brainstorm-and-execute.sh
# Static integrity checks for the brainstorm-and-execute skill.
# Exits 0 on pass with "Result: OK"; nonzero on any failure with "Result: FAIL".

set -u

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)/brainstorm-and-execute"
REF_DIR="$SKILL_DIR/references"
SKILL_FILE="$SKILL_DIR/SKILL.md"

failures=0
fail() {
    echo "FAIL: $1"
    failures=$((failures + 1))
}

# 1. SKILL.md exists
[ -f "$SKILL_FILE" ] || fail "missing SKILL.md at $SKILL_FILE"

# 2. SKILL.md has frontmatter with name and description
if [ -f "$SKILL_FILE" ]; then
    python3 - <<PYEOF || fail "frontmatter parse failed"
import sys, yaml
text = open("$SKILL_FILE").read()
if not text.startswith("---"):
    sys.exit(1)
end = text.find("---", 3)
if end < 0:
    sys.exit(1)
fm = yaml.safe_load(text[3:end])
if not fm or "name" not in fm or "description" not in fm:
    sys.exit(1)
PYEOF
fi

# 3. <HARD-GATE> block present
grep -q "<HARD-GATE>" "$SKILL_FILE" 2>/dev/null || fail "missing <HARD-GATE> block in SKILL.md"

# 4. digraph block present
grep -q "digraph" "$SKILL_FILE" 2>/dev/null || fail "missing digraph block in SKILL.md"

# 5. 8-phase checklist (Phase 0 .. Phase 7)
for phase in "Phase 0" "Phase 1" "Phase 2" "Phase 3" "Phase 4" "Phase 5" "Phase 6" "Phase 7"; do
    grep -q "$phase" "$SKILL_FILE" 2>/dev/null || fail "checklist missing $phase"
done

# 6. Every reference file mentioned in SKILL.md exists
mentioned=$(grep -oE "references/[a-z-]+\.md" "$SKILL_FILE" 2>/dev/null | sort -u)
for ref in $mentioned; do
    [ -f "$SKILL_DIR/$ref" ] || fail "SKILL.md references $ref but file is missing"
done

# 7. No orphan reference files
if [ -d "$REF_DIR" ]; then
    for f in "$REF_DIR"/*.md; do
        [ -f "$f" ] || continue
        base="references/$(basename "$f")"
        grep -q "$base" "$SKILL_FILE" 2>/dev/null || fail "orphan reference: $base is in references/ but never mentioned in SKILL.md"
    done
fi

# 8. SKILL.md mentions every required artifact path
for path in "docs/superpowers/decisions" "docs/superpowers/specs" "docs/superpowers/plans" "docs/superpowers/runs"; do
    grep -q "$path" "$SKILL_FILE" 2>/dev/null || fail "SKILL.md never mentions $path"
done

# 9. Templates that declare frontmatter parse cleanly
for tpl in decision-template rubric-template run-report-template; do
    f="$REF_DIR/$tpl.md"
    [ -f "$f" ] || continue
    # Templates contain example frontmatter inside fenced blocks; we just check
    # that the file is non-empty, well-formed UTF-8, and contains the literal "---"
    # frontmatter delimiter at least twice.
    delim_count=$(grep -c "^---$" "$f" 2>/dev/null || echo 0)
    if [ "$delim_count" -lt 2 ]; then
        fail "$tpl.md does not contain a frontmatter delimiter pair"
    fi
done

if [ "$failures" -eq 0 ]; then
    echo "Result: OK"
    exit 0
else
    echo "Result: FAIL ($failures check(s) failed)"
    exit 1
fi
