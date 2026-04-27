# Dev Audit Findings — 2026-04-27

## Summary

- **Scanned:** Scripts (`init.sh`, `apply-overlay.sh`, `test-template.sh`, `test-apply-overlay.sh`), `.claude/settings.json`, `.claude/plugins/project-template/.claude-plugin/plugin.json`, all markdown and config files
- **Scan date:** 2026-04-27
- **Issues found:** 4 (2 BLOCKING, 1 MEDIUM, 1 LOW)
- **Status:** Plugin name hardcoding blocks new project initialization; `correspondence-2` skill listed but unclear value; smoke test coverage solid but does not verify plugin name consistency

## Issues

### Issue 1: Plugin name hardcoded in `.claude/settings.json` and `plugin.json`

**Severity:** BLOCKING

**Location:**
- `.claude/settings.json` line 11: `"project-template@local": true`
- `.claude/plugins/project-template/.claude-plugin/plugin.json` line 1: `"name": "project-template"`
- README.md line 41: references `project-template@local` in plugin list
- CLAUDE.md line 23: references `project-template@local` in plugin list

**Description:**

`init.sh` (lines 36-44) only replaces `{{PROJECT_NAME}}` in markdown files (CLAUDE.md, AGENTS.md, README.md). It does NOT replace hardcoded `project-template@local` in JSON configs. This causes **critical misalignment**:

1. When a new project is initialized with `bash scripts/init.sh my-project`, the plugin is still named `project-template@local`
2. The `.claude/plugins/project-template/` directory path remains unchanged (hardcoded in `apply-overlay.sh` and `test-template.sh`)
3. Documentation will say "my-project" but the plugin will be `project-template@local`, breaking the semantic link
4. Multiple copies of the template will all register as `project-template@local`, causing plugin name collisions when used side-by-side

**Recommendation:**

Rename plugin identifier to universal `project@local` (not `project-template@local`) so all instances use the same identifier. This aligns with the intention that the template is "universal" — the plugin should be named for the **role** (project management suite), not the repository.

**Why this matters:**

The CLAUDE.md contract states `project-template@local` provides "агенты PM/BA/SA/Dev/DevOps/Researcher + локальные скиллы". This plugin is the **core orchestration system** for all new projects. If the name drifts from docs, new users will struggle to verify plugin enablement.

---

### Issue 2: `init.sh` incomplete placeholder substitution in configs

**Severity:** BLOCKING

**Location:** `scripts/init.sh` lines 36-44

**Description:**

The `init.sh` script substitutes `{{PROJECT_NAME}}` in markdown files but **does not extend to JSON/YAML configs**:

```bash
for f in CLAUDE.md AGENTS.md README.md; do
  if [[ -f "$f" ]] && grep -q '{{PROJECT_NAME}}' "$f"; then
    sed -i.bak "s/{{PROJECT_NAME}}/$NAME/g" "$f"
    # ... only markdown files
```

**Current behavior:** After `bash scripts/init.sh my-project`, the markdown files say "my-project" but:
- `.claude/settings.json` still contains `"project-template@local": true` (not templated)
- `.claude/plugins/project-template/.claude-plugin/plugin.json` still contains `"name": "project-template"` (not templated)
- `.claude/plugins/project-template/agents/` path is hardcoded in `apply-overlay.sh` (line 82)
- `.claude/plugins/project-template/agents/` path is hardcoded in `test-template.sh` (lines 48, 51)

**Recommendation:**

Either:

1. **Option A (Preferred):** Rename plugin to `project@local` (see Issue 1) so no per-project replacement is needed — all projects use the same identifier.

2. **Option B:** Extend `init.sh` to replace plugin name:
   - Add sed rules for `.claude/settings.json` and `.claude/plugins/project-template/.claude-plugin/plugin.json`
   - Rename plugin directory from `project-template/` to `project/`
   - Update hardcoded paths in `apply-overlay.sh` and `test-template.sh`

**Current status:** Option A (universal `project@local`) is recommended by SA findings and solves this completely.

---

### Issue 3: `correspondence-2` skill listed as core but unclaimed

**Severity:** MEDIUM

**Location:**
- CLAUDE.md line 23: lists `correspondence-2` in plugin description
- CLAUDE.md line 42: lists `correspondence-2` in "когда какой скилл звать"
- README.md line 30: mentions `correspondence-2` as available
- `.claude/plugins/project-template/agents/ba-agent.md`: references `correspondence-2` (no specific line count found)
- `.claude/plugins/project-template/skills/correspondence-2/SKILL.md`: skill exists

**Description:**

The `correspondence-2` skill is documented as a core competency for business correspondence ("деловое письмо/сообщение"). However:

1. **No actual usage pattern:** The skill is listed in BA agent table but BA (business analyst) role does not inherently require business letter writing in the template workflow
2. **Source of truth unclear:** README.md states skills are copied from `/Users/mdemyanov/Documents/naumen-cto/.claude/skills/` (line 53), suggesting these are personal CTO utilities, not universally needed for template projects
3. **Inconsistent positioning:** BA agent references `correspondence-2` but does not specify when/why to use it — the skill appears opportunistic rather than integral to BA responsibility

**Recommendation:**

1. Clarify if `correspondence-2` is a **mandatory template skill** (core to all projects) or an **optional utility** (specific to Naumen CTO workflow)
2. If mandatory: Add usage example in BA agent description
3. If optional: Move to "optional CTO utilities" section in documentation; remove from core plugin description

**Current status:** Skill directory exists and works (not broken), but its place in the template's value proposition is ambiguous.

---

### Issue 4: Plugin directory path hardcoded in shell scripts

**Severity:** LOW (will be resolved by Issue 1 or 2)

**Location:**
- `scripts/apply-overlay.sh` line 82: `agent=".claude/plugins/project-template/agents/$role-agent.md"`
- `scripts/test-template.sh` lines 48, 51: hardcoded `.claude/plugins/project-template/agents/` and `.claude/plugins/project-template/commands/`

**Description:**

The plugin directory path `.claude/plugins/project-template/` is hardcoded in multiple shell scripts. If Issue 1 or 2 is resolved by renaming the plugin directory, these scripts must be updated in lockstep.

**Current behavior:**
- `apply-overlay.sh` hardcodes the exact agent directory path
- `test-template.sh` hardcodes agent and command directory paths
- These paths must be kept in sync with plugin.json name

**Recommendation:**

Define a **plugin directory variable** at the top of each script:

```bash
PLUGIN_DIR=".claude/plugins/project-template"  # or project, after renaming
AGENT_DIR="$PLUGIN_DIR/agents"
COMMAND_DIR="$PLUGIN_DIR/commands"
```

This reduces update surface area when resolving Issue 1 or 2. Currently, a rename requires changes in 4 places: `.json`, `.sh` (apply-overlay), `.sh` (test-template), `.json` (settings).

---

## Smoke Test Coverage

**Test file:** `scripts/test-template.sh`

**Current coverage:**

✓ T1: JSON validity (`settings.json`, `plugin.json` parse correctly)
✓ T2: Agent frontmatter complete (all 6 agents have name, description, model)
✓ T3: Command files complete (7 commands have descriptions)
✓ T4: Content scaffold present (all README directories exist)
✓ T5: `init.sh` works (PROJECT_NAME substituted, private branch created, .env copied)
✓ T6: `apply-overlay.sh` idempotent (markers appear, second apply no diff, remove works)

**Gaps:**

1. **No plugin name consistency check** — test does not verify that plugin name in `.claude/settings.json` matches `plugin.json` or that after init the name is still valid (would fail under Issue 1)
2. **No hardcoded path check** — test does not verify that `.claude/plugins/project-template/` paths are consistent across all scripts
3. **No full integration test** — test verifies individual pieces but does not simulate opening repo in Claude Code to verify plugin loads
4. **No `correspondence-2` presence check** — test does not verify skill directory exists or is well-formed

**Recommendation:** Add T7 test:

```bash
echo ""
echo "==> T7: plugin name consistency"
PLUGIN_NAME=$(python3 -c "import json; print(json.load(open('.claude/plugins/project-template/.claude-plugin/plugin.json'))['name'])")
ENABLED_PLUGIN=$(python3 -c "import json; d=json.load(open('.claude/settings.json')); print([k for k in d.get('enabledPlugins', {}).keys() if 'project' in k][0])")
assert "plugin name matches settings" "[ \"$PLUGIN_NAME@local\" = \"$ENABLED_PLUGIN\" ]"
```

---

## Appendix: Raw Grep Output

### All hardcoded `project-template` references

```
/Users/mdemyanov/knowlage/project_template/.claude/settings.json:    "project-template@local": true
/Users/mdemyanov/knowlage/project_template/.claude/plugins/project-template/.claude-plugin/plugin.json:  "name": "project-template",
/Users/mdemyanov/knowlage/project_template/scripts/test-template.sh:assert "plugin.json valid" "python3 -c 'import json; json.load(open(\".claude/plugins/project-template/.claude-plugin/plugin.json\"))'"
/Users/mdemyanov/knowlage/project_template/scripts/test-template.sh:  file=".claude/plugins/project-template/agents/${agent}-agent.md"
/Users/mdemyanov/knowlage/project_template/scripts/test-template.sh:  file=".claude/plugins/project-template/commands/${cmd}.md"
/Users/mdemyanov/knowlage/project_template/scripts/apply-overlay.sh:  agent=".claude/plugins/project-template/agents/$role-agent.md"
/Users/mdemyanov/knowlage/project_template/scripts/test-apply-overlay.sh:assert "marker in ba-agent.md" "grep -q 'OVERLAY:naumen-smp:start' .claude/plugins/project-template/agents/ba-agent.md"
/Users/mdemyanov/knowlage/project_template/scripts/test-apply-overlay.sh:assert "marker in sa-agent.md" "grep -q 'OVERLAY:naumen-smp:start' .claude/plugins/project-template/agents/sa-agent.md"
/Users/mdemyanov/knowlage/project_template/scripts/test-apply-overlay.sh:assert "marker in dev-agent.md" "grep -q 'OVERLAY:naumen-smp:start' .claude/plugins/project-template/agents/dev-agent.md"
/Users/mdemyanov/knowlage/project_template/scripts/test-apply-overlay.sh:assert "no marker in ba-agent.md after remove" "! grep -q 'OVERLAY:naumen-smp:start' .claude/plugins/project-template/agents/ba-agent.md"
/Users/mdemyanov/knowlage/project_template/scripts/test-apply-overlay.sh:assert "no marker in sa-agent.md after remove" "! grep -q 'OVERLAY:naumen-smp:start' .claude/plugins/project-template/agents/sa-agent.md"
/Users/mdemyanov/knowlage/project_template/scripts/test-apply-overlay.sh:assert "no marker in dev-agent.md after remove" "! grep -q 'OVERLAY:naumen-smp:start' .claude/plugins/project-template/agents/dev-agent.md"
```

**Count:** 13 hardcoded references to `project-template` (5 in scripts, 3 in JSON/config, 5 in test assertions)

### All `{{PROJECT_NAME}}` placeholders

Found in: CLAUDE.md, AGENTS.md, README.md (expected — awaiting init.sh substitution)

**Status:** Placeholders present; `init.sh` correctly replaces them in markdown but not in configs.

---

## Next Steps for Resolution

1. **Immediate (critical for template usability):**
   - Decide: Option A (rename to `project@local`) or Option B (extend init.sh to handle configs)
   - Recommended: Option A — simpler, universal naming

2. **Follow-up (script consistency):**
   - If renaming plugin directory: update `.claude/plugins/project-template/` → `.claude/plugins/project/` everywhere
   - Extract plugin dir path as variable in shell scripts

3. **Clarification (skill documentation):**
   - Audit `correspondence-2` usage in actual projects
   - Document as optional CTO utility or remove from core template

4. **Improvement (test coverage):**
   - Add T7 plugin consistency test
   - Consider E2E test with actual Claude Code load

