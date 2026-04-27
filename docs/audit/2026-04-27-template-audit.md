# Comprehensive Template Audit Report

**Date:** 2026-04-27  
**Conducted by:** SA (architecture audit), Dev (scripts audit), PM (aggregation)  
**Status:** Ready for implementation  
**Branch:** `private`

---

## Executive Summary

The `project-template` repository serves as the foundation for starting new internal projects with Gramax documentation and AI-agent team structure. The audit identified **4 actionable issues** that prevent the template from functioning as a true universal scaffold:

### Critical Findings:

1. **Plugin name hardcoded** (BLOCKING) — `project-template@local` baked into `.claude/settings.json` and plugin manifest. When `init.sh` initializes new projects, it doesn't update these config references, creating plugin name misalignment.

2. **Incomplete placeholder substitution** (BLOCKING) — `init.sh` replaces `{{PROJECT_NAME}}` in markdown docs but NOT in JSON/YAML configs, leaving initialized projects with stale plugin names.

3. **Unnecessary skill in core docs** (MEDIUM) — `correspondence-2` (business letter writing) listed as core in CLAUDE.md/README despite being peripheral to the canonical template workflow.

4. **Hardcoded plugin paths in scripts** (LOW) — Shell scripts hardcode `.claude/plugins/project-template/` paths in multiple places, creating update surface area.

### Overall Assessment:

**FIXABLE with LOW RISK.** All issues are in configuration and documentation; no runtime code changes required. Primary fix: rename plugin to `project@local` (universal identifier).

---

## SA Audit Summary

**Scanned:** `.doc-root.yaml`, `content/` full tree, `docs/overlays/`, CLAUDE.md, AGENTS.md, README.md

**Issues Found:** 3 (1 HIGH, 2 MEDIUM)

### Issue SA-1: Hardcoded `project-template@local` in configuration

**Severity:** HIGH

**Locations:**
- `.claude/settings.json` line 19: `"project-template@local": true`
- `.claude/plugins/project-template/.claude-plugin/plugin.json` line 1: `"name": "project-template"`
- CLAUDE.md line 23: `- **project-template@local** — агенты PM/BA/SA/Dev/DevOps/Researcher + локальные скиллы`
- README.md line 41: `- project-template@local — агенты...`

**Impact:** Plugin reference mismatch between config and actual directory structure after template instantiation.

**Recommendation:** Rename globally to `project@local` (universal name for all template instances).

---

### Issue SA-2: `correspondence-2` skill listed as core

**Severity:** MEDIUM

**Locations:**
- CLAUDE.md line 42: `| Деловое письмо/сообщение | correspondence-2 |`
- README.md line 30: "для писем — correspondence-2"
- README.md line 53: references CTO skill source
- `.claude/plugins/project-template/skills/correspondence-2/` directory exists

**Impact:** Business letter skill adds noise to core documentation; unclear if mandatory or optional.

**Recommendation:** Remove from CLAUDE.md and README (keep skill directory for backward compatibility).

---

### Issue SA-3: Incomplete property documentation in `.doc-root.yaml`

**Severity:** MEDIUM

**Location:** `content/.doc-root.yaml` + missing guidance

**Impact:** Required properties (Тип контента, Фаза, Статус) defined but not documented with examples.

**Recommendation:** Add quick-reference in `content/README.md` with YAML frontmatter examples.

---

## Dev Audit Summary

**Scanned:** Scripts, `.claude/settings.json`, plugin manifest, configs

**Issues Found:** 4 (2 BLOCKING, 1 MEDIUM, 1 LOW)

### Issue DEV-1: Plugin name hardcoded in `.claude/settings.json` and `plugin.json`

**Severity:** BLOCKING

**Locations:**
- `.claude/settings.json` line 11: `"project-template@local": true`
- `.claude/plugins/project-template/.claude-plugin/plugin.json` line 1: `"name": "project-template"`

**Impact:** When `bash scripts/init.sh my-project` is run, markdown files show "my-project" but plugin remains `project-template@local`, breaking semantic alignment. Multiple template instances create plugin name collisions.

**Recommendation:** Rename to `project@local` (universal identifier).

---

### Issue DEV-2: `init.sh` incomplete config substitution

**Severity:** BLOCKING

**Location:** `scripts/init.sh` lines 36-44

**Impact:** Markdown files get {{PROJECT_NAME}} replaced but JSON/YAML configs don't, leaving initialized projects broken.

**Recommendation:** Either rename plugin to `project@local` (no substitution needed) or extend `init.sh` to handle all file types.

---

### Issue DEV-3: `correspondence-2` skill unclear value

**Severity:** MEDIUM

**Locations:**
- CLAUDE.md line 23, 42
- README.md line 30, 53
- `.claude/plugins/project-template/skills/correspondence-2/` exists

**Impact:** Skill is documented as core but has no explicit usage pattern in template workflow; appears copied from external CTO utilities.

**Recommendation:** Clarify if mandatory (add usage example) or optional (move to utilities section). Current status: ambiguous.

---

### Issue DEV-4: Plugin directory hardcoded in shell scripts

**Severity:** LOW

**Locations:**
- `scripts/apply-overlay.sh` line 82
- `scripts/test-template.sh` lines 48, 51
- `scripts/test-apply-overlay.sh` lines (multiple)

**Impact:** 13 hardcoded references to `project-template` across scripts. If plugin is renamed, all must be updated in lockstep.

**Recommendation:** Extract as variable: `PLUGIN_DIR=".claude/plugins/project-template"` at script top.

---

## Consolidated Issues by Category

### Category 1: Plugin Configuration (BLOCKING)

**Root cause:** Plugin naming is template-specific instead of universal.

**Affected files:**
1. `.claude/settings.json` — enabledPlugins map
2. `.claude/plugins/project-template/.claude-plugin/plugin.json` — name field
3. `scripts/init.sh` — needs update to handle configs
4. `scripts/apply-overlay.sh` — hardcoded path
5. `scripts/test-template.sh` — hardcoded path
6. `scripts/test-apply-overlay.sh` — hardcoded path

**Fix approach:** Rename `project-template@local` → `project@local` universally.

**Impact:** All new projects will use same plugin identifier; no per-instance substitution needed.

---

### Category 2: Documentation References (HIGH)

**Root cause:** Hardcoded plugin name in user-facing docs.

**Affected files:**
1. CLAUDE.md — lines 23 (plugin list)
2. README.md — lines 41, 53 (plugin list + CTO skills source)
3. AGENTS.md — check for references

**Fix approach:** Bulk replace `project-template@local` → `project@local`.

**Impact:** Docs remain accurate after template instantiation.

---

### Category 3: Unnecessary Skill (MEDIUM)

**Root cause:** Business letter skill included as core template dependency.

**Affected files:**
1. CLAUDE.md — line 42 (skill table)
2. README.md — lines 30, 53 (skill list + source reference)
3. `.claude/plugins/project-template/skills/correspondence-2/` — skill directory

**Fix approach:** Remove from documentation; keep skill directory for backward compatibility.

**Impact:** Cleaner onboarding; reduces noise in core guidelines.

---

## Implementation Checklist

### Phase 1: Plugin Configuration Fix

- [ ] Edit `.claude/settings.json`: replace `"project-template@local"` with `"project@local"`
- [ ] Edit `.claude/plugins/project-template/.claude-plugin/plugin.json`: change `"name": "project-template"` to `"name": "project"`
- [ ] Validate JSON: `jq . .claude/settings.json .claude/plugins/project-template/.claude-plugin/plugin.json`
- [ ] Commit: `git commit -m "refactor(config): rename plugin to universal project@local"`

### Phase 2: Documentation Updates

- [ ] Replace in README.md: `project-template@local` → `project@local` (2 locations)
- [ ] Replace in CLAUDE.md: `project-template@local` → `project@local` (1 location)
- [ ] Replace in AGENTS.md: check for references and update
- [ ] Verify: `grep -r "project-template@local" . --include="*.md" --include="*.json" 2>/dev/null | grep -v ".git"` (expect 0 results)
- [ ] Commit: `git commit -m "docs: update plugin name references to project@local"`

### Phase 3: Remove correspondence-2

- [ ] Delete from CLAUDE.md line 42: `| Деловое письмо/сообщение | correspondence-2 |`
- [ ] Edit README.md line 30: remove "для писем — correspondence-2"
- [ ] Edit README.md line 53: remove "correspondence-2" from CTO skills list
- [ ] Verify: `grep -r "correspondence-2" . --include="*.md" --include="*.json" 2>/dev/null | grep -v ".git"` (expect 0 results)
- [ ] Commit: `git commit -m "refactor: remove unnecessary correspondence-2 skill from core documentation"`

### Phase 4: Test & Verify

- [ ] Run smoke test: `bash scripts/test-template.sh`
- [ ] Expected: `Template smoke test PASSED` (exit code 0)
- [ ] Verify JSON syntax: `jq . .claude/settings.json && jq . .claude/plugins/project-template/.claude-plugin/plugin.json`
- [ ] Verify no old references: `grep -r "project-template@local\|correspondence-2" . --include="*.md" --include="*.json" 2>/dev/null | grep -v ".git"` (expect 0)
- [ ] Git status: `git status` (expect clean tree after commits)

### Phase 5: Push to private & Prepare for public

- [ ] Review commits: `git log --oneline -10`
- [ ] Push to private: `git push origin private`
- [ ] Prepare summary for `/pm-review` before public merge
- [ ] Summary should include: what changed (plugin rename, skill removal), why (template universality), test results

---

## Verification & Testing Plan

### Test 1: JSON Configuration Validity

```bash
jq . .claude/settings.json && echo "✓ settings.json valid"
jq . .claude/plugins/project-template/.claude-plugin/plugin.json && echo "✓ plugin.json valid"
```

**Expected:** Both commands exit 0.

---

### Test 2: No References to Old Names

```bash
grep -r "project-template@local" . --include="*.md" --include="*.json" --include="*.yaml" 2>/dev/null | grep -v ".git"
```

**Expected:** No output (all replaced).

---

### Test 3: No correspondence-2 References

```bash
grep -r "correspondence-2" . --include="*.md" --include="*.json" 2>/dev/null | grep -v ".git"
```

**Expected:** No output (completely removed from docs).

---

### Test 4: Smoke Test Passes

```bash
bash scripts/test-template.sh
```

**Expected:** Exit code 0, final line: `Template smoke test PASSED`.

---

## Rollback Plan

If any test fails:

```bash
git log --oneline -5  # Identify commits to undo
git reset --hard HEAD~N  # N = number of commits to undo
git push origin private --force
```

Then diagnose root cause and fix before re-applying.

---

## Timeline & Effort

| Phase | Task | Est. Time | Owner |
|-------|------|-----------|-------|
| 1 | SA Audit | 15 min | SA subagent |
| 2 | Dev Audit | 15 min | Dev subagent |
| 3 | PM Aggregates | 10 min | PM |
| 4 | Fix Plugin Config | 5 min | PM |
| 5 | Update Docs | 5 min | PM |
| 6 | Remove correspondence-2 | 3 min | PM |
| 7 | Test & Verify | 5 min | PM |
| 8 | Push to private | 2 min | PM |
| **Total** | | **~50 min** | |

---

## Success Criteria (GO-No-GO Checklist)

✅ Both audit reports exist and are complete (`sa-findings.md`, `dev-findings.md`)  
✅ Consolidated audit report created with checklist  
✅ All `project-template@local` replaced with `project@local` in configs and docs  
✅ `correspondence-2` removed from all documentation  
✅ Smoke test passes: `bash scripts/test-template.sh` → PASSED  
✅ JSON validation passes: `jq .` on modified files → 0 errors  
✅ All commits created with meaningful messages  
✅ Push to `private` branch complete  
✅ User reviews and approves before push to `public`  

---

## Appendix: Combined Issue Summary

| ID | Issue | Severity | Category | Owner | Status |
|--|--|--|--|--|--|
| SA-1 / DEV-1 | Plugin hardcoded | BLOCKING | Config | PM Phase 1 | Ready |
| DEV-2 | init.sh incomplete | BLOCKING | Scripts | PM Phase 2 | Ready |
| SA-2 / DEV-3 | correspondence-2 core | MEDIUM | Docs | PM Phase 3 | Ready |
| SA-3 | Property guidance missing | MEDIUM | Docs | SA (post-audit) | Deferred |
| DEV-4 | Hardcoded paths | LOW | Scripts | PM (refactor) | Deferred |

**Priority for this audit:** BLOCKING + MEDIUM issues (SA-1/DEV-1, DEV-2, SA-2/DEV-3)  
**Deferred for future:** SA-3 (property guidance), DEV-4 (script refactor)

---

## Next Steps

1. PM Phase 1-4: Execute implementation checklist (Phases 1-5 above)
2. User review & approval before push to `public`
3. Post-implementation: Consider SA-3 (property examples) and DEV-4 (script refactor) for next iteration

---

*Report Generated: 2026-04-27*  
*Audit conducted by SA and Dev subagents with PM coordination*
