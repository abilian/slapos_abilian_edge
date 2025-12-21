# Next Steps

## Immediate Fixes (Easy)

### 1. Add meson to Docker image
Many Python scientific packages require meson for building.

```dockerfile
RUN pip install meson ninja
```

### 2. Fix coreutils root issue
Add environment variable to allow running configure as root.

```dockerfile
ENV FORCE_UNSAFE_CONFIGURE=1
```

### 3. Fix bazel Python 2 syntax
Update `component/bazel/buildout.cfg` to use Python 3 octal syntax:
```python
# Change 0644 to 0o644
os.chmod(crosstool_path, 0o644)
```

## Medium-Term Improvements

### 4. Enable Network Cache
Modify `scripts/build.py` to optionally enable shacache:

```python
[networkcache]
download-cache-url = http://shacache.nxdcdn.com
download-dir-url = http://shadir.nxdcdn.com
```

Install `slapos.libnetworkcache` in Docker image. Note: May not help on aarch64.

### 5. Update Checksums
Several upstream files have changed. Options:
- Update MD5 checksums in component configs
- Find alternative mirrors
- Build from git repositories instead

Affected components:
- `boost-lib`
- `cclient` (apache-php dependency)

### 6. Add aarch64 Support
For architecture-specific components, add aarch64 sections:

```ini
[consul:linux and platform.machine() == "aarch64"]
_url = linux_arm64
md5sum = <checksum>
```

This requires finding aarch64 binaries from upstream.

## Long-Term Considerations

### 7. Build on x86_64
For production use, build on x86_64 to:
- Match SlapOS infrastructure
- Benefit from network cache
- Avoid architecture-specific issues

### 8. Upstream Contributions
Consider contributing fixes back to Nexedi:
- PEP 503 name normalization patch for slapos.buildout
- Python 3 syntax fixes
- aarch64 support for components

### 9. Complete Build Run
After applying fixes, run full `build-all` to get complete picture:

```bash
docker compose build --no-cache
docker compose run --rm build-all components --timeout 3600
```

Review reports and categorize remaining failures.

## Questions to Investigate

1. **Why do some components timeout?** Are they legitimately slow or stuck?
2. **Can we use a local cache?** Set up local shacache for repeated builds
3. **Which components are critical?** Focus on dependencies for target software (abilian-sbe)

## Command Reference

```bash
# Rebuild Docker image
docker compose build --no-cache

# Build single component
docker compose run --rm build-component component <name>

# Build all components
docker compose run --rm build-all components

# View logs
docker run --rm -v slapos_abilian_edge_slapos-build:/slapos/build \
  slapos-build cat /slapos/build/logs/component_<timestamp>/<name>.log

# Check build reports
docker run --rm -v slapos_abilian_edge_slapos-build:/slapos/build \
  slapos-build cat /slapos/build/reports/component_report_<timestamp>.txt
```
