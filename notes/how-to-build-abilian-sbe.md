# How to Build Abilian SBE (Software Release)

This guide documents the working procedure to build the `abilian-sbe` software release using Docker.

## Prerequisites

- Docker and Docker Compose installed
- x86_64 architecture (for optimal cache hit rate)
- This repository cloned locally

## Quick Start

```bash
# Build the Docker image (first time only)
docker-compose build

# Build abilian-sbe with network cache enabled
SLAPOS_CACHE=1 SLAPOS_SHOW_OUTPUT=1 docker-compose run --rm build-component software abilian-sbe
```

## What the Command Does

| Flag | Purpose |
|------|---------|
| `SLAPOS_CACHE=1` | Enable Nexedi's network cache (shacache) for pre-built binaries |
| `SLAPOS_SHOW_OUTPUT=1` | Stream build output in real-time |
| `build-component software abilian-sbe` | Build the abilian-sbe software release |

## Expected Results

With network cache enabled on x86_64:
- **Cache hit rate**: ~80-95%
- **Build time**: Significantly reduced (cache hits are instant downloads)
- **Output location**: `build/software/abilian-sbe/`

Example cache statistics:
```
CACHE STATISTICS:
  Cache hits:     138
  Cache misses:   29
  Downloads:      29
  Hit rate:       82.6%
```

## Fixes Applied

Two fixes were required to make the build work:

### 1. slapos.core Version (stack/slapos.cfg)

The `slapos.core==1.19.0` package on PyPI is broken - its tarball contains 1.20.1 metadata.

**Fix:** Changed version from `1.19.0` to `1.20.1` in `stack/slapos.cfg`:
```ini
slapos.core = 1.20.1
```

### 2. Root User in Docker (docker-compose.yml)

GNU autoconf-based packages (like coreutils) refuse to configure as root by default.

**Fix:** Added `FORCE_UNSAFE_CONFIGURE=1` environment variable to all build services in `docker-compose.yml`:
```yaml
environment:
  - FORCE_UNSAFE_CONFIGURE=1
```

## Build Output Structure

After a successful build:
```
build/software/abilian-sbe/
├── buildout.cfg      # Generated standalone buildout config
├── bin/              # Executables
├── eggs/             # Python eggs
├── parts/            # Compiled components (130+ directories)
│   ├── python3/
│   ├── postgresql/
│   ├── redis/
│   ├── nginx/
│   └── ...
└── develop-eggs/
```

## Checking Build Progress

While the build is running, you can check what's been built:

```bash
# Count built parts
ls build/software/abilian-sbe/parts/ | wc -l

# List most recently built parts
ls -lrt build/software/abilian-sbe/parts/ | tail -10
```

## Troubleshooting

### Build fails with AssertionError in zc.buildout

```
assert newdist is not None  # newloc above is missing our dist?!
AssertionError
```

**Cause:** Corrupted or partial egg, often due to a broken package on PyPI.

**Solution:**
1. Check which package it was trying to install (look at the log before the error)
2. If it's a version issue (like slapos.core 1.19.0), update the version in `stack/slapos.cfg`
3. Clean eggs and retry:
```bash
rm -rf build/software/abilian-sbe/eggs/*
SLAPOS_CACHE=1 SLAPOS_SHOW_OUTPUT=1 docker-compose run --rm build-component software abilian-sbe
```

### Configure error: "you should not run configure as root"

**Cause:** GNU packages like coreutils refuse to build as root.

**Solution:** Ensure `FORCE_UNSAFE_CONFIGURE=1` is set in docker-compose.yml (already applied).

### Low cache hit rate

**Cause:** Running on aarch64 (ARM) instead of x86_64. Nexedi's cache contains x86_64 binaries.

**Solution:** Use an x86_64 machine or accept longer build times.

## Diagnosing Cache Issues

```bash
# Run the diagnostic tool
docker-compose run --rm diagnose
```

Expected output for working cache:
```
✓ libnetworkcache_installed
✓ cache_download
```

Note: HTTP 405 errors on `shacache_connectivity` and `shadir_connectivity` are normal - the diagnostic probes the root URL which the server rejects.

## Related Files

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Docker service definitions |
| `Dockerfile` | Build environment setup |
| `scripts/build.py` | Single component/software build script |
| `scripts/diagnose_cache.py` | Cache diagnostic tool |
| `stack/slapos.cfg` | Version pins for SlapOS packages |
| `software/abilian-sbe/software.cfg` | Abilian SBE build definition |

## Version Information

- **Date:** 2026-01-23
- **slapos.core:** 1.20.1
- **Python:** 3.11 (in Docker)
- **Cache hit rate achieved:** 82.6%
