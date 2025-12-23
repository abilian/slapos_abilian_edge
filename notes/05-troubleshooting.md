# Troubleshooting Guide

## Quick Diagnostics

### 1. Run the Diagnostic Tool

```bash
docker-compose run --rm diagnose
```

Tests:
- Network connectivity to shacache/shadir
- `slapos.libnetworkcache` installation
- Cache download capability
- Environment configuration

### 2. Access Build Logs

```bash
# List logs
ls -la build/logs/

# View specific log
cat build/logs/software_*/abilian-sbe.log | tail -100

# Search for errors
grep -i "error" build/logs/software_*/*.log
```

### 3. Real-Time Output

```bash
SLAPOS_SHOW_OUTPUT=1 docker-compose run --rm build-component software abilian-sbe
```

## Common Issues

### Issue 1: AssertionError in zc.buildout

```
assert newdist is not None  # newloc above is missing our dist?!
AssertionError
```

**Causes:**
- Corrupted/partial egg from previous attempt
- Broken package on PyPI (version mismatch)

**Solution:**
```bash
# Clean eggs and retry
rm -rf build/software/abilian-sbe/eggs/*
SLAPOS_CACHE=1 docker-compose run --rm build-component software abilian-sbe
```

If it keeps failing at the same package, check if the version is broken on PyPI (like `slapos.core==1.19.0` was).

### Issue 2: Configure Error "should not run as root"

```
configure: error: you should not run configure as root
```

**Cause:** GNU packages (coreutils, etc.) reject root builds.

**Solution:** Already fixed in `docker-compose.yml`:
```yaml
environment:
  - FORCE_UNSAFE_CONFIGURE=1
```

If you see this, ensure you're using the latest docker-compose.yml.

### Issue 3: Build Timeouts

```
[1/70]   Building abilian-sbe... FAILED (34405.6s)
```

**Solution:**
```bash
# Increase timeout (4 hours)
docker-compose run --rm build-all software --timeout 14400

# Or build individually (no timeout)
SLAPOS_CACHE=1 SLAPOS_SHOW_OUTPUT=1 docker-compose run --rm build-component software abilian-sbe
```

### Issue 4: Network Cache Errors

```
networkcache: Trying to download... from networkcache failed
```

**This is often normal!** It means the package isn't in the cache, so buildout falls back to source.

**To verify cache is working:**
```bash
docker-compose run --rm diagnose
```

### Issue 5: "Package not found" Errors

```
pkg_resources.DistributionNotFound: The 'zc.buildout' distribution was not found
```

**Solution:** Rebuild Docker image:
```bash
docker-compose build --no-cache
```

### Issue 6: MD5 Mismatch

```
MD5 checksum mismatch downloading 'https://...'
```

**Cause:** Upstream file changed.

**Solutions:**
1. Enable cache (bypasses source downloads): `SLAPOS_CACHE=1`
2. Update checksum in component's `buildout.cfg`

### Issue 7: Version Conflicts

```
We already have: zope-interface 7.0
but slapos.core requires 'zope.interface>=4.0'
```

**Cause:** PEP 503 name normalization mismatch.

**Solution:** Should be fixed by Dockerfile patches. If you see this, rebuild image:
```bash
docker-compose build --no-cache
```

### Issue 8: Missing System Dependencies

```
fatal error: some_header.h: No such file or directory
```

**Cause:** Missing development package.

**Solution:** Add to Dockerfile and rebuild:
```dockerfile
RUN apt-get install -y libsomething-dev
```

## Debugging Techniques

### Interactive Container

```bash
docker-compose run --rm --entrypoint bash build-component

# Inside container
cd /slapos
python scripts/build.py component redis --use-cache
```

### Examine Generated Config

```bash
cat build/software/abilian-sbe/buildout.cfg
```

### Check What's Installed

```bash
docker-compose run --rm --entrypoint bash build-component -c "pip list | grep slapos"
```

### Test Network Manually

```bash
docker-compose run --rm --entrypoint bash build-component -c "curl -I http://shacache.nxdcdn.com"
```

## Performance Tips

### Always Use Cache on x86_64

```bash
export SLAPOS_CACHE=1
# Or add to ~/.bashrc
```

### Skip Known-Failing Components

```bash
docker-compose run --rm build-all software --resume-from gitlab
```

### Build Specific Items Only

```bash
docker-compose run --rm build-all software --only "abilian-sbe,gitlab,erp5"
```

### Parallel Builds (Manual)

```bash
# Terminal 1
SLAPOS_CACHE=1 docker-compose run --rm build-component component redis

# Terminal 2
SLAPOS_CACHE=1 docker-compose run --rm build-component component postgresql
```

## Collecting Diagnostic Info

When reporting issues:

```bash
# 1. Run diagnostics
docker-compose run --rm diagnose > diagnostics.txt

# 2. Get platform info
echo "Docker: $(docker --version)" >> diagnostics.txt
echo "Arch: $(uname -m)" >> diagnostics.txt

# 3. Get latest report
cat build/reports/*.txt >> diagnostics.txt 2>/dev/null

# 4. Get error logs
grep -i "error" build/logs/*/*.log >> diagnostics.txt 2>/dev/null
```

## File Locations Reference

```
build/
├── logs/                       # Build logs
│   └── software_<timestamp>/
│       └── <name>.log
├── reports/                    # Summary reports
│   └── software_report_*.txt
├── software/                   # Built releases
│   └── <name>/
│       ├── buildout.cfg        # Generated config
│       ├── parts/              # Built components
│       └── eggs/               # Python eggs
└── components/                 # Built components
```

## Quick Reference

```bash
# Diagnose
docker-compose run --rm diagnose

# Build with cache + verbose
SLAPOS_CACHE=1 SLAPOS_SHOW_OUTPUT=1 docker-compose run --rm build-component software abilian-sbe

# Clean and retry
rm -rf build/software/abilian-sbe/eggs/*
SLAPOS_CACHE=1 docker-compose run --rm build-component software abilian-sbe

# Check logs
cat build/logs/software_*/*.log | grep -i error

# Interactive debug
docker-compose run --rm --entrypoint bash build-component
```
