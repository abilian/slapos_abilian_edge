# Dockerfile Compatibility Fix

## Problem

The original Dockerfile used **heredoc syntax** (`RUN python3 << 'EOF'`) which was introduced in Docker 23.0. This syntax is not supported in older Docker versions, causing build errors like:

```
ERROR: dockerfile parse error on line 71: unknown instruction: import
```

## Solution

Replaced all heredoc Python scripts with separate script files:

### Files Created

1. **docker/patch_buildout.py** - Patches buildout's easy_install.py for PEP 503 name normalization
2. **docker/create_sitecustomize.py** - Creates sitecustomize.py to monkeypatch pkg_resources
3. **docker/fix_package_names.py** - Fixes dist-info directory names (underscores → dots)

### Dockerfile Changes

**Before** (heredoc syntax - not compatible with older Docker):
```dockerfile
RUN python3 << 'EOF'
import site
import os
# ... Python code ...
EOF
```

**After** (universally compatible):
```dockerfile
# Copy helper scripts early
COPY docker/ /tmp/docker/

# Run the scripts
RUN python3 /tmp/docker/patch_buildout.py
RUN python3 /tmp/docker/create_sitecustomize.py
# ...
RUN python3 /tmp/docker/fix_package_names.py && rm -rf /tmp/docker
```

## Benefits

- ✅ **Compatible with all Docker versions** (including pre-23.0)
- ✅ **More maintainable** - Python scripts are separate files with syntax highlighting
- ✅ **Easier to test** - Scripts can be run independently
- ✅ **Better debugging** - Line numbers in errors match actual file line numbers

## Testing

To verify the fix works:

```bash
docker --version  # Works with any version
docker-compose build
```

The build should complete without parse errors.
