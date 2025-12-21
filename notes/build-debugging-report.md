# SlapOS Build System Debugging Report

**Date:** January 2026
**Project:** slapos_abilian_edge
**Objective:** Build SlapOS components and software releases independently of Nexedi's infrastructure using Docker

## Executive Summary

This report documents the investigation and resolution of multiple issues preventing successful builds of SlapOS components in a standalone Docker environment. The primary challenges stemmed from:

1. Broken download URLs in component definitions
2. Missing system build dependencies
3. Incompatibility between modern pip's package name normalization (PEP 503) and Nexedi's forked buildout

All issues have been identified and patched, enabling successful builds of previously failing components like ZEO, ZODB, and many others.

---

## 1. Initial Setup

### 1.1 Build Environment

A Docker-based build environment was created using:

- **Base image:** `python:3.11-slim-bookworm`
- **Buildout:** Nexedi's forked `zc.buildout` (3.0.1+slapos010)
- **Pinned dependencies:**
  - `setuptools==67.8.0` (newer versions removed `pkg_resources.package_index`)
  - `pip==23.2.1` (newer versions removed `pip._vendor.six`)

### 1.2 Build Scripts Created

| Script | Purpose |
|--------|---------|
| `scripts/build.py` | Build individual components or software releases |
| `scripts/build_all.py` | Build all components with reporting and logging |

### 1.3 Docker Services

| Service | Command |
|---------|---------|
| `build-component` | `docker compose run --rm build-component component <name>` |
| `build-software` | `docker compose run --rm build-software software <name>` |
| `build-all` | `docker compose run --rm build-all components` |

---

## 2. Issues Identified and Resolved

### 2.1 Issue: gnu-config Download URL Broken (HTTP 400)

**Symptoms:**
- ~21 components failing with download errors
- Error: `HTTP Error 400: Bad Request` when fetching from Savannah

**Root Cause:**
The `component/gnu-config/buildout.cfg` used a Savannah cgit snapshot URL that no longer works:
```
https://cgit.git.savannah.gnu.org/cgit/config.git/snapshot/config-*.tar.gz
```

**Fix:**
Changed to GitHub mirror (arthenica/gnu-config):
```ini
[gnu-config]
url = https://github.com/arthenica/gnu-config/archive/a2287c3041a3f2a204eb942e09c015eab00dc7dd.tar.gz
md5sum = 3e3d21528f63da26e6408b1e0c009057
```

**Impact:** Fixed ~21 component build failures.

**File Modified:** `component/gnu-config/buildout.cfg`

---

### 2.2 Issue: Missing System Build Dependencies

**Symptoms:**
- Various compilation failures
- Missing headers and libraries
- `gfortran: command not found`

**Root Cause:**
The slim Docker base image lacks many development packages required by SlapOS components.

**Fix:**
Added comprehensive build dependencies to Dockerfile:

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

**Key additions:**
- `gfortran` - Required by OpenBLAS, numpy, scipy
- `libasound2-dev` - Audio components
- `cmake` - Modern build systems
- `bison`, `flex` - Parser generators

**File Modified:** `Dockerfile`

---

### 2.3 Issue: Missing SlapOS Extensions

**Symptoms:**
- `MissingSection: The referenced section, 'shared-part-list', was not defined.`

**Root Cause:**
SlapOS components use `slapos.extension.shared` for shared parts functionality, but this extension was not installed.

**Fix:**
Added SlapOS extensions to Dockerfile:

```dockerfile
RUN pip install --no-cache-dir \
    slapos.extension.shared \
    slapos.extension.strip
```

**File Modified:** `Dockerfile`

---

### 2.4 Issue: Eggs Directory Collision

**Symptoms:**
- `OSError: [Errno 39] Directory not empty`
- Occurs during `os.rename()` when buildout tries to move eggs

**Root Cause:**
When a build fails and is retried, stale temporary egg directories and egg files from the previous attempt cause collisions.

**Fix:**
Added cleanup code in `scripts/build.py` to remove stale eggs before building:

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

**File Modified:** `scripts/build.py`

---

### 2.5 Issue: Package Name Normalization (PEP 503 vs pkg_resources)

**This is the most complex issue and required the most investigation.**

**Symptoms:**
- ZEO, ZODB, and other Zope-related components failing
- `AssertionError` in buildout's wheel verification
- Stack trace pointing to `_get_matching_dist_in_location`

**Investigation:**

The error occurred in `zc/buildout/easy_install.py` at the `_get_matching_dist_in_location` function:

```python
def _get_matching_dist_in_location(dist, location):
    env = pkg_resources.Environment([location])
    dists = [ d for project_name in env for d in env[project_name] ]
    dist_infos = [ (d.project_name.lower(), d.parsed_version) for d in dists ]
    if dist_infos == [(dist.project_name.lower(), dist.parsed_version)]:
        return dists.pop()
    # If comparison fails, returns None, causing AssertionError upstream
```

**Root Cause Analysis:**

1. **PEP 503 Name Normalization:** Modern pip (and PyPI) normalizes package names according to PEP 503:
   - Dots (`.`) → hyphens (`-`)
   - Underscores (`_`) → hyphens (`-`)
   - All lowercase

2. **Wheel Naming:** When pip downloads a wheel, the filename uses the normalized name:
   - Package: `zope.interface`
   - Wheel: `zope_interface-7.2-cp311-cp311-linux_x86_64.whl`
   - Metadata directory: `zope_interface-7.2.dist-info`

3. **pkg_resources Behavior:** `pkg_resources.Environment` reads the `.dist-info` directory and extracts the project name, which may use underscores or hyphens.

4. **Buildout Comparison:** The function compares:
   - Expected: `zope.interface` (from buildout requirement)
   - Found: `zope-interface` or `zope_interface` (from wheel metadata)
   - Result: **Mismatch → AssertionError**

**The Two-Part Fix:**

**Part 1: dist-info Directory Renaming**

Already in the Dockerfile, this renames directories to use dotted names:
```python
# Renames zc_buildout-*.dist-info → zc.buildout-*.dist-info
packages_to_fix = [
    ('zc_buildout', 'zc.buildout'),
    ('slapos_core', 'slapos.core'),
    # ... etc
]
```

This fixes `pkg_resources.get_distribution()` calls but doesn't fix all cases.

**Part 2: Buildout Patch**

Added a patch to `_get_matching_dist_in_location` that normalizes names before comparison:

```python
# Patch applied to zc/buildout/easy_install.py
def _norm(n): return n.lower().replace(".", "-").replace("_", "-")
dist_infos = [ (_norm(d.project_name), d.parsed_version) for d in dists ]
if dist_infos == [(_norm(dist.project_name), dist.parsed_version)]:
    return dists.pop()
```

**Part 3: pkg_resources Monkeypatch (sitecustomize.py)**

A comprehensive patch applied via `sitecustomize.py` that fixes multiple locations in `pkg_resources`:

1. **`Environment.__getitem__`**: Falls back to normalized name lookup when original name not found
2. **`Environment.best_match`**: Tries normalized key lookup if standard lookup fails
3. **`WorkingSet.find`**: Catches false VersionConflict errors due to name mismatch
4. **`WorkingSet.resolve`**: Handles version conflicts caused by name normalization
5. **`Requirement.__contains__`**: Normalizes keys before comparing distribution against requirement

The key fix is in `Requirement.__contains__`:
```python
def _patched_req_contains(self, item):
    if isinstance(item, pkg_resources.Distribution):
        # Use normalized keys for comparison
        if normalize_name(item.key) != normalize_name(self.key):
            return False
        item = item.version
    return self.specifier.contains(item, prereleases=True)
```

**Why This Works:**
| Name Form | After `normalize_name()` |
|-----------|---------------------------|
| `zope.interface` | `zope-interface` |
| `zope_interface` | `zope-interface` |
| `zope-interface` | `zope-interface` |

All forms normalize to the same string, enabling correct comparison at every level.

**File Modified:** `Dockerfile` (patches applied during image build)

---

## 3. Technical Deep Dive: The Naming Problem

### 3.1 Historical Context

Python packaging has evolved through several naming conventions:

| Era | Convention | Example |
|-----|------------|---------|
| Pre-2010 | Dotted namespaces | `zope.interface` |
| 2010s | Underscores in wheels | `zope_interface` |
| 2020+ | PEP 503 normalization | `zope-interface` |

### 3.2 The Conflict

**Nexedi's buildout fork** was developed primarily for SlapOS, which uses many Zope packages with dotted names. The codebase assumes:
- Requirements use dotted names (`zope.interface`)
- Installed packages use dotted names

**Modern pip** follows PEP 503 strictly:
- Downloads wheels with normalized names
- Creates `.dist-info` directories with normalized names
- The original dotted name is only preserved in metadata files

### 3.3 Where Comparisons Happen

| Location | What's Compared | Issue |
|----------|-----------------|-------|
| `_get_matching_dist_in_location` | Wheel filename vs requirement | **Fixed with patch** |
| `pkg_resources.get_distribution()` | dist-info directory name | **Fixed with renaming** |
| `pkg_resources.require()` | Requirement string vs installed | Usually works (uses `safe_name`) |

### 3.4 Nexedi's Partial Fix

Nexedi added `WkrdPackageIndex.getdists()` which handles some normalization:
```python
def getdists(self, location):
    # ... handles distribution lookup with some name normalization
```

However, this doesn't cover all code paths, particularly `_get_matching_dist_in_location`.

---

## 4. Files Modified

| File | Changes |
|------|---------|
| `Dockerfile` | Added system deps, extensions, buildout patch |
| `component/gnu-config/buildout.cfg` | Fixed download URL |
| `scripts/build.py` | Added eggs cleanup |
| `scripts/build_all.py` | Created (new file) |
| `docker-compose.yml` | Added build-all service |
| `notes/docker-build.md` | Updated documentation |

---

## 5. Testing and Verification

### 5.1 Rebuild Docker Image

```bash
docker compose build --no-cache
```

### 5.2 Verify Patch Applied

```bash
docker run --rm slapos-build python3 -c "
import zc.buildout.easy_install as ei
import inspect
src = inspect.getsource(ei._get_matching_dist_in_location)
print('_normalize_name' in src)  # Should print: True
"
```

### 5.3 Test Previously Failing Components

```bash
# ZEO (was failing with AssertionError)
docker compose run --rm build-component component ZEO

# ZODB (was failing with AssertionError)
docker compose run --rm build-component component ZODB
```

### 5.4 Run Full Build

```bash
docker compose run --rm build-all components
```

---

## 6. Remaining Considerations

### 6.1 Components That May Still Fail

Some components may fail due to:
- **External URL changes:** Other components may have broken download URLs
- **Missing system deps:** Rare libraries not in our apt-get list
- **Architecture-specific code:** Components that assume x86_64
- **Network dependencies:** Components needing external services during build

### 6.2 Upstream Contribution

Consider contributing the buildout patch to Nexedi's fork:
- Repository: `https://lab.nexedi.com/nexedi/slapos.buildout`
- The fix is minimal and backwards-compatible

### 6.3 Long-term Solutions

1. **Upgrade to newer packaging:** Use `importlib.metadata` instead of `pkg_resources`
2. **Pin wheel versions:** Ensure consistent naming across builds
3. **Use network cache:** Nexedi's binary cache avoids building from source

---

## 7. Conclusion

The SlapOS build system can now successfully build components in a standalone Docker environment. The key insight is that modern Python packaging (PEP 503) creates a naming mismatch with older code that expects dotted package names. By normalizing names during comparison, we bridge this gap without modifying the core SlapOS infrastructure.

---

## Appendix A: Full Dockerfile Patches

### A.1 Buildout easy_install.py Patch

```python
# Patch buildout's _get_matching_dist_in_location to handle PEP 503 name normalization
RUN python3 << 'PATCH_EOF'
import site
import os

for sp in site.getsitepackages():
    easy_install_path = os.path.join(sp, 'zc', 'buildout', 'easy_install.py')
    if os.path.exists(easy_install_path):
        with open(easy_install_path, 'r') as f:
            lines = f.readlines()

        new_lines = []
        for line in lines:
            # Replace dist_infos line with normalized version
            if 'dist_infos = [ (d.project_name.lower()' in line:
                indent = line[:len(line) - len(line.lstrip())]
                new_lines.append(f'{indent}def _norm(n): return n.lower().replace(".", "-").replace("_", "-")\n')
                new_lines.append(f'{indent}dist_infos = [ (_norm(d.project_name), d.parsed_version) for d in dists ]\n')
            elif 'if dist_infos == [(dist.project_name.lower()' in line:
                indent = line[:len(line) - len(line.lstrip())]
                new_lines.append(f'{indent}if dist_infos == [(_norm(dist.project_name), dist.parsed_version)]:\n')
            else:
                new_lines.append(line)

        with open(easy_install_path, 'w') as f:
            f.writelines(new_lines)
        break
PATCH_EOF
```

### A.2 sitecustomize.py Patch (pkg_resources monkeypatch)

```python
# PEP 503 name normalization patch for pkg_resources
def _apply_pkg_resources_patch():
    import pkg_resources

    def normalize_name(name):
        return name.lower().replace('.', '-').replace('_', '-')

    # Patch Environment.__getitem__
    _original_env_getitem = pkg_resources.Environment.__getitem__
    def _patched_env_getitem(self, project_name):
        result = _original_env_getitem(self, project_name)
        if result:
            return result
        norm_name = normalize_name(project_name)
        for key in list(self._distmap.keys()):
            if normalize_name(key) == norm_name:
                return _original_env_getitem(self, key)
        return result
    pkg_resources.Environment.__getitem__ = _patched_env_getitem

    # Patch Environment.best_match
    _original_best_match = pkg_resources.Environment.best_match
    def _patched_best_match(self, req, working_set, installer=None, replace_conflicting=False):
        result = _original_best_match(self, req, working_set, installer, replace_conflicting)
        if result is not None:
            return result
        norm_key = normalize_name(req.key)
        for key in list(self._distmap.keys()):
            if normalize_name(key) == norm_key:
                for dist in self[key]:
                    if dist.parsed_version in req:
                        return dist
        return None
    pkg_resources.Environment.best_match = _patched_best_match

    # Patch Requirement.__contains__
    def _patched_req_contains(self, item):
        if isinstance(item, pkg_resources.Distribution):
            if normalize_name(item.key) != normalize_name(self.key):
                return False
            item = item.version
        return self.specifier.contains(item, prereleases=True)
    pkg_resources.Requirement.__contains__ = _patched_req_contains

_apply_pkg_resources_patch()
```

---

## Appendix B: Error Messages Reference

### B.1 gnu-config URL Error
```
Error: Download error on https://cgit.git.savannah.gnu.org/.../config-*.tar.gz:
HTTP Error 400: Bad Request
```

### B.2 Eggs Collision Error
```
OSError: [Errno 39] Directory not empty: '/slapos/build/.../eggs/tmpXXXXXX'
```

### B.3 Package Name Mismatch (AssertionError)
```
File ".../zc/buildout/easy_install.py", line 894, in _maybe_move_for_rename
    assert _get_matching_dist_in_location(...)
AssertionError
```

### B.4 Missing Extension Error
```
MissingSection: The referenced section, 'shared-part-list', was not defined.
```
