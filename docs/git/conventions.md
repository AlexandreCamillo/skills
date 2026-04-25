# Git Conventions

## Commit Message Format

All commits must follow **Conventional Commits**:

```
<type>(<scope>): <description>
```

- **Subject line only** — no body, no footer, no `Co-Authored-By`
- Keep the description concise and under 72 characters

## Allowed Types

| Type       | Usage                              |
|------------|------------------------------------|
| `feat`     | New feature or skill capability    |
| `fix`      | Bug fix or incorrect behavior      |
| `docs`     | Documentation only                 |
| `style`    | Formatting (no logic changes)      |
| `refactor` | Restructuring without behavior change |
| `test`     | Adding or updating tests/scripts   |
| `chore`    | Maintenance tasks (configs, deps)  |

## Scopes

Use the component or file area being changed:

| Scope          | When to use                                       |
|----------------|---------------------------------------------------|
| `visual-qa`    | Changes to the `visual-qa/` skill                 |
| `visual-refine`| Changes to the `visual-refine/` skill             |
| `references`   | Changes to any `references/` file                 |
| `design`       | Changes to `design-principles.md`                 |
| `scripts`      | Changes to `scripts/`                             |
| `docs`         | Changes to `docs/`                                |
| `platform`     | Changes to `GEMINI.md`, `AGENTS.md`, or `CLAUDE.md`  |
| `install`      | README install steps or runtime requirements      |
| `brainstorm-and-execute` | Changes to the `brainstorm-and-execute/` skill |

## Good vs Bad Examples

```bash
# Good — natural and descriptive
git commit -m "feat(visual-qa): add mobile viewport to exploration checklist"
git commit -m "fix(visual-refine): correct stall detection after two equal iters"
git commit -m "refactor(references): extract motion anchors into separate section"
git commit -m "docs(git): add commit conventions"
git commit -m "chore(scripts): update verify script to check digraph marker"

# Bad — generic or robotic
git commit -m "Update skill"
git commit -m "Fix issue"
git commit -m "Improve visual-qa as requested"
```

## Development Workflow

Commit at every meaningful checkpoint:

1. **After rubric or schema changes** — `feat(design): add contrast anchor to accessibility dimension`
2. **After skill logic changes** — `feat(visual-qa): enforce exhaustion rule before marking untested`
3. **After reference updates** — `docs(references): clarify loop exit precedence in loop-mechanics`
4. **After script fixes** — `fix(scripts): handle missing SKILL.md in verify script`
5. **After refactoring** — `refactor(visual-refine): extract checkpoint logic to shared block`

## Rules

- **Never** make large commits with many unrelated changes
- **Never** use generic messages like "fix skill" or "update file"
- Keep commits small and frequent
- Messages should explain the **why**, not just the **what**
- Write messages as a human developer would
