# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "pyyaml>=6.0",
# ]
# ///
"""_drift_check.py — drift-check algorithm for /pm-review.

Implements check_drift() function per design-spec §3c and parse_bypass_from_commits().

Usage (from pm-review.md):
    uv run scripts/_drift_check.py --changed-files <file1> <file2> ...
        --manifest docs/overlays/profiles/<name>/manifest.yaml
        [--bypass-reason "<reason>"]
"""
from __future__ import annotations

import argparse
import fnmatch
import subprocess
import sys
from pathlib import Path


def _matches_pattern(file_path: str, pattern: str) -> bool:
    """Returns True if file_path matches glob pattern.

    Pattern may end with '/' (directory prefix) or contain fnmatch wildcards.
    Examples:
        'content/30-requirements/' matches 'content/30-requirements/foo.md'
        'content/*-module-*/' matches 'content/10-module-01-intro/lesson.md'
        'src/' matches 'src/auth/login.py'
    """
    # Normalise trailing slash patterns to prefix match
    if pattern.endswith("/"):
        # Directory prefix — match any file under that prefix (supports fnmatch globs too)
        # Split pattern into directory part and match
        norm_path = file_path.replace("\\", "/")
        norm_pattern = pattern.rstrip("/")
        # If pattern has wildcards — use fnmatch on path prefix segments
        if "*" in norm_pattern or "?" in norm_pattern or "[" in norm_pattern:
            # Check each prefix of the path against the pattern
            parts = norm_path.split("/")
            for i in range(1, len(parts)):
                prefix = "/".join(parts[:i])
                if fnmatch.fnmatch(prefix, norm_pattern):
                    return True
            return False
        else:
            # Plain prefix check
            return norm_path.startswith(norm_pattern + "/") or norm_path == norm_pattern
    else:
        # Direct fnmatch
        return fnmatch.fnmatch(file_path, pattern)


def check_drift(
    changed_files: list[str],
    drift_pairs: list[dict] | None,
    bypass_reason: str | None = None,
) -> list[dict]:
    """Returns list of {"level": "WARN"|"INFO", "message": str} events.

    Algorithm per design-spec §3c:
    1. drift_pairs is None → INFO skip (absent from manifest)
    2. drift_pairs == [] → INFO skip (empty, e.g. custom profile)
    3. bypass_reason non-empty (after strip) → INFO bypass for each affected pair
    4. bypass_reason empty/whitespace-only → WARN about empty reason + proceed to check
    5. For each pair: if downstream changed AND upstream NOT changed → WARN
    """
    events: list[dict] = []

    # Step 1: drift_pairs absent
    if drift_pairs is None:
        events.append({
            "level": "INFO",
            "message": "no drift_pairs declared, skipping check",
        })
        return events

    # Step 2: drift_pairs empty list
    if len(drift_pairs) == 0:
        events.append({
            "level": "INFO",
            "message": "drift_pairs is empty (custom profile), skipping check",
        })
        return events

    # Step 3 & 4: Normalise bypass
    bypass_active = False
    bypass_reason_stripped: str | None = None
    if bypass_reason is not None:
        stripped = bypass_reason.strip()
        if stripped:
            bypass_active = True
            bypass_reason_stripped = stripped
        else:
            # Empty/whitespace-only bypass reason → WARN
            events.append({
                "level": "WARN",
                "message": "empty skip-drift reason — bypass ignored",
            })

    # Pre-compute matches for all pairs to support chain-change logic
    # A file that is a downstream of pair N but also an upstream of pair M
    # (and pair M's downstream is also changed) is considered "intentionally changed"
    # for the purpose of pair N — suppress WARN.
    pair_data = []
    for pair in drift_pairs:
        if not isinstance(pair, dict):
            pair_data.append(None)
            continue
        upstream_pattern = pair.get("upstream", "")
        downstream_pattern = pair.get("downstream", "")
        if not upstream_pattern or not downstream_pattern:
            pair_data.append(None)
            continue
        downstream_matched = [f for f in changed_files if _matches_pattern(f, downstream_pattern)]
        upstream_matched = [f for f in changed_files if _matches_pattern(f, upstream_pattern)]
        pair_data.append({
            "upstream_pattern": upstream_pattern,
            "downstream_pattern": downstream_pattern,
            "downstream_matched": downstream_matched,
            "upstream_matched": upstream_matched,
        })

    # Step 5: Check each pair
    for i, pd in enumerate(pair_data):
        if pd is None:
            continue
        upstream_pattern = pd["upstream_pattern"]
        downstream_pattern = pd["downstream_pattern"]
        downstream_matched = pd["downstream_matched"]
        upstream_matched = pd["upstream_matched"]

        if not downstream_matched:
            # No downstream changes — no issue
            continue

        if upstream_matched:
            # Both sides changed — no issue
            continue

        # Downstream changed but upstream not changed.
        # Chain-change suppression: if any of the downstream files ALSO appears as upstream
        # in another pair (pair M) where pair M's downstream IS also changed — suppress WARN.
        # This handles cases like domain→roles→runbooks where you update roles+runbooks together.
        suppressed_by_chain = False
        for j, other_pd in enumerate(pair_data):
            if j == i or other_pd is None:
                continue
            # Check if any downstream_matched file is an upstream in pair j
            other_up_pattern = other_pd["upstream_pattern"]
            for f in downstream_matched:
                if _matches_pattern(f, other_up_pattern):
                    # This file is also an upstream of pair j
                    # If pair j's downstream is also changed → suppress
                    if other_pd["downstream_matched"]:
                        suppressed_by_chain = True
                        break
            if suppressed_by_chain:
                break

        if suppressed_by_chain:
            continue

        # Downstream changed but upstream not changed
        if bypass_active and bypass_reason_stripped:
            events.append({
                "level": "INFO",
                "message": (
                    f"drift-check bypassed: {bypass_reason_stripped}. "
                    f"Pair {upstream_pattern}→{downstream_pattern} skipped."
                ),
            })
            continue

        # No valid bypass — emit WARN
        events.append({
            "level": "WARN",
            "message": (
                f"drift detected: {downstream_matched} changed without paired upstream "
                f"{upstream_pattern}. Fix upstream first, or add 'skip-drift: <reason>' "
                f"to commit message."
            ),
            "downstream_files": downstream_matched,
            "upstream_pattern": upstream_pattern,
            "downstream_pattern": downstream_pattern,
        })

    return events


def parse_bypass_from_commits(repo_path: str = ".", base_ref: str = "public") -> str | None:
    """Extract 'skip-drift: <reason>' trailer from commits between base_ref..HEAD.

    Primary format: trailer line 'skip-drift: <reason>' in any commit message.
    Fallback: 'Drift: skip — <reason>' line in last commit body.

    Returns the reason string, or None if no bypass found.
    """
    try:
        result = subprocess.run(
            ["git", "log", f"{base_ref}..HEAD", "--format=%B", "--"],
            cwd=repo_path,
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode != 0:
            return None
        log_body = result.stdout

        # Primary: skip-drift: <reason>
        for line in log_body.splitlines():
            stripped = line.strip()
            if stripped.startswith("skip-drift:"):
                reason = stripped[len("skip-drift:"):].strip()
                return reason  # may be empty string — caller validates

        # Fallback: "Drift: skip — <reason>"
        for line in log_body.splitlines():
            stripped = line.strip()
            if stripped.startswith("Drift: skip —") or stripped.startswith("Drift: skip -"):
                separator = "—" if "—" in stripped else "-"
                parts = stripped.split(separator, 1)
                if len(parts) == 2:
                    return parts[1].strip()

        return None

    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        return None


def _main(argv: list[str]) -> int:
    """CLI entry point for direct invocation from pm-review.md."""
    parser = argparse.ArgumentParser(description="drift-check for /pm-review")
    parser.add_argument("--changed-files", nargs="*", default=[], metavar="FILE",
                        help="List of changed files (from git diff --name-only)")
    parser.add_argument("--manifest", metavar="PATH",
                        help="Path to profile manifest.yaml with drift_pairs")
    parser.add_argument("--bypass-reason", default=None,
                        help="Bypass reason (from skip-drift: trailer)")
    parser.add_argument("--base-ref", default="public",
                        help="Git base ref for commit log parsing (default: public)")
    args = parser.parse_args(argv)

    drift_pairs: list[dict] | None = None

    if args.manifest:
        manifest_path = Path(args.manifest)
        if manifest_path.exists():
            try:
                import yaml  # type: ignore
                with open(manifest_path) as f:
                    manifest = yaml.safe_load(f)
                drift_pairs = manifest.get("drift_pairs")  # None if key absent
            except Exception as e:
                print(f"[WARN] Failed to parse manifest {args.manifest}: {e}", file=sys.stderr)
        else:
            print(f"[INFO] Manifest not found: {args.manifest} — skipping drift-check")
            return 0

    bypass = args.bypass_reason
    if bypass is None:
        bypass = parse_bypass_from_commits(base_ref=args.base_ref)

    events = check_drift(args.changed_files, drift_pairs, bypass)

    for event in events:
        level = event.get("level", "INFO")
        msg = event.get("message", "")
        print(f"[{level}] {msg}")

    # Always exit 0 — WARN is soft-fail (PM confirms before merge)
    return 0


if __name__ == "__main__":
    sys.exit(_main(sys.argv[1:]))
