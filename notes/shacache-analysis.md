# Shacache Analysis and Cache Issues

## Overview

SlapOS uses a network cache (shacache) to store pre-built binaries, avoiding recompilation. This document analyzes why our standalone Docker build doesn't use it and what issues would remain even if enabled.

## Current Situation

Our standalone build **intentionally disables** the network cache (lines 109-117 in `scripts/build.py`):

```python
# Disable SlapOS extensions that require infrastructure
extensions =

# Disable network cache (build from source)
# networkcache-section = networkcache
```

## How to Enable Shacache

### Step 1: Install the library

Add to `Dockerfile`:
```dockerfile
RUN pip install slapos.libnetworkcache
```

### Step 2: Modify build.py

Update the standalone buildout config generation in `scripts/build.py`:

```python
content = f"""
[buildout]
extends = {rel_cfg_path}

# Enable SlapOS extensions for network cache
extensions =
  slapos.extension.shared

# Enable network cache
networkcache-section = networkcache

[networkcache]
download-cache-url = http://shacache.nxdcdn.com
download-dir-url = http://shadir.nxdcdn.com
"""
```

## Detecting Cache Hits vs Misses

When network cache is enabled, buildout logs indicate:

| Log Message | Meaning |
|-------------|---------|
| `"Got <package> from network cache"` | Cache hit - binary downloaded |
| `"Downloading <url>"` | Cache miss - building from source |

## Why Shacache Won't Solve All Problems

### Architecture Mismatch (Critical)

**Our environment:** aarch64 (ARM64 / Apple Silicon)
**SlapOS infrastructure:** x86_64

The cache stores pre-built binaries keyed by:
- Source URL SHA512
- **Platform/architecture**
- Build options

Since Nexedi's infrastructure is x86_64, the shacache likely contains **no aarch64 builds**. Every lookup would be a cache miss.

### Root Cause Analysis

| Issue | Root Cause | Would Cache Help? |
|-------|------------|-------------------|
| MD5 mismatch (boost, cclient) | Upstream files changed | **Yes** - cache bypasses source downloads |
| Architecture (chromedriver, consul) | No aarch64 URLs defined | **No** - config issue, not build issue |
| Running as root (coreutils) | Docker runs as root | **No** - configure-time check |
| Python 2 syntax (bazel) | Code bug (`0644` → `0o644`) | **No** - code needs fixing |
| Missing meson | Not installed in Docker | **No** - dependency issue |
| Version conflicts (gast) | Pinned version incompatible | **No** - config issue |
| Timeouts (bcrypt, clamav) | Complex builds | **Yes** - would skip build entirely |

### Summary

Out of the observed failures:
- **2 would be fixed** by cache (MD5 mismatches, timeouts)
- **5+ would NOT be fixed** (architecture, root, syntax, missing deps, version conflicts)

## Recommendation

For **aarch64 development**, enabling shacache provides minimal benefit since most lookups will miss. Focus on:

1. Fixing code issues (bazel Python 3 syntax)
2. Adding missing dependencies (meson)
3. Setting environment variables (`FORCE_UNSAFE_CONFIGURE=1`)
4. Updating checksums for changed upstream files

For **x86_64 production**, enabling shacache would significantly speed up builds by downloading pre-compiled binaries.

## Testing the Cache

To verify cache behavior, enable it and watch for log patterns:

```bash
# Build with verbose output
docker compose run --rm build-component component redis 2>&1 | grep -E "(network cache|Downloading)"
```

Expected output with cache miss:
```
Downloading https://download.redis.io/releases/redis-7.x.x.tar.gz
```

Expected output with cache hit:
```
Got redis from network cache
```
