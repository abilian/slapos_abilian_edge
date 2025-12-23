# Quick Start Guide

This guide gets you building SlapOS software releases in minutes.

## Prerequisites

- Docker and Docker Compose installed
- x86_64 architecture (for optimal cache hit rate)
- This repository cloned locally

## First-Time Setup

```bash
# Build the Docker image (only needed once)
docker-compose build
```

## Build Abilian SBE

The main software release for this project:

```bash
SLAPOS_CACHE=1 SLAPOS_SHOW_OUTPUT=1 docker-compose run --rm build-component software abilian-sbe
```

### What the Flags Do

| Flag | Purpose |
|------|---------|
| `SLAPOS_CACHE=1` | Enable Nexedi's network cache for pre-built binaries |
| `SLAPOS_SHOW_OUTPUT=1` | Stream build output in real-time |

### Expected Results

With network cache on x86_64:
- **Cache hit rate:** 80-95%
- **Output location:** `build/software/abilian-sbe/`

Example statistics:
```
CACHE STATISTICS:
  Cache hits:     138
  Cache misses:   29
  Hit rate:       82.6%
```

## Build Everything

### All Components (~420)

```bash
SLAPOS_CACHE=1 docker-compose run --rm build-all components
```

### All Software Releases (~70)

```bash
SLAPOS_CACHE=1 docker-compose run --rm build-all software
```

### Everything (Components + Software)

```bash
SLAPOS_CACHE=1 docker-compose run --rm build-all all
```

## Build Options

| Option | Description | Example |
|--------|-------------|---------|
| `--timeout <seconds>` | Timeout per item (default: 1800s) | `--timeout 7200` |
| `--only <items>` | Build specific items only | `--only gitlab,erp5` |
| `--resume-from <item>` | Skip items before this one | `--resume-from redis` |

### Examples

```bash
# Longer timeout (2 hours per item)
SLAPOS_CACHE=1 docker-compose run --rm build-all software --timeout 7200

# Build specific releases only
SLAPOS_CACHE=1 docker-compose run --rm build-all software --only gitlab,erp5,nextcloud

# Resume after failure
SLAPOS_CACHE=1 docker-compose run --rm build-all components --resume-from redis

# Verbose output for batch builds
SLAPOS_CACHE=1 SLAPOS_SHOW_OUTPUT=1 docker-compose run --rm build-all components
```

## Check Progress

### During Build

```bash
# Count built items
ls build/software/ 2>/dev/null | wc -l
ls build/components/ 2>/dev/null | wc -l

# List most recently built parts
ls -lrt build/software/abilian-sbe/parts/ | tail -10
```

### After Build

```bash
# View latest report
cat $(ls -t build/reports/*.txt 2>/dev/null | head -1)

# Check specific build log
cat build/logs/software_*/abilian-sbe.log | tail -50
```

## Output Structure

```
build/
├── software/                   # Built software releases
│   └── abilian-sbe/
│       ├── buildout.cfg        # Generated config
│       ├── parts/              # 130+ compiled components
│       ├── eggs/               # Python eggs
│       └── bin/                # Executables
├── components/                 # Built standalone components
│   └── <name>/parts/
├── logs/                       # Build logs
│   └── software_<timestamp>/
│       └── <name>.log
└── reports/                    # Summary reports
    ├── software_report_<timestamp>.txt
    └── software_report_<timestamp>.json
```

## Diagnose Issues

```bash
docker-compose run --rm diagnose
```

Expected output for working setup:
```
✓ libnetworkcache_installed
✓ cache_download
```

Note: HTTP 405 errors on connectivity tests are normal.

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `SLAPOS_CACHE` | `0` | Enable network cache (`1` = enabled) |
| `SLAPOS_SHOW_OUTPUT` | `0` | Real-time build output (`1` = enabled) |

## Troubleshooting

### AssertionError in zc.buildout

```bash
rm -rf build/software/abilian-sbe/eggs/*
# Then retry the build
```

### Configure error: "should not run as root"

Already fixed in `docker-compose.yml` with `FORCE_UNSAFE_CONFIGURE=1`.

### Low cache hit rate

You may be on ARM architecture. Use x86_64 for best cache performance.

### Build times out

```bash
# Increase timeout to 4 hours
docker-compose run --rm build-all software --timeout 14400
```

## Key Files

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Docker service definitions |
| `Dockerfile` | Build environment |
| `scripts/build.py` | Single item build script |
| `scripts/build_all.py` | Batch build script |
| `scripts/diagnose_cache.py` | Cache diagnostic tool |
| `stack/slapos.cfg` | Version pins |

## Next Steps

- [03-docker-build-reference.md](03-docker-build-reference.md) - Complete Docker reference
- [04-network-cache.md](04-network-cache.md) - Cache configuration details
- [05-troubleshooting.md](05-troubleshooting.md) - More troubleshooting tips
