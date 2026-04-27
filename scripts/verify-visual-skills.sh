#!/usr/bin/env bash
# scripts/verify-visual-skills.sh
# Static integrity checks for the visual-qa and visual-refine skills.
# Exits 0 on pass with "Result: OK"; nonzero on any failure with "Result: FAIL".

set -u

if [ "${1:-}" = "--version" ]; then
    echo "$0"
    echo "Static integrity checks for the visual-qa and visual-refine skills."
    exit 0
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QA_DIR="$REPO_ROOT/visual-qa"
REFINE_DIR="$REPO_ROOT/visual-refine"
QA_SKILL="$QA_DIR/SKILL.md"
REFINE_SKILL="$REFINE_DIR/SKILL.md"
QA_REF_DIR="$QA_DIR/references"
REFINE_REF_DIR="$REFINE_DIR/references"

failures=0
fail() {
    echo "FAIL: $1"
    failures=$((failures + 1))
}

# 1. Both SKILL.md files exist with valid YAML frontmatter containing name + description
for f in "$QA_SKILL" "$REFINE_SKILL"; do
    if [ ! -f "$f" ]; then
        fail "missing SKILL.md at $f"
        continue
    fi
    SKILL_PATH="$f" python3 - <<'PYEOF' || fail "frontmatter parse failed for $f"
import sys, os, yaml
path = os.environ["SKILL_PATH"]
text = open(path).read()
if not text.startswith("---"):
    sys.exit(1)
end = text.find("---", 3)
if end < 0:
    sys.exit(1)
fm = yaml.safe_load(text[3:end])
if not fm or "name" not in fm or "description" not in fm:
    sys.exit(1)
PYEOF
done

# 2. <HARD-GATE> block in both SKILL.md files
for f in "$QA_SKILL" "$REFINE_SKILL"; do
    [ -f "$f" ] || continue
    grep -q "<HARD-GATE>" "$f" 2>/dev/null || fail "missing <HARD-GATE> block in $f"
done

# 3. digraph block in both SKILL.md files
for f in "$QA_SKILL" "$REFINE_SKILL"; do
    [ -f "$f" ] || continue
    grep -q "digraph" "$f" 2>/dev/null || fail "missing digraph block in $f"
done

# 4. visual-qa/SKILL.md mentions inventory, inventory_coverage, aspiration_match
if [ -f "$QA_SKILL" ]; then
    for term in "inventory" "inventory_coverage" "aspiration_match"; do
        grep -q "$term" "$QA_SKILL" 2>/dev/null || fail "visual-qa/SKILL.md missing required term: $term"
    done
fi

# 5. visual-refine/SKILL.md mentions Phase 1.5, aspiration_match, triple-gate concept,
#    and the aspirational-spec path.
if [ -f "$REFINE_SKILL" ]; then
    grep -q "Phase 1.5" "$REFINE_SKILL" 2>/dev/null || fail "visual-refine/SKILL.md missing 'Phase 1.5'"
    grep -q "aspiration_match" "$REFINE_SKILL" 2>/dev/null || fail "visual-refine/SKILL.md missing 'aspiration_match'"
    grep -qE "triple-gate|triple gate" "$REFINE_SKILL" 2>/dev/null || fail "visual-refine/SKILL.md missing 'triple' gate concept"
    grep -q "instant_transitions" "$REFINE_SKILL" 2>/dev/null || fail "visual-refine/SKILL.md missing 'instant_transitions'"
    grep -q "aspirational-spec" "$REFINE_SKILL" 2>/dev/null || fail "visual-refine/SKILL.md missing 'aspirational-spec' path"
fi

# 6. recording-playbook.md has a "Capturing transitions" section
RECORDING_PLAYBOOK="$QA_REF_DIR/recording-playbook.md"
if [ -f "$RECORDING_PLAYBOOK" ]; then
    grep -qE "^## Capturing transitions" "$RECORDING_PLAYBOOK" 2>/dev/null \
        || fail "$RECORDING_PLAYBOOK missing '## Capturing transitions' section"
else
    fail "missing $RECORDING_PLAYBOOK"
fi

# 7. loop-mechanics.md has the two new section headings
LOOP_MECH="$REFINE_REF_DIR/loop-mechanics.md"
if [ -f "$LOOP_MECH" ]; then
    grep -qE "^## Aspiration-match across iterations" "$LOOP_MECH" 2>/dev/null \
        || fail "$LOOP_MECH missing '## Aspiration-match across iterations' section"
    grep -qE "^## Phase 5 regression includes aspiration regression" "$LOOP_MECH" 2>/dev/null \
        || fail "$LOOP_MECH missing '## Phase 5 regression includes aspiration regression' section"
else
    fail "missing $LOOP_MECH"
fi

# 8. design-principles.md byte-identical between the two skills
QA_DP="$QA_REF_DIR/design-principles.md"
REFINE_DP="$REFINE_REF_DIR/design-principles.md"
if [ -f "$QA_DP" ] && [ -f "$REFINE_DP" ]; then
    if ! diff_output=$(diff "$QA_DP" "$REFINE_DP" 2>&1); then
        fail "design-principles.md differs between visual-qa and visual-refine:
$diff_output"
    fi
else
    [ -f "$QA_DP" ] || fail "missing $QA_DP"
    [ -f "$REFINE_DP" ] || fail "missing $REFINE_DP"
fi

# 9. Negative check: no --reference (or equivalent) CLI flag introduced.
# Match flag-style tokens preceded by whitespace or backtick and followed by a
# non-letter/digit/hyphen/underscore. This distinguishes a flag (`--reference`)
# from a longer hyphenated flag (`--references-doc`) and from prose words.
for f in "$QA_SKILL" "$REFINE_SKILL"; do
    [ -f "$f" ] || continue
    for flag in reference ref-image mockup-input input-mockup; do
        if grep -qE "(^|[[:space:]\`])--${flag}([^a-zA-Z0-9_-]|$)" "$f" 2>/dev/null; then
            fail "$f introduces a --${flag} CLI flag (forbidden)"
        fi
    done
done

# 10. Every reference file mentioned in either SKILL.md exists.
# Resolution rules:
#   - If the substring `references/<name>.md` is preceded by a path-like prefix
#     (e.g., `~/.claude/skills/<other-skill>/`) we resolve against that other
#     skill's references/ dir under the repo root.
#   - Otherwise it is a local reference; resolve against the SKILL's own
#     references/ dir. As a fallback (for prose like "its `references/foo.md`"
#     where context implies a sibling skill), we also accept the file existing
#     in any sibling skill's references/ dir.
check_refs_for_skill() {
    local skill_file="$1"
    local skill_ref_dir="$2"
    [ -f "$skill_file" ] || return
    SKILL_FILE="$skill_file" SKILL_REF_DIR="$skill_ref_dir" REPO_ROOT="$REPO_ROOT" \
    python3 - <<'PYEOF'
import os, re, sys
skill_file = os.environ["SKILL_FILE"]
local_ref_dir = os.environ["SKILL_REF_DIR"]
repo_root = os.environ["REPO_ROOT"]
text = open(skill_file).read()
# Match an optional path prefix capturing a sibling-skill segment, then references/<name>.md
pattern = re.compile(r"(?:[~/\w./-]*?(?P<skill>[a-z][a-z0-9-]+)/)?references/(?P<name>[a-zA-Z0-9_-]+)\.md")
sibling_dirs = [
    os.path.join(repo_root, d, "references")
    for d in ("visual-qa", "visual-refine", "brainstorm-and-execute")
]
errors = 0
for m in pattern.finditer(text):
    name = m.group("name")
    skill_seg = m.group("skill")
    fname = name + ".md"
    # Try the explicit skill segment first if present.
    if skill_seg and skill_seg in ("visual-qa", "visual-refine", "brainstorm-and-execute"):
        target = os.path.join(repo_root, skill_seg, "references", fname)
        if os.path.isfile(target):
            continue
    # Otherwise try the local references dir.
    local = os.path.join(local_ref_dir, fname)
    if os.path.isfile(local):
        continue
    # Fallback: any sibling skill (covers prose like "its references/invariants.md").
    if any(os.path.isfile(os.path.join(sd, fname)) for sd in sibling_dirs):
        continue
    print("FAIL: %s mentions references/%s but no such file exists" % (skill_file, fname))
    errors += 1
sys.exit(0 if errors == 0 else 1)
PYEOF
}
if ! check_refs_for_skill "$QA_SKILL" "$QA_REF_DIR"; then
    failures=$((failures + 1))
fi
if ! check_refs_for_skill "$REFINE_SKILL" "$REFINE_REF_DIR"; then
    failures=$((failures + 1))
fi

# 11. No orphan reference files: every *.md under each skill's references/ is mentioned in its SKILL.md.
check_orphans() {
    local ref_dir="$1"
    local skill_file="$2"
    local skill_name="$3"
    [ -d "$ref_dir" ] || return
    for f in "$ref_dir"/*.md; do
        [ -f "$f" ] || continue
        base="references/$(basename "$f")"
        grep -q "$base" "$skill_file" 2>/dev/null \
            || fail "orphan reference: $base is in $skill_name/references/ but never mentioned in $skill_name/SKILL.md"
    done
}
check_orphans "$QA_REF_DIR" "$QA_SKILL" "visual-qa"
check_orphans "$REFINE_REF_DIR" "$REFINE_SKILL" "visual-refine"

# 12. Both SKILL.md files contain the autonomy HARD-GATE clause.
for f in "$QA_SKILL" "$REFINE_SKILL"; do
    [ -f "$f" ] || continue
    grep -q "MUST NOT pause for user confirmation" "$f" 2>/dev/null \
        || fail "$f missing the autonomy HARD-GATE clause"
done

# 13. visual-refine/SKILL.md documents BOTH the composite per-component path
#     (<component-id>.html) and the per-variation path (<variation-id>.html).
#     Locks in the side-by-side composite mockup contract.
if [ -f "$REFINE_SKILL" ]; then
    grep -q '<component-id>\.html' "$REFINE_SKILL" 2>/dev/null \
        || fail "visual-refine/SKILL.md missing composite mockup path '<component-id>.html'"
    grep -q '<variation-id>\.html' "$REFINE_SKILL" 2>/dev/null \
        || fail "visual-refine/SKILL.md missing per-variation mockup path '<variation-id>.html'"
fi

# 14. visual-refine/SKILL.md documents the per-run mockup gallery, the
#     Copy-reference button mechanism, the canonical citation anchor, and
#     the index→composite "Open in dedicated page" deep-link.
#     Locks the navigation + citation contract.
if [ -f "$REFINE_SKILL" ]; then
    grep -q '<scope-slug>/index\.html' "$REFINE_SKILL" 2>/dev/null \
        || fail "visual-refine/SKILL.md missing index artifact path '<scope-slug>/index.html'"
    grep -qE 'Copy reference|copy-ref' "$REFINE_SKILL" 2>/dev/null \
        || fail "visual-refine/SKILL.md missing Copy-reference button mechanism"
    grep -q '#variation-<id>' "$REFINE_SKILL" 2>/dev/null \
        || fail "visual-refine/SKILL.md missing canonical citation anchor '#variation-<id>'"
    grep -q 'Open in dedicated page' "$REFINE_SKILL" 2>/dev/null \
        || fail "visual-refine/SKILL.md missing 'Open in dedicated page' deep-link from index to composite"
fi

if [ "$failures" -eq 0 ]; then
    echo "Result: OK"
    exit 0
else
    echo "Result: FAIL ($failures check(s) failed)"
    exit 1
fi
