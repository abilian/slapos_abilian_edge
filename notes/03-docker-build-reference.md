# Docker Build System Reference

Complete reference for the Docker-based SlapOS build system.

## Docker Services

| Service | Purpose | Command |
|---------|---------|---------|
| `slapos-build` | Base service | Shows help |
| `build-component` | Build individual items | `docker-compose run --rm build-component component <name>` |
| `build-software` | Build software releases | `docker-compose run --rm build-component software <name>` |
| `build-all` | Batch builds with reporting | `docker-compose run --rm build-all components` |
| `diagnose` | Cache diagnostics | `docker-compose run --rm diagnose` |

## Volume Structure

```
build/                          # Bind-mounted to host
├── components/                 # Built components
│   └── <name>/
│       ├── buildout.cfg        # Generated config
│       ├── parts/              # Compiled artifacts
│       ├── eggs/               # Python eggs
│       └── bin/                # Executables
├── software/                   # Built software releases
│   └── <name>/
│       └── parts/
├── shared-parts/               # Shared components (shared=true)
├── logs/                       # Build logs
│   ├── component_<timestamp>/
│   │   └── <name>.log
│   └── software_<timestamp>/
│       └── <name>.log
└── reports/                    # Summary reports
    ├── component_report_<timestamp>.txt
    ├── component_report_<timestamp>.json
    └── ...
```

## Building Individual Components

```bash
# Basic usage
docker-compose run --rm build-component component <name>

# Examples
docker-compose run --rm build-component component redis
docker-compose run --rm build-component component postgresql

# With cache enabled
SLAPOS_CACHE=1 docker-compose run --rm build-component component redis
```

## Building Software Releases

```bash
# Basic usage
docker-compose run --rm build-component software <name>

# With cache and real-time output
SLAPOS_CACHE=1 SLAPOS_SHOW_OUTPUT=1 docker-compose run --rm build-component software abilian-sbe
```

## Batch Builds

### Commands

```bash
# Build all components
docker-compose run --rm build-all components

# Build all software releases
docker-compose run --rm build-all software

# Build everything
docker-compose run --rm build-all all
```

### Options

```bash
# Custom timeout (default: 1800s = 30 min)
docker-compose run --rm build-all components --timeout 3600

# Build specific items only
docker-compose run --rm build-all components --only redis,postgres,xz

# Resume from specific item
docker-compose run --rm build-all components --resume-from redis
```

### Output

**Text report** (`component_report_<timestamp>.txt`):
- Human-readable summary
- Failed builds with error excerpts
- Successful builds with duration

**JSON report** (`component_report_<timestamp>.json`):
- Machine-readable
- Full details including timestamps, durations, log paths, cache stats

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `SLAPOS_CACHE` | `0` | Enable network cache (`1` = enabled) |
| `SLAPOS_SHOW_OUTPUT` | `0` | Real-time build output (`1` = enabled) |
| `FORCE_UNSAFE_CONFIGURE` | `1` | Allow configure as root (set in docker-compose.yml) |

## Viewing Results

### List Reports

```bash
ls -la build/reports/
```

### View a Report

```bash
cat build/reports/component_report_*.txt
```

### View Build Logs

```bash
# Latest software build log
cat build/logs/software_*/abilian-sbe.log | tail -100

# Search for errors
grep -i "error" build/logs/software_*/abilian-sbe.log
```

### Verify Built Binaries

```bash
# Check a built binary
build/components/redis/parts/redis/bin/redis-server --version
```

## Managing Volumes

### List Volumes

```bash
docker volume ls | grep slapos
```

### Clear Build Artifacts

```bash
# Remove specific build
rm -rf build/software/abilian-sbe

# Remove all builds
rm -rf build/software/* build/components/*

# Remove Docker volumes
docker-compose down -v
```

## Monitoring Long Builds

```bash
# Watch for new log files
watch -n 5 'ls -lt build/logs/*/ | head -10'

# Tail the latest log
tail -f $(ls -t build/logs/*/*.log | head -1)

# Count completed builds
ls build/software/ | wc -l
```

## Technical Details

### Why Nexedi's Buildout Fork?

SlapOS uses a customized `zc.buildout` (3.0.1+slapos010) with:
- Network cache integration
- Shared parts support
- Custom egg handling
- SlapOS-specific extensions

Standard buildout won't work with most SlapOS components.

### Pinned Dependencies

| Package | Version | Reason |
|---------|---------|--------|
| `setuptools` | 67.8.0 | Newer versions removed `pkg_resources.package_index` |
| `pip` | 23.2.1 | Newer versions removed `pip._vendor.six` |

### Package Name Normalization

Modern pip normalizes names (PEP 503): `zope.interface` → `zope-interface`

The Dockerfile includes patches for:
1. **dist-info directory renaming** - Fixes `pkg_resources.get_distribution()`
2. **buildout `_get_matching_dist_in_location`** - Fixes wheel verification
3. **sitecustomize.py** - Monkeypatches pkg_resources for runtime lookups

### System Dependencies

The Dockerfile installs build tools:
- `gfortran` - OpenBLAS, numpy, scipy
- `cmake` - Modern build systems
- `bison`, `flex` - Parsers and compilers
- Various `-dev` packages

## Known Fixes Applied

| Fix | Location | Issue |
|-----|----------|-------|
| `slapos.core = 1.20.1` | `stack/slapos.cfg` | 1.19.0 broken on PyPI |
| `FORCE_UNSAFE_CONFIGURE=1` | `docker-compose.yml` | GNU packages reject root |
| gnu-config URL | `component/gnu-config/buildout.cfg` | Savannah URL broken |
| PEP 503 patches | `Dockerfile` | Name normalization mismatches |

## Interactive Debugging

```bash
# Enter container for manual work
docker-compose run --rm --entrypoint bash build-component

# Inside container
cd /slapos
python scripts/build.py component redis --use-cache
python scripts/diagnose_cache.py
```
