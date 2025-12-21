#!/usr/bin/env python3
"""
Build all SlapOS components and software releases, tracking results.

Note: Run with PYTHONUNBUFFERED=1 for real-time output in Docker.

This script iterates through all components and software releases,
attempts to build each one, and generates a comprehensive report
with individual build logs.

Usage:
    # Build all components
    ./scripts/build_all.py components

    # Build all software releases
    ./scripts/build_all.py software

    # Build everything
    ./scripts/build_all.py all

    # Build with a timeout per component (in seconds)
    ./scripts/build_all.py components --timeout 600

    # Resume from a specific component (skip already built)
    ./scripts/build_all.py components --resume-from redis
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional

# Project root
ROOT = Path(__file__).parent.parent.absolute()
COMPONENT_DIR = ROOT / "component"
SOFTWARE_DIR = ROOT / "software"
BUILD_DIR = ROOT / "build"
LOGS_DIR = BUILD_DIR / "logs"
REPORTS_DIR = BUILD_DIR / "reports"


def list_available(base_dir: Path) -> list[str]:
    """List available components or software releases."""
    items = []
    for item in sorted(base_dir.iterdir()):
        if item.is_dir() and not item.name.startswith("."):
            # Check if it has a buildout.cfg or software.cfg
            if (item / "buildout.cfg").exists() or (item / "software.cfg").exists():
                items.append(item.name)
    return items


def ensure_dirs():
    """Ensure log and report directories exist."""
    LOGS_DIR.mkdir(parents=True, exist_ok=True)
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)


def build_item(
    item_type: str, name: str, timeout: int, log_dir: Path
) -> dict:
    """
    Build a single component or software release.

    Returns a dict with build results.
    """
    log_file = log_dir / f"{name}.log"

    start_time = datetime.now()
    result = {
        "name": name,
        "type": item_type,
        "start_time": start_time.isoformat(),
        "success": False,
        "return_code": None,
        "duration_seconds": None,
        "log_file": str(log_file),
        "error_summary": None,
    }

    cmd = [
        sys.executable,
        str(ROOT / "scripts" / "build.py"),
        item_type,
        name,
    ]

    print(f"  Building {name}...", end=" ", flush=True)

    try:
        with open(log_file, "w") as log:
            log.write(f"=== Build log for {item_type}: {name} ===\n")
            log.write(f"Started: {start_time.isoformat()}\n")
            log.write(f"Command: {' '.join(cmd)}\n")
            log.write("=" * 60 + "\n\n")
            log.flush()

            proc = subprocess.run(
                cmd,
                stdout=log,
                stderr=subprocess.STDOUT,
                timeout=timeout,
                cwd=str(ROOT),
            )

            result["return_code"] = proc.returncode
            result["success"] = proc.returncode == 0

    except subprocess.TimeoutExpired:
        result["return_code"] = -1
        result["error_summary"] = f"Timeout after {timeout} seconds"
        with open(log_file, "a") as log:
            log.write(f"\n\n=== TIMEOUT after {timeout} seconds ===\n")

    except Exception as e:
        result["return_code"] = -2
        result["error_summary"] = str(e)
        with open(log_file, "a") as log:
            log.write(f"\n\n=== ERROR: {e} ===\n")

    end_time = datetime.now()
    duration = (end_time - start_time).total_seconds()
    result["duration_seconds"] = duration
    result["end_time"] = end_time.isoformat()

    # Try to extract error summary from log if build failed
    if not result["success"] and not result["error_summary"]:
        result["error_summary"] = extract_error_summary(log_file)

    # Append end marker to log
    with open(log_file, "a") as log:
        log.write(f"\n\n{'=' * 60}\n")
        log.write(f"Finished: {end_time.isoformat()}\n")
        log.write(f"Duration: {duration:.1f} seconds\n")
        log.write(f"Success: {result['success']}\n")
        log.write(f"Return code: {result['return_code']}\n")

    # Print result
    if result["success"]:
        print(f"OK ({duration:.1f}s)")
    else:
        print(f"FAILED ({duration:.1f}s)")
        if result["error_summary"]:
            # Print first line of error summary
            first_line = result["error_summary"].split("\n")[0][:60]
            print(f"    Error: {first_line}...")

    return result


def extract_error_summary(log_file: Path, max_lines: int = 10) -> Optional[str]:
    """Extract error summary from build log."""
    try:
        with open(log_file, "r") as f:
            content = f.read()

        # Look for common error patterns
        lines = content.split("\n")

        # Find lines with "Error:" or "error:" or traceback
        error_lines = []
        in_traceback = False

        for i, line in enumerate(lines):
            if "Traceback (most recent call last):" in line:
                in_traceback = True
            if in_traceback:
                error_lines.append(line)
                if line.strip() and not line.startswith(" ") and i > 0:
                    # End of traceback
                    break
            elif "Error:" in line or "error:" in line.lower():
                # Get some context
                start = max(0, i - 2)
                error_lines = lines[start:i + 3]
                break

        if error_lines:
            return "\n".join(error_lines[-max_lines:])

        # Fall back to last N non-empty lines
        non_empty = [l for l in lines if l.strip() and not l.startswith("===")]
        return "\n".join(non_empty[-max_lines:])

    except Exception:
        return None


def generate_report(
    results: list[dict],
    item_type: str,
    report_dir: Path,
    timestamp: str,
) -> Path:
    """Generate build report."""
    # Summary counts
    total = len(results)
    success = sum(1 for r in results if r["success"])
    failed = total - success

    # Sort results: failures first, then by name
    sorted_results = sorted(results, key=lambda r: (r["success"], r["name"]))

    # Generate text report
    report_file = report_dir / f"{item_type}_report_{timestamp}.txt"

    with open(report_file, "w") as f:
        f.write(f"{'=' * 70}\n")
        f.write(f"SlapOS Build Report - {item_type.upper()}\n")
        f.write(f"Generated: {datetime.now().isoformat()}\n")
        f.write(f"{'=' * 70}\n\n")

        f.write(f"SUMMARY\n")
        f.write(f"-" * 40 + "\n")
        f.write(f"Total:   {total}\n")
        f.write(f"Success: {success} ({100*success/total:.1f}%)\n")
        f.write(f"Failed:  {failed} ({100*failed/total:.1f}%)\n")
        f.write("\n")

        # Failed builds
        if failed > 0:
            f.write(f"FAILED BUILDS ({failed})\n")
            f.write(f"-" * 40 + "\n")
            for r in sorted_results:
                if not r["success"]:
                    duration = r.get("duration_seconds", 0)
                    f.write(f"  {r['name']:<40} ({duration:.1f}s)\n")
                    if r.get("error_summary"):
                        # Indent error summary
                        for line in r["error_summary"].split("\n")[:3]:
                            f.write(f"    | {line[:65]}\n")
                    f.write(f"    Log: {r['log_file']}\n")
                    f.write("\n")

        # Successful builds
        if success > 0:
            f.write(f"\nSUCCESSFUL BUILDS ({success})\n")
            f.write(f"-" * 40 + "\n")
            for r in sorted_results:
                if r["success"]:
                    duration = r.get("duration_seconds", 0)
                    f.write(f"  {r['name']:<40} ({duration:.1f}s)\n")

        f.write(f"\n{'=' * 70}\n")
        f.write(f"Logs directory: {LOGS_DIR / item_type}_{timestamp}\n")
        f.write(f"{'=' * 70}\n")

    # Also save JSON report for programmatic access
    json_file = report_dir / f"{item_type}_report_{timestamp}.json"
    with open(json_file, "w") as f:
        json.dump({
            "type": item_type,
            "timestamp": timestamp,
            "summary": {
                "total": total,
                "success": success,
                "failed": failed,
            },
            "results": sorted_results,
        }, f, indent=2)

    return report_file


def build_all(
    item_type: str,
    items: list[str],
    timeout: int,
    resume_from: Optional[str] = None,
) -> list[dict]:
    """Build all items of a given type."""
    ensure_dirs()

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_dir = LOGS_DIR / f"{item_type}_{timestamp}"
    log_dir.mkdir(parents=True, exist_ok=True)

    print(f"\n{'=' * 60}")
    print(f"Building all {item_type} ({len(items)} total)")
    print(f"Logs: {log_dir}")
    print(f"Timeout: {timeout} seconds per item")
    print(f"{'=' * 60}\n")

    results = []
    skip = resume_from is not None

    for i, name in enumerate(items, 1):
        # Handle resume
        if skip:
            if name == resume_from:
                skip = False
            else:
                print(f"[{i}/{len(items)}] Skipping {name} (resuming from {resume_from})")
                continue

        print(f"[{i}/{len(items)}] ", end="")
        result = build_item(item_type, name, timeout, log_dir)
        results.append(result)

    # Generate report
    report_file = generate_report(results, item_type, REPORTS_DIR, timestamp)

    # Print summary
    success = sum(1 for r in results if r["success"])
    failed = len(results) - success

    print(f"\n{'=' * 60}")
    print(f"BUILD COMPLETE")
    print(f"  Success: {success}/{len(results)}")
    print(f"  Failed:  {failed}/{len(results)}")
    print(f"  Report:  {report_file}")
    print(f"{'=' * 60}\n")

    return results


def main():
    parser = argparse.ArgumentParser(
        description="Build all SlapOS components and software releases",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "target",
        choices=["components", "software", "all"],
        help="What to build",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=1800,
        help="Timeout per item in seconds (default: 1800 = 30 minutes)",
    )
    parser.add_argument(
        "--resume-from",
        type=str,
        help="Resume from a specific item (skip items before it)",
    )
    parser.add_argument(
        "--only",
        type=str,
        help="Only build items matching this pattern (comma-separated)",
    )

    args = parser.parse_args()

    all_results = []

    if args.target in ("components", "all"):
        items = list_available(COMPONENT_DIR)
        if args.only:
            patterns = [p.strip() for p in args.only.split(",")]
            items = [i for i in items if any(p in i for p in patterns)]
        results = build_all("component", items, args.timeout, args.resume_from)
        all_results.extend(results)

    if args.target in ("software", "all"):
        items = list_available(SOFTWARE_DIR)
        if args.only:
            patterns = [p.strip() for p in args.only.split(",")]
            items = [i for i in items if any(p in i for p in patterns)]
        results = build_all("software", items, args.timeout, args.resume_from)
        all_results.extend(results)

    # Exit with error if any builds failed
    failed = sum(1 for r in all_results if not r["success"])
    return 1 if failed > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
