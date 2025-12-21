#!/usr/bin/env python3
"""
Standalone build script for SlapOS components and software releases.

This script allows building SlapOS components without the full SlapOS infrastructure.
It uses buildout directly, bypassing the SlapOS Master/Node architecture.

Usage:
    # Build a single component
    ./scripts/build.py component redis

    # Build a software release (Phase 1 only - compilation)
    ./scripts/build.py software abilian-sbe

    # List available components
    ./scripts/build.py list components

    # List available software releases
    ./scripts/build.py list software
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Optional

# Project root
ROOT = Path(__file__).parent.parent.absolute()
COMPONENT_DIR = ROOT / "component"
SOFTWARE_DIR = ROOT / "software"
BUILD_DIR = ROOT / "build"


def find_buildout_cfg(base_dir: Path, name: str) -> Optional[Path]:
    """Find the buildout.cfg file for a component or software."""
    target_dir = base_dir / name
    if not target_dir.exists():
        return None

    # Try common names
    for cfg_name in ["buildout.cfg", "software.cfg"]:
        cfg_path = target_dir / cfg_name
        if cfg_path.exists():
            return cfg_path

    return None


def list_available(base_dir: Path) -> list[str]:
    """List available components or software releases."""
    items = []
    for item in sorted(base_dir.iterdir()):
        if item.is_dir() and not item.name.startswith("."):
            # Check if it has a buildout.cfg or software.cfg
            if (item / "buildout.cfg").exists() or (item / "software.cfg").exists():
                items.append(item.name)
    return items


def create_standalone_buildout_cfg(cfg_path: Path, output_dir: Path) -> Path:
    """
    Create a standalone buildout.cfg that wraps the target config
    with settings suitable for standalone building.
    """
    output_dir.mkdir(parents=True, exist_ok=True)

    # Calculate relative path from output_dir to cfg_path
    rel_cfg_path = os.path.relpath(cfg_path, output_dir)

    standalone_cfg = output_dir / "buildout.cfg"

    # Shared parts directory for slapos.recipe.cmmi shared builds
    shared_parts_dir = BUILD_DIR / "shared-parts"
    shared_parts_dir.mkdir(parents=True, exist_ok=True)

    # Clean eggs directory to avoid collision errors from previous builds
    # This fixes: OSError: [Errno 39] Directory not empty when os.rename()
    # tries to move an egg that already exists from a previous failed build
    eggs_dir = output_dir / "eggs"
    if eggs_dir.exists():
        for item in eggs_dir.iterdir():
            if item.name.startswith("tmp") or item.name.endswith(".egg"):
                try:
                    if item.is_dir():
                        shutil.rmtree(item)
                    else:
                        item.unlink()
                except OSError:
                    pass

    content = f"""\
[buildout]
extends = {rel_cfg_path}

# Override SlapOS-specific settings for standalone build
parts-directory = ${{buildout:directory}}/parts
develop-eggs-directory = ${{buildout:directory}}/develop-eggs
eggs-directory = ${{buildout:directory}}/eggs
bin-directory = ${{buildout:directory}}/bin

# Shared parts directory for slapos.recipe.cmmi (used by shared=true)
shared-parts = {shared_parts_dir}

# Disable SlapOS extensions that require infrastructure
extensions =

# Allow picking versions if not pinned (for flexibility)
allow-picked-versions = true

# Disable network cache (build from source)
# To enable, uncomment and configure:
# networkcache-section = networkcache

# Use standard PyPI
index = https://pypi.org/simple/

# Increase verbosity
verbosity = 1
"""

    standalone_cfg.write_text(content)
    return standalone_cfg


def run_buildout(cfg_path: Path, output_dir: Path) -> int:
    """Run buildout with the given configuration."""
    # Ensure buildout and common recipes are available
    required_packages = [
        "zc.buildout",
        "slapos.recipe.cmmi",
        "slapos.recipe.build",
        "slapos.recipe.template",
        "plone.recipe.command",
        "collective.recipe.template",
    ]

    print("Ensuring required packages are installed...")
    for pkg in required_packages:
        try:
            subprocess.run(
                [sys.executable, "-m", "pip", "show", pkg],
                check=True,
                capture_output=True,
            )
        except subprocess.CalledProcessError:
            print(f"  Installing {pkg}...")
            subprocess.run(
                [sys.executable, "-m", "pip", "install", pkg, "-q"],
                check=True,
            )

    # Create standalone config
    standalone_cfg = create_standalone_buildout_cfg(cfg_path, output_dir)

    print(f"Building with config: {cfg_path}")
    print(f"Output directory: {output_dir}")
    print(f"Standalone config: {standalone_cfg}")
    print("-" * 60)

    # Run buildout
    env = os.environ.copy()
    env["HOME"] = str(output_dir)  # Isolate buildout cache

    # Try to find buildout executable
    buildout_bin = output_dir / "bin" / "buildout"
    if not buildout_bin.exists():
        # Use the buildout command from PATH or venv
        buildout_cmd = shutil.which("buildout")
        if buildout_cmd:
            buildout_bin = Path(buildout_cmd)
        else:
            # Fall back to running buildout module differently
            print("Installing buildout in build directory...")
            subprocess.run(
                [sys.executable, "-m", "pip", "install", "zc.buildout", "-q"],
                cwd=str(output_dir),
                env=env,
            )
            buildout_cmd = shutil.which("buildout")
            if buildout_cmd:
                buildout_bin = Path(buildout_cmd)
            else:
                print("Error: Could not find buildout command")
                return 1

    result = subprocess.run(
        [str(buildout_bin), "-c", str(standalone_cfg)],
        cwd=str(output_dir),
        env=env,
    )

    return result.returncode


def cmd_build_component(args):
    """Build a single component."""
    cfg_path = find_buildout_cfg(COMPONENT_DIR, args.name)
    if not cfg_path:
        print(f"Error: Component '{args.name}' not found or has no buildout.cfg")
        print(f"Available components: {', '.join(list_available(COMPONENT_DIR)[:10])}...")
        return 1

    output_dir = BUILD_DIR / "components" / args.name
    return run_buildout(cfg_path, output_dir)


def cmd_build_software(args):
    """Build a software release (Phase 1 only)."""
    cfg_path = find_buildout_cfg(SOFTWARE_DIR, args.name)
    if not cfg_path:
        print(f"Error: Software release '{args.name}' not found")
        print(f"Available software: {', '.join(list_available(SOFTWARE_DIR)[:10])}...")
        return 1

    output_dir = BUILD_DIR / "software" / args.name
    return run_buildout(cfg_path, output_dir)


def cmd_list(args):
    """List available components or software releases."""
    if args.type == "components":
        items = list_available(COMPONENT_DIR)
        print(f"Available components ({len(items)}):")
    elif args.type == "software":
        items = list_available(SOFTWARE_DIR)
        print(f"Available software releases ({len(items)}):")
    else:
        print(f"Unknown type: {args.type}")
        return 1

    for item in items:
        print(f"  - {item}")
    return 0


def main():
    parser = argparse.ArgumentParser(
        description="Standalone build script for SlapOS components and software releases",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    subparsers = parser.add_subparsers(dest="command", help="Command to run")

    # component command
    comp_parser = subparsers.add_parser("component", help="Build a component")
    comp_parser.add_argument("name", help="Component name (e.g., redis, postgresql)")
    comp_parser.set_defaults(func=cmd_build_component)

    # software command
    soft_parser = subparsers.add_parser("software", help="Build a software release")
    soft_parser.add_argument("name", help="Software name (e.g., abilian-sbe, gitlab)")
    soft_parser.set_defaults(func=cmd_build_software)

    # list command
    list_parser = subparsers.add_parser("list", help="List available items")
    list_parser.add_argument(
        "type", choices=["components", "software"], help="What to list"
    )
    list_parser.set_defaults(func=cmd_list)

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 1

    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
