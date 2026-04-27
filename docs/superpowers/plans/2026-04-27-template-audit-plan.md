# Template Audit & Plugin Rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to execute this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Conduct comprehensive audit of project-template repository, identify all issues with hardcoded `project-template@local` plugin name and unused `correspondence-2` skill, then fix them systematically.

**Architecture:** Three-phase execution — (1) parallel SA + Dev audits producing findings markdown files, (2) PM aggregates findings into consolidated report with checklist, (3) PM batch-implements all fixes following checklist, tests, commits.

**Tech Stack:** Bash scripts, sed/grep for text processing, jq for JSON validation, git for version control

---

## **Task 1: SA Audit — Architecture & Structure (Subagent: SA)**

**Files:**
- Scan (no modification): `.doc-root.yaml`, `CLAUDE.md`, `AGENTS.md`, `README.md`, `content/` (full tree), `docs/overlays/`
- Create: `docs/audit/sa-findings.md`

- [ ] **Step 1: Scan `.doc-root.yaml` for property definitions**

Run from repo root:
```bash
cat content/.doc-root.yaml | head -100
```

Expected: YAML with `properties`, `enum`, `required` fields. Take note of required properties (e.g., tags, authors, etc.).

- [ ] **Step 2: Search for all references to `project-template@local` in markdown and YAML**

```bash
grep -r "project-template@local" content/ docs/ CLAUDE.md AGENTS.md README.md 2>/dev/null | tee /tmp/sa-grep-project-template.txt
```

Expected: List of all lines containing `project-template@local`. Save to temp file for reporting.

- [ ] **Step 3: Search for references to `correspondence-2` in documentation**

```bash
grep -r "correspondence-2" content/ docs/ CLAUDE.md AGENTS.md README.md 2>/dev/null | tee /tmp/sa-grep-correspondence.txt
```

Expected: List of all lines mentioning `correspondence-2` skill.

- [ ] **Step 4: Check `docs/overlays/` structure and completeness**

```bash
find docs/overlays -type f \( -name "*.md" -o -name "*.yaml" \) | head -20
```

Review that each overlay has README and proper structure.

- [ ] **Step 5: Verify `content/` structure against `.doc-root.yaml` requirements**

```bash
find content -type f -name "*.md" | head -20
# For each .md, check if it has required frontmatter fields (title, tags, etc.)
head -20 content/00-project/roadmap.md  # example
```

Expected: Markdown files should have YAML frontmatter matching properties in `.doc-root.yaml`.

- [ ] **Step 6: Check for broken cross-references or dangling links**

```bash
# Look for placeholders that were not replaced
grep -r "{{" content/ docs/ CLAUDE.md AGENTS.md README.md 2>/dev/null | grep -v "PROJECT_NAME" | tee /tmp/sa-grep-placeholders.txt
```

Expected: Should find minimal/no results (only {{PROJECT_NAME}} if not yet initialized).

- [ ] **Step 7: Write findings to `docs/audit/sa-findings.md`**

Create file with structure:

```markdown
# SA Audit Findings — 2026-04-27

## Summary
- Scanned: `.doc-root.yaml`, `content/` full tree, `docs/overlays/`, CLAUDE.md, AGENTS.md, README.md
- Scan date: 2026-04-27
- Issues found: [N] critical, [M] informational

## Issues

### Issue 1: Hardcoded `project-template@local` in documentation
**Severity:** HIGH  
**Location:** [list exact files and line numbers from grep output]  
**Description:** Documentation references hardcoded plugin name `project-template@local` which does not align with the universal naming scheme needed for a template.  
**Recommendation:** Replace all instances with `project@local`

### Issue 2: `correspondence-2` skill references in docs
**Severity:** MEDIUM  
**Location:** [list exact files]  
**Description:** Unnecessary skill listed as core in CLAUDE.md and README.  
**Recommendation:** Remove all references

### Issue 3: Overlay documentation completeness
**Severity:** LOW  
**Location:** docs/overlays/naumen-smp/  
**Description:** [Your findings about overlay structure]  
**Recommendation:** [Your suggestion]

## Audit Coverage
- ✅ `.doc-root.yaml` reviewed
- ✅ `content/` tree structure verified
- ✅ All markdown documentation scanned
- ✅ Overlay structure examined
```

Include the actual grep outputs in an appendix.

- [ ] **Step 8: Commit SA findings**

```bash
git add docs/audit/sa-findings.md
git commit -m "docs(audit): SA findings — structure and reference scan"
```

---

## **Task 2: Dev Audit — Scripts & Plugin Manifests (Subagent: Dev)**

**Files:**
- Scan (no modification): `scripts/init.sh`, `scripts/apply-overlay.sh`, `scripts/test-*.sh`, `.claude/settings.json`, `.claude/plugins/project-template/.claude-plugin/plugin.json`
- Create: `docs/audit/dev-findings.md`

- [ ] **Step 1: Audit `init.sh` — what gets replaced, what doesn't**

```bash
cat scripts/init.sh
```

Expected: Read through init.sh carefully. Note:
- Lines 36-44: only replace {{PROJECT_NAME}} in CLAUDE.md, AGENTS.md, README.md
- Lines 46-50: create branch 'private'
- Lines 52-56: copy .env.example → .env
- **ISSUE:** Does NOT replace `project-template@local` in `.claude/settings.json` or plugin.json

- [ ] **Step 2: Check what `apply-overlay.sh` does with placeholders**

```bash
cat scripts/apply-overlay.sh | grep -A5 -B5 "sed\|replace\|PROJECT_NAME"
```

Expected: Look for any placeholder replacement logic.

- [ ] **Step 3: Examine `.claude/settings.json`**

```bash
cat .claude/settings.json
```

Expected: JSON with `enabledPlugins` including `"project-template@local": true`. This is the problem — not replaced by init.sh.

- [ ] **Step 4: Examine plugin manifest at `.claude/plugins/project-template/.claude-plugin/plugin.json`**

```bash
cat .claude/plugins/project-template/.claude-plugin/plugin.json
```

Expected: JSON with `"name": "project-template"`. Should be universal `project` instead.

- [ ] **Step 5: Check for `correspondence-2` in plugin skills directory**

```bash
find .claude/plugins/project-template/skills -type f -name "*correspondence*" 2>/dev/null
# Also check if it's referenced in any skill manifest
grep -r "correspondence-2" .claude/plugins/project-template/ 2>/dev/null
```

Expected: Either find the skill directory or confirm it's only referenced in docs.

- [ ] **Step 6: Review smoke test coverage**

```bash
cat scripts/test-template.sh | head -50
# Check what tests are being run
```

Expected: Smoke test should verify that basic template structure is sound. Note what's being tested.

- [ ] **Step 7: Search for all hardcoded references to `project-template`**

```bash
grep -r "project-template" . --include="*.sh" --include="*.json" --include="*.yaml" 2>/dev/null | grep -v ".git" | grep -v "node_modules" | tee /tmp/dev-grep-project-template.txt
```

Expected: Comprehensive list of all non-git, non-node_modules occurrences.

- [ ] **Step 8: Write findings to `docs/audit/dev-findings.md`**

Create file with structure:

```markdown
# Dev Audit Findings — 2026-04-27

## Summary
- Scanned: All `.sh` scripts, `.json` configs, plugin manifests
- Scan date: 2026-04-27
- Issues found: [N] blocking, [M] important

## Issues

### Issue 1: Plugin name hardcoded in `.claude/settings.json` and `plugin.json`
**Severity:** BLOCKING  
**Location:** 
  - `.claude/settings.json` line X: `"project-template@local": true`
  - `.claude/plugins/project-template/.claude-plugin/plugin.json` line Y: `"name": "project-template"`  
**Description:** `init.sh` does NOT replace these hardcoded references when initializing new projects. This causes plugin name misalignment.  
**Recommendation:** Rename to universal `project@local` so all new projects use same plugin identifier.

### Issue 2: `init.sh` incomplete placeholder substitution
**Severity:** BLOCKING  
**Location:** `scripts/init.sh` lines 36-44  
**Description:** Script only replaces {{PROJECT_NAME}} in markdown files, not in JSON/YAML configs.  
**Recommendation:** Either (A) extend init.sh to replace in configs, or (B) rename plugin to universal `project@local` to avoid need for per-project replacement.

### Issue 3: Plugin manifest missing fields
**Severity:** LOW  
**Location:** `.claude/plugins/project-template/.claude-plugin/plugin.json`  
**Description:** [Any missing optional fields]  
**Recommendation:** [Suggestions]

### Issue 4: `correspondence-2` skill unclear applicability
**Severity:** MEDIUM  
**Location:** CLAUDE.md line 42, README.md lines 30, 41, possibly `skills/correspondence-2/`  
**Description:** Business letter skill listed as core but deemed unnecessary for template workflow.  
**Recommendation:** Remove from documentation and plugin config if directory exists.

## Smoke Test Coverage
- Test file: `scripts/test-template.sh`
- Current coverage: [Your summary of what's being tested]
- Gaps: [Any missing test scenarios]
```

Include grep outputs in appendix.

- [ ] **Step 9: Commit Dev findings**

```bash
git add docs/audit/dev-findings.md
git commit -m "docs(audit): Dev findings — scripts and plugin manifest scan"
```

---

## **Task 3: PM Aggregates Findings & Writes Consolidated Report (PM)**

**Files:**
- Read: `docs/audit/sa-findings.md`, `docs/audit/dev-findings.md`
- Create: `docs/audit/2026-04-27-template-audit.md`

- [ ] **Step 1: Read both audit reports**

```bash
cat docs/audit/sa-findings.md
cat docs/audit/dev-findings.md
```

Take notes on:
- Unique issues (found by only one agent)
- Overlapping issues (same problem found by both)
- Severity and confidence levels

- [ ] **Step 2: Create consolidated audit report structure**

```markdown
# Comprehensive Template Audit Report

**Date:** 2026-04-27  
**Conducted by:** SA (architecture), Dev (scripts), PM (aggregation)  
**Status:** Ready for implementation

## Executive Summary

The `project-template` repository has three critical issues that prevent it from serving as a true universal template:

1. **Plugin name hardcoded** — `project-template@local` baked into configs, preventing adaptation to new projects
2. **Incomplete placeholder system** — {{PROJECT_NAME}} substitution works for markdown but not for critical config files
3. **Dead skill dependency** — `correspondence-2` listed as core but deemed unnecessary, adding noise

**Overall assessment:** FIXABLE with low-risk changes. All issues are in config/documentation, not runtime code.

---

## SA Findings Summary

[Copy relevant sections from sa-findings.md, deduplicate with Dev findings]

---

## Dev Findings Summary

[Copy relevant sections from dev-findings.md, deduplicate with SA findings]

---

## Consolidated Issues by Category

### Category 1: Plugin Configuration
**Issues:**
- `project-template@local` in `.claude/settings.json`
- `"name": "project-template"` in plugin.json
- Not updated by `init.sh`

**Root cause:** Plugin naming was template-specific; should be universal.

**Fix approach:** Rename to `project@local` (universal) instead of `{PROJECT_NAME}@local` (per-project).

**Affected files:**
1. `.claude/settings.json`
2. `.claude/plugins/project-template/.claude-plugin/plugin.json`

### Category 2: Documentation References
**Issues:**
- README.md mentions `project-template@local` in context of plugin setup
- CLAUDE.md line 23 lists `project-template@local` in plugin list
- AGENTS.md may have similar references

**Fix approach:** Bulk replace `project-template@local` → `project@local`

**Affected files:**
1. README.md
2. CLAUDE.md
3. AGENTS.md
4. Any other docs referencing the plugin

### Category 3: Unnecessary Skill
**Issues:**
- `correspondence-2` listed in CLAUDE.md line 42 as core skill
- `correspondence-2` listed in README.md (lines 30, 41)
- Deemed unnecessary for template workflow

**Fix approach:** Remove all references

**Affected files:**
1. CLAUDE.md
2. README.md
3. Possibly `.claude/plugins/project-template/skills/correspondence-2/` (delete if exists)
4. Plugin manifest if it lists skills

---

## Implementation Checklist

### Phase 3A: Fix Plugin Naming

- [ ] Edit `.claude/settings.json`: replace `"project-template@local"` with `"project@local"`
- [ ] Edit `.claude/plugins/project-template/.claude-plugin/plugin.json`: change `"name": "project-template"` to `"name": "project"`
- [ ] Verify JSON syntax: `jq . .claude/settings.json` and `jq . .claude/plugins/project-template/.claude-plugin/plugin.json`
- [ ] Commit: "refactor(config): rename plugin to universal project@local"

### Phase 3B: Fix Documentation References

- [ ] Find-replace in README.md: `project-template@local` → `project@local`
- [ ] Find-replace in CLAUDE.md: `project-template@local` → `project@local`
- [ ] Find-replace in AGENTS.md: `project-template@local` → `project@local`
- [ ] Search for any other references: `grep -r "project-template@local" . --include="*.md" --include="*.yaml"`
- [ ] Commit: "docs: update plugin name references to project@local"

### Phase 3C: Remove correspondence-2

- [ ] Delete line from CLAUDE.md (currently line 42): `| Деловое письмо/сообщение | correspondence-2 |`
- [ ] Delete line from README.md: `- **Все:** для текстов — \`infoinstyle\`; для писем — \`correspondence-2\`; для многошаговых задач...`
- [ ] Search for directory: `ls -la .claude/plugins/project-template/skills/ | grep correspondence`
- [ ] If found, remove: `rm -rf .claude/plugins/project-template/skills/correspondence-2/`
- [ ] Commit: "refactor: remove unnecessary correspondence-2 skill"

### Phase 3D: Verify & Test

- [ ] Run smoke test: `bash scripts/test-template.sh`
- [ ] Expected output: `Template smoke test PASSED`
- [ ] Check git status: `git status` should show clean tree after commits
- [ ] Spot-check JSON: `jq . .claude/settings.json` (no errors)

### Phase 3E: Final Commit & Push

- [ ] Push to private: `git push origin private`
- [ ] Prepare message for public push (user reviews first with `/pm-review`)

---

## Verification Plan

### Test 1: Plugin Configuration Valid
```bash
jq . .claude/settings.json
jq . .claude/plugins/project-template/.claude-plugin/plugin.json
```
Expected: Both commands exit 0 with valid JSON output.

### Test 2: No References to Old Names
```bash
grep -r "project-template@local" . --include="*.md" --include="*.json" --include="*.yaml" 2>/dev/null | grep -v ".git"
```
Expected: No output (no matches).

### Test 3: Smoke Test Passes
```bash
bash scripts/test-template.sh
```
Expected: Exit code 0, final line says "Template smoke test PASSED".

### Test 4: Documentation Consistency
```bash
grep -r "correspondence-2" . --include="*.md" --include="*.json" 2>/dev/null | grep -v ".git"
```
Expected: No output (skill completely removed from docs).

---

## Rollback Plan

If smoke test fails or any issue arises:
```bash
git reset --hard HEAD~N  # N = number of commits to undo
git push origin private --force
```
Then diagnose and fix root cause.
```

- [ ] **Step 3: Insert actual SA findings into consolidated report**

Copy-paste the key issues from `docs/audit/sa-findings.md` into the "SA Findings Summary" section.

- [ ] **Step 4: Insert actual Dev findings into consolidated report**

Copy-paste the key issues from `docs/audit/dev-findings.md` into the "Dev Findings Summary" section.

- [ ] **Step 5: Save consolidated audit report**

Write the complete consolidated report to `docs/audit/2026-04-27-template-audit.md` (use Write tool).

- [ ] **Step 6: Commit consolidated report**

```bash
git add docs/audit/2026-04-27-template-audit.md
git commit -m "docs(audit): consolidated audit report with implementation checklist"
```

---

## **Task 4: PM Phase 3A — Fix Plugin Naming (PM)**

**Files:**
- Modify: `.claude/settings.json`
- Modify: `.claude/plugins/project-template/.claude-plugin/plugin.json`

- [ ] **Step 1: Read and validate current `.claude/settings.json`**

```bash
cat .claude/settings.json
jq . .claude/settings.json
```

Expected: Valid JSON with `enabledPlugins` containing `"project-template@local": true`.

- [ ] **Step 2: Edit `.claude/settings.json` — rename plugin**

Replace:
```json
{
  ...
  "enabledPlugins": {
    "gramax@ai-assistants": true,
    "superpowers@claude-plugins-official": true,
    "project-template@local": true
  }
}
```

With:
```json
{
  ...
  "enabledPlugins": {
    "gramax@ai-assistants": true,
    "superpowers@claude-plugins-official": true,
    "project@local": true
  }
}
```

Use Edit tool:

```bash
# Current content (before):
jq . .claude/settings.json
```

- [ ] **Step 3: Edit `.claude/plugins/project-template/.claude-plugin/plugin.json` — rename plugin**

Replace:
```json
{
  "name": "project-template",
  ...
}
```

With:
```json
{
  "name": "project",
  ...
}
```

- [ ] **Step 4: Validate both JSON files**

```bash
jq . .claude/settings.json && echo "✓ settings.json valid"
jq . .claude/plugins/project-template/.claude-plugin/plugin.json && echo "✓ plugin.json valid"
```

Expected: Both commands return 0 (no errors), files are syntactically valid.

- [ ] **Step 5: Commit configuration changes**

```bash
git add .claude/settings.json .claude/plugins/project-template/.claude-plugin/plugin.json
git commit -m "refactor(config): rename plugin to universal project@local"
```

---

## **Task 5: PM Phase 3B — Fix Documentation References (PM)**

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Modify: `AGENTS.md`

- [ ] **Step 1: Find all documentation references to `project-template@local`**

```bash
grep -r "project-template@local" README.md CLAUDE.md AGENTS.md docs/ 2>/dev/null
```

Expected: List of exact matches with line numbers (use grep -n).

- [ ] **Step 2: Replace in README.md**

Current (line ~41):
```markdown
- `project-template@local` — агенты PM/BA/SA/Dev/DevOps/Researcher + локальные скиллы CTO
```

New:
```markdown
- `project@local` — агенты PM/BA/SA/Dev/DevOps/Researcher + локальные скиллы CTO
```

Also check line ~3:
```markdown
- `project-template@local` — writer, comments-read, comments-write
```

Should become:
```markdown
- `project@local` — writer, comments-read, comments-write
```

Use Edit tool for each occurrence.

- [ ] **Step 3: Replace in CLAUDE.md**

Current (line 23):
```markdown
- **project-template@local** — агенты PM/BA/SA/Dev/DevOps/Researcher + локальные скиллы
```

New:
```markdown
- **project@local** — агенты PM/BA/SA/Dev/DevOps/Researcher + локальные скиллы
```

Use Edit tool.

- [ ] **Step 4: Replace in AGENTS.md**

Search for any occurrences of `project-template@local` and replace with `project@local`. Use Edit tool.

- [ ] **Step 5: Verify no remaining references**

```bash
grep -r "project-template@local" README.md CLAUDE.md AGENTS.md docs/ 2>/dev/null
```

Expected: No output (all replaced).

- [ ] **Step 6: Commit documentation changes**

```bash
git add README.md CLAUDE.md AGENTS.md
git commit -m "docs: update plugin name references to project@local"
```

---

## **Task 6: PM Phase 3C — Remove correspondence-2 (PM)**

**Files:**
- Modify: `CLAUDE.md`
- Modify: `README.md`
- Delete (if exists): `.claude/plugins/project-template/skills/correspondence-2/`

- [ ] **Step 1: Locate and remove from CLAUDE.md**

Current (line 42):
```markdown
| Деловое письмо/сообщение | correspondence-2 |
```

Delete this entire line from the table in CLAUDE.md.

Use Edit tool to remove the line.

- [ ] **Step 2: Locate and remove from README.md**

Current (around line 30):
```markdown
- **Все:** для текстов — `infoinstyle`; для писем — `correspondence-2`; для многошаговых задач — `superpowers:brainstorming`.
```

New:
```markdown
- **Все:** для текстов — `infoinstyle`; для многошаговых задач — `superpowers:brainstorming`.
```

Also check around line 41:
```markdown
- `project-template@local` — агенты PM/BA/SA/Dev/DevOps/Researcher + локальные скиллы CTO
```

May have reference to correspondence-2 in plugin description. Use Edit tool.

- [ ] **Step 3: Check for skill directory**

```bash
ls -la .claude/plugins/project-template/skills/ 2>/dev/null | grep correspondence
```

If `correspondence-2` directory exists:
```bash
rm -rf .claude/plugins/project-template/skills/correspondence-2/
```

If not found, skip this step.

- [ ] **Step 4: Verify removal complete**

```bash
grep -r "correspondence-2" README.md CLAUDE.md AGENTS.md .claude/plugins/ 2>/dev/null
```

Expected: No output (all removed).

- [ ] **Step 5: Commit removal**

```bash
git add README.md CLAUDE.md
# Also stage deleted directory if it existed:
git add .claude/plugins/project-template/skills/ 2>/dev/null || true
git commit -m "refactor: remove unnecessary correspondence-2 skill"
```

---

## **Task 7: PM Phase 3D — Verify & Test (PM)**

**Files:**
- No modifications; verification only

- [ ] **Step 1: Run smoke test**

```bash
bash scripts/test-template.sh
```

Expected output ends with: `Template smoke test PASSED`
Expected exit code: 0

If test fails, examine output for errors and fix the root cause (likely in previous tasks).

- [ ] **Step 2: Validate JSON syntax**

```bash
jq . .claude/settings.json && echo "✓ settings.json valid"
jq . .claude/plugins/project-template/.claude-plugin/plugin.json && echo "✓ plugin.json valid"
```

Expected: Both return 0 with "✓" messages.

- [ ] **Step 3: Check git status**

```bash
git status
```

Expected: Clean working tree or only expected commits listed.

- [ ] **Step 4: Verify old names completely gone**

```bash
grep -r "project-template@local" . --include="*.md" --include="*.json" --include="*.yaml" 2>/dev/null | grep -v ".git"
grep -r "correspondence-2" . --include="*.md" --include="*.json" 2>/dev/null | grep -v ".git"
```

Expected: No output for either grep.

---

## **Task 8: PM Phase 3E — Final Commit & Push (PM)**

**Files:**
- No new files; push existing commits

- [ ] **Step 1: Review all commits on current branch**

```bash
git log --oneline -10
```

Expected: Recent commits should include plugin rename, documentation updates, skill removal.

- [ ] **Step 2: Push to private branch**

```bash
git push origin private
```

Expected: Output shows commits pushed to `private` branch.

- [ ] **Step 3: Create summary for public push**

Prepare a message for user to review before `/pm-review` and merge to `public`. Message should include:
- What was changed (plugin name, removed skill, updated docs)
- Why (template universality, cleanup)
- Tests passed (smoke test output)

- [ ] **Step 4: Prepare for public merge**

User will trigger this via `/pm-review` or manual approval. Steps available if needed:
```bash
git checkout public
git merge private
git push origin public
```

---

## **Execution Path**

This plan is structured for **subagent-driven execution**:

1. **Task 1 & 2:** Dispatch to SA and Dev subagents in parallel
2. **Task 3:** PM aggregates findings (can start while subagents finish)
3. **Tasks 4–8:** PM executes sequentially (configuration, docs, testing, commit)

**Total estimated time:** 40–50 minutes including parallel audit phases.

---

## **Success Criteria Checklist**

- [ ] Both audit reports exist and are complete (`sa-findings.md`, `dev-findings.md`)
- [ ] Consolidated audit report created with checklist (`2026-04-27-template-audit.md`)
- [ ] All `project-template@local` replaced with `project@local` in configs and docs
- [ ] `correspondence-2` removed from all documentation
- [ ] Smoke test passes (`bash scripts/test-template.sh` → PASSED)
- [ ] JSON validation passes (jq succeeds on all modified files)
- [ ] All commits created with meaningful messages
- [ ] Push to `private` complete
- [ ] User reviews and approves before `public` push
