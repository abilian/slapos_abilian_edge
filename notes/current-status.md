# Current Status (January 21, 2026)

## Overview

We are building SlapOS components in a standalone Docker environment on **aarch64** (ARM64/Apple Silicon), independent of Nexedi's infrastructure.

## What's Working

### Docker Build Environment
- **Base image:** `python:3.11-slim-bookworm`
- **Nexedi's buildout fork:** `zc.buildout 3.0.1+slapos010` installed and working
- **Build scripts:** `scripts/build.py` and `scripts/build_all.py` functional
- **Named volumes:** Using Docker volumes to persist build artifacts

### Patched Issues
1. **PEP 503 Name Normalization:** Patched buildout's `easy_install.py` and pkg_resources via `sitecustomize.py` to handle dotted vs hyphenated package names (e.g., `zope.interface` vs `zope-interface`)
2. **gnu-config URL:** Fixed broken Savannah URL by switching to GitHub mirror
3. **Eggs collision:** Added cleanup code in build.py to remove stale eggs
4. **System dependencies:** Added comprehensive build tools (gfortran, cmake, etc.)

### Build Results (Partial Run)
From the first ~46 components tested:
- **Successful:** ZEO, ZODB, curl, cmake, cython, and many others
- **Failed:** See "Known Failures" below

## Known Failures

| Component | Error | Root Cause |
|-----------|-------|------------|
| PyWavelets, chainer | Version conflict (gast) | `pythran` requires `gast~=0.6.0` but pinned to `0.5.3` |
| chromedriver, chromium, consul | Missing URL | Only x86_64 URLs defined, no aarch64 |
| apache-php, cclient, boost-lib | MD5 mismatch | Upstream files changed |
| bazel | SyntaxError | Python 2 octal literals (`0644` → `0o644`) |
| coreutils | Configure error | Rejects running as root |
| bcrypt, clamav | Timeout | Build exceeds 30-minute limit |

## Architecture Issue

**Critical:** We're building on **aarch64** but SlapOS infrastructure is **x86_64**.

This means:
- Many binary-only components have no aarch64 support
- Network cache (shacache) likely only has x86_64 builds
- Architecture-specific configs won't work

## Network Cache Status

The shacache is **not enabled** in our standalone builds. The services are accessible:
- `http://shacache.nxdcdn.com` - Binary cache
- `http://shadir.nxdcdn.com` - Directory service

But `slapos.libnetworkcache` is not installed, and even if enabled, cache hits are unlikely on aarch64.

## Files Modified

| File | Purpose |
|------|---------|
| `Dockerfile` | Build environment with patches |
| `docker-compose.yml` | Service definitions |
| `scripts/build.py` | Single component builder |
| `scripts/build_all.py` | Batch builder with reporting |
| `component/gnu-config/buildout.cfg` | Fixed download URL |

## Build Logs Location

When running `build-all`, logs are stored at:
```
/slapos/build/logs/component_<timestamp>/<component>.log
/slapos/build/reports/component_report_<timestamp>.txt
/slapos/build/reports/component_report_<timestamp>.json
```
