# SA Audit Findings — 2026-04-27

## Summary

- **Scanned:** `.doc-root.yaml`, `content/` full tree, `docs/overlays/`, CLAUDE.md, AGENTS.md, README.md
- **Scan date:** 2026-04-27
- **Issues found:** 3 (1 HIGH, 2 MEDIUM)
- **Status:** All issues identified; recommendations documented for PM/Dev phases

---

## Issues

### Issue 1: Hardcoded `project-template@local` in configuration and documentation

**Severity:** HIGH

**Location:**
- `.claude/settings.json` line 19: `"project-template@local": true`
- `.claude/plugins/project-template/.claude-plugin/plugin.json` line 1: `"name": "project-template"`
- CLAUDE.md line 23: `- **project-template@local** — агенты PM/BA/SA/Dev/DevOps/Researcher + локальные скиллы...`
- AGENTS.md line 1: `# AGENTS.md — {{PROJECT_NAME}}`
- README.md line 41: `- project-template@local — агенты PM/BA/SA/Dev/DevOps/Researcher + локальные скиллы CTO`

**Description:**
The plugin name `project-template@local` is hardcoded in:
1. `.claude/settings.json` enabledPlugins map
2. `.claude/plugins/project-template/` directory structure (not a placeholder)
3. Documentation (CLAUDE.md, README.md)

This prevents the template from being properly instantiated for new projects. When `init.sh` substitutes `{{PROJECT_NAME}}`, it does NOT update the plugin name in `.claude/settings.json` or the physical plugin directory. This causes:
- Plugin reference mismatch between config and actual directory structure
- Documentation becoming stale after instantiation
- Users unable to rename the plugin for their specific project

**Recommendation:**
1. Rename `project-template@local` → `project@local` universally (more generic for template reuse)
2. Update `.claude/settings.json` to use the universal name
3. Update documentation to reflect the universal plugin name
4. Consider making plugin directory/name parameterizable in `init.sh` for future instances

---

### Issue 2: `correspondence-2` skill listed as core dependency

**Severity:** MEDIUM

**Location:**
- CLAUDE.md line 42: `| Деловое письмо/сообщение | correspondence-2 |`
- README.md line 30: `- **Все:** для текстов — infoinstyle; для писем — correspondence-2; для многошаговых задач — superpowers:brainstorming.`
- README.md line 53: `CTO-скиллы (infoinstyle, correspondence-2): /Users/mdemyanov/Documents/naumen-cto/.claude/skills/.`

**Description:**
The `correspondence-2` skill (business letter/messaging writing) is listed in CLAUDE.md and README.md as a core team skill. However, per audit plan specs, this skill is deemed:
- Not essential to the canonical template workflow (Researcher → BA → SA → Dev → DevOps)
- Niche use case (business correspondence) not critical for template initialization
- Adding unnecessary cognitive load to developers reading onboarding docs

The skill exists in `.claude/plugins/project-template/skills/correspondence-2/` directory with full implementation (SKILL.md, references, assets, scripts), but its inclusion in team-wide guidelines creates noise.

**Recommendation:**
1. Remove `correspondence-2` from CLAUDE.md skill table (line 42)
2. Remove references from README.md lines 30 and 53
3. Optionally: Keep the skill directory in place for projects that need it (backward compatibility), but remove from core documentation
4. If removing entirely, delete `.claude/plugins/project-template/skills/correspondence-2/` directory

---

### Issue 3: Incomplete property definitions in `.doc-root.yaml`

**Severity:** MEDIUM

**Location:** `content/.doc-root.yaml` lines 1-30

**Description:**
The `.doc-root.yaml` file defines required properties (Тип контента, Фаза, Статус) for all markdown files in `content/`, but:
1. No README-level documentation on HOW to apply these properties to new articles
2. The template articles in `content/00-project/`, `content/30-requirements/`, etc. do not include examples of properly formatted YAML frontmatter
3. New users following the template may miss the requirement to include properties in their markdown files

This is a **documentation/guidance issue** rather than a structural issue. The validation mechanism exists, but onboarding is incomplete.

**Recommendation:**
1. Add a quick-reference section in `content/README.md` showing example YAML frontmatter for new articles
2. Ensure one example article in each major content area (00-project, 30-requirements, 40-architecture, 60-implementation) includes complete YAML frontmatter with all required properties
3. Link from CLAUDE.md "Красные линии" (line 49) to property reference

---

## Audit Coverage

- ✅ `.doc-root.yaml` reviewed — valid schema with required properties (Тип контента, Фаза, Статус)
- ✅ `content/` tree structure verified — 7 markdown files found in correct layout (00-project, 10-domain, 30-requirements, 40-architecture, 60-implementation, 70-operations)
- ✅ `docs/overlays/naumen-smp/` examined — valid overlay structure with README, patches, and property extensions
- ✅ All markdown documentation scanned for hardcoded references
- ✅ Configuration files checked (`.claude/settings.json`, `plugin.json`)
- ✅ Plugin directory structure validated

---

## Appendix: Raw Grep Output

### `project-template@local` references

From `/tmp/sa-grep-project-template.txt` (filtered to non-plan-document entries):

```
CLAUDE.md:23:- **project-template@local** — агенты PM/BA/SA/Dev/DevOps/Researcher + локальные скиллы (`infoinstyle`, `correspondence-2`)
README.md:41:- `project-template@local` — агенты PM/BA/SA/Dev/DevOps/Researcher + локальные скиллы CTO
```

Configuration file:
```
.claude/settings.json:19:    "project-template@local": true
```

### `correspondence-2` references

From `/tmp/sa-grep-correspondence.txt` (filtered to non-plan-document entries):

```
CLAUDE.md:42:| Деловое письмо/сообщение | `correspondence-2` |
README.md:30:- **Все:** для текстов — `infoinstyle`; для писем — `correspondence-2`; для многошаговых задач — `superpowers:brainstorming`.
README.md:53:- CTO-скиллы (infoinstyle, correspondence-2): `/Users/mdemyanov/Documents/naumen-cto/.claude/skills/`. При обновлении: `cp -R <src> .claude/plugins/project-template/skills/<name>/`.
```

Skill directory exists:
```
.claude/plugins/project-template/skills/correspondence-2/SKILL.md
.claude/plugins/project-template/skills/correspondence-2/references/karepina-method.md
.claude/plugins/project-template/skills/correspondence-2/scripts/README.md
.claude/plugins/project-template/skills/correspondence-2/assets/examples-email.md
.claude/plugins/project-template/skills/correspondence-2/assets/examples-messenger.md
```

### Placeholder issues

No stale placeholders found (only `{{PROJECT_NAME}}` which is expected and properly managed).

---

## Next Steps (PM Phase)

Per the implementation plan, PM should address findings in this order:

1. **Phase 3A:** Fix `project-template@local` → `project@local` globally (requires `/dev` implementation for init.sh changes)
2. **Phase 3B:** Remove `correspondence-2` from core documentation (edit CLAUDE.md, README.md)
3. **Phase 3C:** Document property requirements in content/ (SA review + example creation)

All issues are actionable and do not block template usage, but should be resolved before wide distribution to other teams.
