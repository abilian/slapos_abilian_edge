# Docker Build System for SlapOS Components

This document describes how to build SlapOS components and software releases using Docker, independently of Nexedi's infrastructure.

## Prerequisites

- Docker and Docker Compose installed
- The repository cloned locally

## Quick Start

```bash
# Build the Docker image
docker compose build

# Build a single component
docker compose run --rm build-component component xz-utils

# Build a software release
docker compose run --rm build-software software abilian-sbe

# List available components
docker compose run --rm build-component list components

# List available software releases
docker compose run --rm build-component list software
```

## Architecture

The build system uses:

- **Nexedi's forked zc.buildout** (3.0.1+slapos010) - Required because standard buildout doesn't work with most SlapOS components
- **Pinned dependencies** - setuptools 67.8.0, pip 23.2.1 for compatibility
- **Named Docker volumes** - To persist build artifacts and avoid macOS bind mount issues

### Docker Services

| Service | Purpose |
|---------|---------|
| `slapos-build` | Base service, shows help |
| `build-component` | Build individual components |
| `build-software` | Build software releases |
| `build-all` | Build all components/software with reporting |

### Volume Structure

```
slapos-build/           # Named volume for build artifacts
├── components/         # Built components
│   └── <name>/
│       ├── parts/      # Compiled artifacts
│       ├── eggs/       # Python eggs
│       └── bin/        # Executables
├── software/           # Built software releases
├── shared-parts/       # Shared components (for shared=true)
├── logs/               # Build logs
│   └── component_<timestamp>/
│       └── <name>.log
└── reports/            # Build reports
    ├── component_report_<timestamp>.txt
    └── component_report_<timestamp>.json
```

## Building Individual Components

```bash
# Basic usage
docker compose run --rm build-component component <name>

# Examples
docker compose run --rm build-component component xz-utils
docker compose run --rm build-component component redis
docker compose run --rm build-component component postgresql

# Using docker directly (without compose)
docker run --rm slapos-build python scripts/build.py component xz-utils
```

## Building Software Releases

```bash
# Basic usage
docker compose run --rm build-software software <name>

# Examples
docker compose run --rm build-software software abilian-sbe
```

## Building All Components/Software

The `build-all` service attempts to build everything and generates reports.

### Commands

```bash
# Build all components
docker compose run --rm build-all components

# Build all software releases
docker compose run --rm build-all software

# Build everything (components + software)
docker compose run --rm build-all all
```

### Options

```bash
# Custom timeout per component (default: 1800 seconds = 30 minutes)
docker compose run --rm build-all components --timeout 600

# Build only specific items (comma-separated patterns)
docker compose run --rm build-all components --only redis,postgres,xz

# Resume from a specific component (skip items before it)
docker compose run --rm build-all components --resume-from redis
```

### Output

**Reports** are generated in two formats:

1. **Text report** (`component_report_<timestamp>.txt`):
   - Human-readable summary
   - Failed builds listed first with error excerpts
   - Successful builds with duration

2. **JSON report** (`component_report_<timestamp>.json`):
   - Machine-readable for scripting
   - Full details including timestamps, durations, log paths

**Logs** are stored per-component:
- Path: `/slapos/build/logs/<type>_<timestamp>/<name>.log`
- Contains full build output, timestamps, and error details

## Viewing Results

### List Reports

```bash
docker run --rm -v slapos_abilian_edge_slapos-build:/slapos/build \
  slapos-build ls -la /slapos/build/reports/
```

### View a Report

```bash
docker run --rm -v slapos_abilian_edge_slapos-build:/slapos/build \
  slapos-build cat /slapos/build/reports/component_report_<timestamp>.txt
```

### View a Component Log

```bash
docker run --rm -v slapos_abilian_edge_slapos-build:/slapos/build \
  slapos-build cat /slapos/build/logs/component_<timestamp>/<name>.log
```

### Verify Built Binaries

```bash
# Check xz-utils
docker run --rm -v slapos_abilian_edge_slapos-build:/slapos/build \
  slapos-build /slapos/build/components/xz-utils/parts/xz-utils/bin/xz --version

# Check redis
docker run --rm -v slapos_abilian_edge_slapos-build:/slapos/build \
  slapos-build /slapos/build/components/redis/parts/redis/bin/redis-server --version
```

## Managing Volumes

### List Volumes

```bash
docker volume ls | grep slapos
```

### Clear Build Artifacts

```bash
# Remove the build volume (clears all built components)
docker volume rm slapos_abilian_edge_slapos-build

# Remove all project volumes
docker compose down -v
```

### Inspect Volume Contents

```bash
docker run --rm -v slapos_abilian_edge_slapos-build:/slapos/build \
  slapos-build ls -la /slapos/build/
```

## Monitoring Long Builds

When running `build-all` on many components, use these commands to monitor progress:

```bash
# Watch real-time output (shows component completions)
docker logs -f $(docker ps -q --filter ancestor=slapos_abilian_edge-build-all)

# Count completed components
docker exec $(docker ps -q --filter ancestor=slapos_abilian_edge-build-all) \
  sh -c "ls /slapos/build/logs/component_*/*.log 2>/dev/null | wc -l"

# See latest log files
docker exec $(docker ps -q --filter ancestor=slapos_abilian_edge-build-all) \
  sh -c "ls -lt /slapos/build/logs/component_*/*.log | head -10"

# View current component's build output
docker exec $(docker ps -q --filter ancestor=slapos_abilian_edge-build-all) \
  sh -c "tail -30 \$(ls -t /slapos/build/logs/component_*/*.log | head -1)"

# Check if build is still running
docker ps --filter ancestor=slapos_abilian_edge-build-all
```

## Troubleshooting

### Package Not Found Errors

If you see errors like `pkg_resources.DistributionNotFound: The 'zc.buildout' distribution was not found`, rebuild the Docker image:

```bash
docker compose build --no-cache
```

This re-applies the package name normalization fix (pip registers packages with hyphens/underscores, but SlapOS code expects dotted names).

### Build Timeout

Increase the timeout for complex components:

```bash
docker compose run --rm build-all components --timeout 3600  # 1 hour
```

### macOS File System Errors

If you see errors like `error deallocating ... Invalid argument`, ensure you're using named volumes (not bind mounts) for the build directory. The default docker-compose.yml configuration handles this.

### Missing Dependencies

Some components depend on others. If a build fails with missing dependencies, try building the dependency first:

```bash
# Example: redis depends on patch and tcl
docker compose run --rm build-component component patch
docker compose run --rm build-component component tcl
docker compose run --rm build-component component redis
```

### Viewing Detailed Errors

Check the component log for full error details:

```bash
# Find the latest log directory
docker run --rm -v slapos_abilian_edge_slapos-build:/slapos/build \
  slapos-build ls -lt /slapos/build/logs/ | head -5

# View the failing component's log
docker run --rm -v slapos_abilian_edge_slapos-build:/slapos/build \
  slapos-build cat /slapos/build/logs/component_<timestamp>/<name>.log
```

## Technical Details

### Why Nexedi's Buildout Fork?

SlapOS uses a heavily customized version of `zc.buildout` that includes:
- Custom egg handling
- Network cache integration
- Shared parts support
- SlapOS-specific extensions

Most components will not build with upstream buildout.

### Package Name Normalization

Modern pip normalizes package names (e.g., `zc.buildout` → `zc-buildout`), but SlapOS code expects dotted names. The Dockerfile includes two fixes:

1. **dist-info directory renaming**: Renames directories like `zc_buildout-*.dist-info` to `zc.buildout-*.dist-info` so `pkg_resources` can find them.

2. **buildout `_get_matching_dist_in_location` patch**: Fixes the wheel verification function in `zc/buildout/easy_install.py` to normalize package names before comparison. Without this patch, buildout fails with `AssertionError` when verifying wheels for packages like `zope.interface` (installed as `zope-interface` by pip).

### Pinned Versions

The build environment pins:
- `setuptools==67.8.0` - Newer versions removed `pkg_resources.package_index`
- `pip==23.2.1` - Newer versions removed `pip._vendor.six`

These are required for compatibility with Nexedi's buildout fork.

## Known Issues and Fixes

### gnu-config Download URL (Fixed)

The original `gnu-config` component used a Savannah snapshot URL that returns HTTP 400 errors. This has been fixed to use a GitHub mirror:
- Old URL: `https://cgit.git.savannah.gnu.org/cgit/config.git/snapshot/config-*.tar.gz`
- New URL: `https://github.com/arthenica/gnu-config/archive/*.tar.gz`

Many components depend on `gnu-config`, so this fix enables building of ~20+ additional components.

### Buildout/pkg_resources Name Normalization Bug (Fixed)

PEP 503 name normalization causes mismatches between dotted package names and wheel metadata:
- Buildout/pkg_resources expects: `zope.interface` (dotted name)
- Pip installs wheels with: `zope-interface` (normalized name)

This affects multiple places in the build system:
1. **Buildout `_get_matching_dist_in_location`**: Wheel verification fails
2. **pkg_resources `Environment.best_match`**: Can't find installed packages
3. **pkg_resources `Requirement.__contains__`**: Version conflict detection fails

The Dockerfile applies two patches:
1. **Buildout patch**: Modifies `easy_install.py` to normalize names during wheel verification
2. **sitecustomize.py patch**: Monkeypatches `pkg_resources` to normalize names in Environment lookups, best_match, and requirement containment checks

See `notes/build-debugging-report.md` for full technical details.

### System Dependencies

Some components require system libraries not included in minimal Docker images. The Dockerfile includes common build dependencies:
- `gfortran` - Required by OpenBLAS, numpy, scipy, and scientific Python packages
- `libasound2-dev` - Required by audio-related components
- `cmake` - Required by modern build systems
- `bison`, `flex` - Required by parsers and compilers
- Various `-dev` packages for common libraries

## Network Cache (Shacache)

SlapOS uses a network cache to store pre-compiled binaries, significantly speeding up deployments.

### Cache Servers

| Service | URL | Purpose |
|---------|-----|---------|
| Shacache | http://shacache.nxdcdn.com | Binary downloads |
| Shadir | http://shadir.nxdcdn.com | Directory/metadata lookups |

### Current Status

The standalone Docker build **does not use the network cache** by default. This is intentional because:

1. **Architecture mismatch**: The cache contains x86_64 binaries, but Docker on Apple Silicon runs aarch64
2. **Signature verification**: Downloads require certificate verification
3. **Simplicity**: Building from source is more predictable for debugging

### Enabling Network Cache (Optional)

To enable the cache, modify `scripts/build.py`:

```python
content = f"""
[buildout]
extends = {rel_cfg_path}

# Enable network cache
networkcache-section = networkcache

[networkcache]
download-cache-url = http://shacache.nxdcdn.com
download-dir-url = http://shadir.nxdcdn.com
"""
```

Also install `slapos.libnetworkcache` in the Docker image.

### Detecting Cache Misses

When network cache is enabled, buildout logs indicate:
- **Cache hit**: `"Got <package> from network cache"`
- **Cache miss**: `"Downloading <url>"` followed by compilation

### Architecture Consideration

**Important**: If you're building on aarch64 (ARM64), the cache will likely have no matching binaries since SlapOS infrastructure runs on x86_64. Every component will be a "cache miss" and build from source.
