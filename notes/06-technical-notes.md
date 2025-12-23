# Technical Notes

Deep technical documentation of issues resolved and patches applied.

## Executive Summary

Building SlapOS components in a standalone Docker environment required resolving:

1. Broken download URLs in component definitions
2. Missing system build dependencies
3. Incompatibility between modern pip's PEP 503 name normalization and Nexedi's buildout
4. Docker compatibility issues

## Build Environment

| Component | Version |
|-----------|---------|
| Base image | `python:3.11-slim-bookworm` |
| Buildout | `zc.buildout 3.0.1+slapos010` (Nexedi fork) |
| setuptools | 67.8.0 (pinned) |
| pip | 23.2.1 (pinned) |

### Why Pinned Versions?

| Package | Version | Reason |
|---------|---------|--------|
| setuptools | 67.8.0 | Newer removed `pkg_resources.package_index` |
| pip | 23.2.1 | Newer removed `pip._vendor.six` |

---

## Issue 1: gnu-config Download URL (HTTP 400)

### Symptoms
~21 components failing with download errors from Savannah.

### Root Cause
`component/gnu-config/buildout.cfg` used a Savannah cgit URL that no longer works.

### Fix
Changed to GitHub mirror (arthenica/gnu-config):
```ini
[gnu-config]
url = https://github.com/arthenica/gnu-config/archive/a2287c3041a3f2a204eb942e09c015eab00dc7dd.tar.gz
md5sum = 3e3d21528f63da26e6408b1e0c009057
```

**File:** `component/gnu-config/buildout.cfg`

---

## Issue 2: Missing System Dependencies

### Symptoms
Various compilation failures, missing headers.

### Fix
Added comprehensive build tools to Dockerfile:

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf automake bison build-essential ca-certificates cmake \
    curl flex gawk gettext gfortran git groff libasound2-dev \
    libbz2-dev libcap-dev libexpat1-dev libffi-dev libgdbm-dev \
    libgmp-dev libjpeg-dev liblzma-dev libncurses5-dev libpcre3-dev \
    libpng-dev libreadline-dev libsqlite3-dev libssl-dev libtool \
    libxml2-dev libxslt1-dev m4 patch pkg-config rsync texinfo \
    uuid-dev wget xz-utils zlib1g-dev
```

Key additions:
- `gfortran` - OpenBLAS, numpy, scipy
- `cmake` - Modern build systems
- `bison`, `flex` - Parser generators

---

## Issue 3: Eggs Directory Collision

### Symptoms
```
OSError: [Errno 39] Directory not empty
```
During `os.rename()` when buildout moves eggs.

### Root Cause
Stale temporary eggs from failed builds cause collisions on retry.

### Fix
Added cleanup in `scripts/build.py`:

```python
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
```

---

## Issue 4: PEP 503 Name Normalization (Critical)

This was the most complex issue requiring extensive investigation.

### Symptoms
- ZEO, ZODB, Zope packages failing
- `AssertionError` in buildout's wheel verification
- Stack trace in `_get_matching_dist_in_location`

### Root Cause Analysis

**PEP 503** (2015) standardized package name normalization:
- Dots (`.`) → hyphens (`-`)
- Underscores (`_`) → hyphens (`-`)
- All lowercase

**Problem:** Nexedi's buildout expects dotted names (`zope.interface`), but modern pip installs wheels with normalized names (`zope-interface`).

| Source | Name Form |
|--------|-----------|
| Buildout requirement | `zope.interface` |
| Wheel filename | `zope_interface-7.2-*.whl` |
| dist-info directory | `zope_interface-7.2.dist-info` |
| Comparison result | **Mismatch → AssertionError** |

### The Three-Part Fix

#### Part 1: dist-info Directory Renaming

Renames directories so `pkg_resources.get_distribution()` works:

```python
packages_to_fix = [
    ('zc_buildout', 'zc.buildout'),
    ('slapos_core', 'slapos.core'),
    ('zope_interface', 'zope.interface'),
    # ... etc
]
```

#### Part 2: Buildout Patch

Patches `_get_matching_dist_in_location` in `zc/buildout/easy_install.py`:

```python
# Original
dist_infos = [ (d.project_name.lower(), d.parsed_version) for d in dists ]
if dist_infos == [(dist.project_name.lower(), dist.parsed_version)]:

# Patched
def _norm(n): return n.lower().replace(".", "-").replace("_", "-")
dist_infos = [ (_norm(d.project_name), d.parsed_version) for d in dists ]
if dist_infos == [(_norm(dist.project_name), dist.parsed_version)]:
```

#### Part 3: pkg_resources Monkeypatch (sitecustomize.py)

Comprehensive patch via `sitecustomize.py` fixing multiple locations:

1. **`Environment.__getitem__`** - Falls back to normalized name lookup
2. **`Environment.best_match`** - Tries normalized key if standard fails
3. **`Requirement.__contains__`** - Normalizes before comparing

Key fix:
```python
def _patched_req_contains(self, item):
    if isinstance(item, pkg_resources.Distribution):
        if normalize_name(item.key) != normalize_name(self.key):
            return False
        item = item.version
    return self.specifier.contains(item, prereleases=True)
```

### Why It Works

| Input Form | After `normalize_name()` |
|------------|--------------------------|
| `zope.interface` | `zope-interface` |
| `zope_interface` | `zope-interface` |
| `zope-interface` | `zope-interface` |

All forms normalize to the same string.

---

## Issue 5: slapos.core 1.19.0 Broken on PyPI

### Symptoms
```
AssertionError
```
When trying to install `slapos.core==1.19.0`.

### Root Cause
The tarball `slapos_core-1.19.0.tar.gz` on PyPI contains version `1.20.1` in its metadata - a packaging error.

```
WARNING: Requested slapos.core==1.19.0 but metadata has '1.20.1'
```

### Fix
Updated version pin in `stack/slapos.cfg`:
```ini
slapos.core = 1.20.1
```

---

## Issue 6: GNU Configure Rejects Root

### Symptoms
```
configure: error: you should not run configure as root
```

### Root Cause
GNU packages (coreutils, etc.) have safety checks rejecting root builds.

### Fix
Added to `docker-compose.yml`:
```yaml
environment:
  - FORCE_UNSAFE_CONFIGURE=1
```

---

## Issue 7: Dockerfile Heredoc Compatibility

### Symptoms
```
ERROR: dockerfile parse error on line 71: unknown instruction: import
```

### Root Cause
Docker heredoc syntax (`RUN python3 << 'EOF'`) requires Docker 23.0+.

### Fix
Replaced heredocs with separate script files in `docker/`:
- `docker/patch_buildout.py`
- `docker/create_sitecustomize.py`
- `docker/fix_package_names.py`

Then in Dockerfile:
```dockerfile
COPY docker/ /tmp/docker/
RUN python3 /tmp/docker/patch_buildout.py
RUN python3 /tmp/docker/create_sitecustomize.py
RUN python3 /tmp/docker/fix_package_names.py && rm -rf /tmp/docker
```

---

## Files Modified Summary

| File | Changes |
|------|---------|
| `Dockerfile` | System deps, extensions, patches |
| `docker-compose.yml` | `FORCE_UNSAFE_CONFIGURE=1`, cache env vars |
| `docker/patch_buildout.py` | PEP 503 buildout patch |
| `docker/create_sitecustomize.py` | pkg_resources monkeypatch |
| `docker/fix_package_names.py` | dist-info renaming |
| `component/gnu-config/buildout.cfg` | Fixed download URL |
| `stack/slapos.cfg` | `slapos.core = 1.20.1` |
| `scripts/build.py` | Eggs cleanup, cache support |
| `scripts/build_all.py` | Batch builds, reporting |
| `scripts/diagnose_cache.py` | Cache diagnostics |

---

## Verification

### Verify Buildout Patch

```bash
docker-compose run --rm --entrypoint bash build-component -c "
python3 -c \"
import zc.buildout.easy_install as ei
import inspect
src = inspect.getsource(ei._get_matching_dist_in_location)
print('_norm' in src)
\"
"
# Should print: True
```

### Verify sitecustomize Loaded

```bash
docker-compose run --rm --entrypoint bash build-component -c "
python3 -c \"
import pkg_resources
print(hasattr(pkg_resources.Requirement, '_original_contains'))
\"
"
```

---

## Historical Context

### Python Packaging Evolution

| Era | Convention | Example |
|-----|------------|---------|
| Pre-2010 | Dotted namespaces | `zope.interface` |
| 2010s | Underscores in wheels | `zope_interface` |
| 2020+ | PEP 503 normalization | `zope-interface` |

### The Conflict

**Nexedi's buildout** was built for SlapOS with Zope packages using dotted names.

**Modern pip** follows PEP 503 strictly, creating normalized wheel/dist-info names.

The patches bridge this gap without modifying SlapOS core infrastructure.

---

## Future Considerations

1. **Upstream contribution:** The buildout patch is minimal and backwards-compatible
2. **Long-term:** Migrate to `importlib.metadata` instead of `pkg_resources`
3. **Network cache:** On x86_64, cache provides ~80%+ hit rate avoiding most source builds
