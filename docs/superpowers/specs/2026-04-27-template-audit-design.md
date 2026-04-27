# Design: Comprehensive Template Audit & Refactoring

**Date:** 2026-04-27  
**Status:** Design Review  
**Scope:** Full audit of project-template + planned fixes for plugin naming and skill cleanup

---

## **Problem Statement**

The `project-template` repository serves as a foundation for starting new internal projects with Gramax documentation and an AI-agent team structure. Three critical issues have been identified:

1. **Hardcoded plugin name:** `project-template@local` is baked into `.claude/settings.json` and `plugin.json`. When `init.sh` substitutes `{{PROJECT_NAME}}` in documentation, it does NOT update these config references, causing plugin misalignment.
2. **Incomplete placeholder substitution:** Only `{{PROJECT_NAME}}` gets replaced in `CLAUDE.md`, `AGENTS.md`, and `README.md`. References to `project-template@local` in docs and comments remain stale.
3. **Unused skill dependency:** `correspondence-2` (business letter writing) is listed as a core skill in CLAUDE.md and README but is deemed unnecessary for the template's actual workflow.

**Success Criteria:**
- All references to `project-template@local` replaced with universal `project@local`
- `correspondence-2` removed from all documentation and plugin manifests
- Audit report completed with recommendations and consolidated checklist
- Smoke tests pass post-fix
- All changes committed and pushed to `private` and `public` branches

---

## **Solution Architecture**

### **Parallel Audit (Phase 1)**

Two specialized subagents conduct independent audits and write findings:

**SA Audit (Architecture & Structure):**
- Scans: `.doc-root.yaml`, `content/` structure, `CLAUDE.md`, `AGENTS.md`, all overlays (`docs/overlays/`)
- Checks:
  - Property consistency against `.doc-root.yaml` schema
  - Dangling references to `project-template@local` in markdown, YAML, JSON
  - Overlay applicability and documentation
  - ADR structure and completeness
- Output: `docs/audit/sa-findings.md` (markdown list of issues + recommendations)

**Dev Audit (Scripts & Testing):**
- Scans: `scripts/init.sh`, `scripts/apply-overlay.sh`, `scripts/test-*.sh`, `plugin.json`, `settings.json`
- Checks:
  - `init.sh` logic: what gets replaced, what doesn't, edge cases
  - `apply-overlay.sh` correctness and idempotency
  - Smoke test coverage
  - Plugin manifest correctness (name, version, author fields)
  - Unused skills/commands still referenced in code
- Output: `docs/audit/dev-findings.md` (markdown list of issues + recommendations)

### **Consolidated Report & Implementation (Phase 2)**

PM aggregates findings into a single audit report with consolidated recommendations and a prioritized implementation checklist:

**Output artifact:** `docs/audit/2026-04-27-template-audit.md`

Sections:
1. Executive Summary
2. SA Findings (formatted + deduplicated)
3. Dev Findings (formatted + deduplicated)
4. Consolidated Issues by Category (config, docs, skills, scripts)
5. Recommendations & Trade-offs
6. Implementation Checklist (step-by-step)
7. Verification Plan (how to test each fix)

### **Batch Implementation (Phase 3)**

PM executes all fixes from checklist:

**Changes:**
1. Rename plugin: `project-template@local` → `project@local` in:
   - `.claude/settings.json` (enabledPlugins + plugin reference)
   - `.claude/plugins/project-template/.claude-plugin/plugin.json` (name field)
   - All references in CLAUDE.md, AGENTS.md, README.md, docs/

2. Remove `correspondence-2` skill:
   - Delete from CLAUDE.md (line 42)
   - Delete from README.md (lines 30, 41)
   - Remove from `.claude/plugins/project-template/skills/` (if exists)
   - Update plugin manifest if needed

3. Verify & test:
   - `bash scripts/test-template.sh` → expect PASSED
   - Spot-check `.claude/settings.json` JSON syntax
   - Git status clean

4. Commit & push:
   - Single atomic commit with message describing all changes
   - Push to `private` branch
   - Merge to `public` (or user triggers via `/pm-review`)

---

## **Data Flow**

```
PM creates initial checklist
  ↓
[Parallel execution]
├─ SA subagent → scans structure → sa-findings.md
└─ Dev subagent → scans scripts → dev-findings.md
  ↓
PM aggregates findings
  ↓
2026-04-27-template-audit.md
  ↓
PM batch-implements from checklist
  ↓
test-template.sh passes
  ↓
git commit + push private + push public
```

---

## **Definitions of Done**

✅ Both audit reports (SA, Dev) exist and are readable  
✅ Consolidated audit report written with recommendations  
✅ All config/doc references to `project-template@local` replaced with `project@local`  
✅ `correspondence-2` completely removed from template  
✅ `bash scripts/test-template.sh` exits with code 0 (PASSED)  
✅ Git commit created with meaningful message  
✅ Push to `private` complete  
✅ User reviews and approves before push to `public`  

---

## **Risks & Mitigations**

| Risk | Impact | Mitigation |
|------|--------|-----------|
| SA and Dev audit findings conflict | Incorrect recommendations | PM reviews conflicts before batch-fix, prioritizes by severity |
| Plugin rename breaks existing projects | User confusion | Clearly document change in CHANGELOG/Release Notes post-implementation |
| Smoke test fails after fixes | Regression | Test before final commit, revert if needed |
| Incomplete file discovery during audit | Missed stale references | SA/Dev do second-pass grep for "project-template" and "correspondence-2" |

---

## **Success Metrics**

- Audit report completeness: ≥95% of codebase scanned
- Fix accuracy: 100% of identified issues addressed or explicitly deferred with reason
- Test coverage: smoke test PASSED post-implementation
- Documentation clarity: audit report is actionable by any future maintainer

---

## **Timeline & Effort**

- **Phase 1 (Audit):** 2 parallel subagent runs (SA + Dev) — ~10-15 min
- **Phase 2 (Report):** PM aggregates, writes recommendations — ~10 min
- **Phase 3 (Implementation):** Batch fixes, test, commit — ~15 min
- **Total:** ~40 min, mostly parallel

---

## **Open Questions**

None — ready for implementation.

---

**Next Step:** User review of this design document. If approved, transition to `/writing-plans` for detailed implementation plan.
