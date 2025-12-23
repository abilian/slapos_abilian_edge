# Network Cache (Shacache)

SlapOS uses a network cache to store pre-built binaries, significantly speeding up builds.

## Cache Servers

| Service | URL | Purpose |
|---------|-----|---------|
| Shacache | http://shacache.nxdcdn.com | Binary downloads |
| Shadir | http://shadir.nxdcdn.com | Directory/metadata lookups |

## How to Enable

### Method 1: Environment Variable (Recommended)

```bash
SLAPOS_CACHE=1 docker-compose run --rm build-component software abilian-sbe
```

### Method 2: Command-line Flag

```bash
docker-compose run --rm build-component component redis --use-cache
```

### Method 3: .env File

Create `.env` in project root:
```bash
SLAPOS_CACHE=1
```

Then run normally:
```bash
docker-compose run --rm build-component software abilian-sbe
```

## Cache Statistics

### Single Builds

After build completes:
```
============================================================
CACHE STATISTICS:
  Cache hits:     138
  Cache misses:   29
  Downloads:      29
  Hit rate:       82.6%
============================================================
```

### Batch Builds

Inline stats per component:
```
[5/50]   Building redis... OK (45.2s) [cache: 12hit/2miss]
```

## How It Works

### Cache Keys

Artifacts are keyed by:
1. Source URL SHA512
2. Platform/architecture (x86_64, aarch64)
3. Build options

### Cache Hit vs Miss

| Log Pattern | Meaning |
|-------------|---------|
| `"Got <package> from network cache"` | Cache hit (fast) |
| `"Downloading <url>"` | Cache miss (building from source) |

### What Gets Cached

**Cached (fast):**
- Pre-compiled binaries (CMake projects, C extensions)
- Large downloads (boost, chromium, etc.)

**Not cached (always built):**
- Python packages from PyPI
- Buildout recipe execution
- Configuration file generation

## Expected Performance

### On x86_64

| Scenario | Cache Hit Rate |
|----------|----------------|
| Common components | 70-90%+ |
| First-time builds | 20-50% |
| Custom/modified components | 0% |

Example speedups with 100% cache hits:

| Component | Without Cache | With Cache | Speedup |
|-----------|---------------|------------|---------|
| redis | 120s | 15s | 8x |
| postgresql | 300s | 30s | 10x |
| python3 | 600s | 45s | 13x |
| chromium | 3600s | 60s | 60x |

### On aarch64 (ARM)

Cache hit rate will be low (~0-20%) because Nexedi's infrastructure runs on x86_64. Most lookups will be cache misses.

## Troubleshooting

### Verify Cache is Working

```bash
docker-compose run --rm diagnose
```

Expected:
```
✓ libnetworkcache_installed
✓ cache_download
```

Note: HTTP 405 errors on connectivity tests are **normal** - the diagnostic probes root URLs which the server rejects.

### Test Cache Manually

```bash
docker-compose run --rm --entrypoint bash build-component -c "
python3 -c 'import slapos.libnetworkcache; print(\"OK\")'
"
```

### No Cache Hits Despite Enabling

1. **Check architecture:** `uname -m` should show `x86_64`
2. **Check network:** Can you reach `http://shacache.nxdcdn.com`?
3. **Check library:** Is `slapos.libnetworkcache` installed?

### Cache Enabled but Build Still Slow

Cache doesn't help with:
- Python package installations from PyPI (always downloaded)
- Buildout recipe execution (always runs)
- Components not in Nexedi's cache (builds from source)

First builds are slower; subsequent builds benefit from local caching.

## Configuration Details

When cache is enabled, the generated `buildout.cfg` includes:

```ini
[buildout]
extensions =
  slapos.extension.shared

networkcache-section = networkcache

[networkcache]
download-cache-url = http://shacache.nxdcdn.com
download-dir-url = http://shadir.nxdcdn.com
```

## Implementation

The cache is implemented in:

| File | Purpose |
|------|---------|
| `scripts/build.py` | Adds `--use-cache` flag, generates config |
| `scripts/build_all.py` | Passes cache flag, tracks stats |
| `Dockerfile` | Installs `slapos.libnetworkcache` |
| `docker-compose.yml` | Sets `SLAPOS_CACHE` environment variable |

The `slapos.libnetworkcache` library handles communication with the cache servers.
