# Troubleshooting Guide

## Quick Diagnostics

### 1. Run the Diagnostic Tool

```bash
docker compose run --rm diagnose
```

This will test:
- Network connectivity to shacache/shadir
- `slapos.libnetworkcache` installation
- Cache download capability
- Recent build log analysis
- Environment configuration

### 2. Access Build Logs

**Logs are now accessible on the host machine!**

```bash
# Logs are in ./build/ directory on your host
ls -la build/logs/

# View most recent build logs
ls -lt build/logs/ | head -n 5

# View a specific log
cat build/logs/software_20260121_160012/abilian-sbe.log

# Search for errors in logs
grep -i "error" build/logs/software_*/abilian-sbe.log

# See cache-related messages
grep -i "networkcache" build/logs/software_*/abilian-sbe.log
```

### 3. View Real-Time Build Output

For long-running builds, see what's happening in real-time:

```bash
# Enable real-time output (verbose)
SLAPOS_SHOW_OUTPUT=1 docker compose run --rm build-all software --only abilian-sbe
```

This will stream build output to your console with `[component-name]` prefixes.

## Common Issues and Solutions

### Issue 1: "networkcache: Trying to download... from networkcache failed"

**Diagnosis:**
```bash
# Test cache connectivity
docker compose run --rm diagnose

# Check if cache is actually enabled
docker compose run --rm build-component bash -c 'echo $SLAPOS_CACHE'
```

**Possible Causes:**

1. **Cache miss** (package not in cache) - **This is normal!**
   - The cache doesn't have every package
   - First builds will have many misses
   - Solution: Build will continue from source (slower but works)

2. **Network connectivity issue**
   ```bash
   # Test from container
   docker compose run --rm build-component bash -c "curl -I http://shacache.nxdcdn.com"
   ```

3. **slapos.libnetworkcache not installed**
   - Check diagnostic output
   - Should be fixed in latest Dockerfile

**Solution:**
- If cache misses: Accept that first builds are slower
- If network issues: Check firewall/proxy settings
- If library missing: Rebuild Docker image

### Issue 2: Build Timeouts

**Symptoms:**
```
[1/70]   Building abilian-sbe... FAILED (34405.6s)
```

**Causes:**
1. Default timeout too short for large builds
2. Actual hung build
3. Network slowness downloading from source

**Solutions:**

```bash
# Increase timeout (in seconds)
docker compose run --rm build-all software --timeout 72000  # 20 hours

# Build just one component to test
SLAPOS_SHOW_OUTPUT=1 docker compose run --rm build-component software abilian-sbe

# Check if it's actually building or stuck
SLAPOS_SHOW_OUTPUT=1 docker compose run --rm build-all software --only abilian-sbe --timeout 72000
```

### Issue 3: Can't See What's Happening

**Solution: Enable real-time output**

```bash
# For batch builds
SLAPOS_SHOW_OUTPUT=1 docker compose run --rm build-all software

# For single component
docker compose run --rm build-component component redis
# (single component builds always show output)
```

### Issue 4: Logs Not Accessible

**Fixed!** Logs are now bind-mounted to `./build/` on your host.

```bash
# Verify logs are accessible
ls -la build/logs/

# If directory doesn't exist
mkdir -p build/logs build/reports

# Rebuild to use new mount
docker compose down
docker compose run --rm build-all components --only xz-utils
```

### Issue 5: High Failure Rate

**Diagnosis Steps:**

1. **Check if it's cache-related**
   ```bash
   # Try without cache
   SLAPOS_CACHE=0 docker compose run --rm build-component component xz-utils

   # Try with cache
   SLAPOS_CACHE=1 docker compose run --rm build-component component xz-utils
   ```

2. **Analyze failure patterns**
   ```bash
   # Check build reports
   cat build/reports/software_report_*.txt

   # Count failure types
   grep "Error:" build/logs/software_*/. log | cut -d: -f3 | sort | uniq -c | sort -rn
   ```

3. **Test specific components**
   ```bash
   # Build one component with verbose output
   SLAPOS_SHOW_OUTPUT=1 docker compose run --rm build-component component redis
   ```

## Understanding Cache Behavior

### Cache Hits vs Misses

- **Cache Hit**: Pre-compiled binary downloaded from shacache (fast)
- **Cache Miss**: Build from source code (slow but normal)

```
Example output:
[5/70]   Building buildout-testing... OK (2833.8s) [cache: 79hit/38miss]
                                                    ^This is good!
```

**What's Normal:**
- 50-90% cache hit rate on x86_64 for common components
- 0-20% cache hit rate on first run
- 0% cache hit rate on custom/modified components

### Enabling Cache

Three ways:

```bash
# 1. Environment variable (recommended)
SLAPOS_CACHE=1 docker compose run --rm build-all software

# 2. Command-line flag
docker compose run --rm build-component component redis --use-cache

# 3. .env file
echo "SLAPOS_CACHE=1" >> .env
docker compose run --rm build-all software
```

## Advanced Debugging

### 1. Interactive Container

```bash
# Enter container for manual debugging
docker compose run --rm build-component bash

# Inside container:
cd /slapos
python scripts/diagnose_cache.py
python scripts/build.py component redis --use-cache
```

### 2. Examine Build Configuration

```bash
# See generated buildout.cfg
docker compose run --rm build-component component redis
cat build/components/redis/buildout.cfg
```

### 3. Test Network Cache Manually

```bash
# Inside container
docker compose run --rm build-component bash

# Test cache access
python3 -c "import urllib.request; print(urllib.request.urlopen('http://shacache.nxdcdn.com').status)"

# Check if slapos.libnetworkcache is available
python3 -c "import slapos.libnetworkcache; print('OK')"
```

## Performance Optimization

### 1. Parallel Builds

Currently, builds run sequentially. To speed up:

```bash
# Build only specific components
docker compose run --rm build-all components --only "redis,postgresql,python3"

# Or split into multiple terminals
Terminal 1: docker compose run --rm build-component component redis
Terminal 2: docker compose run --rm build-component component postgresql
Terminal 3: docker compose run --rm build-component component python3
```

### 2. Use Cache Aggressively

```bash
# Always use cache for x86_64
export SLAPOS_CACHE=1

# Or add to ~/.bashrc
echo "export SLAPOS_CACHE=1" >> ~/.bashrc
```

### 3. Skip Failed Components

```bash
# Resume from specific component
docker compose run --rm build-all software --resume-from gitlab
```

## Getting Help

### Collect Diagnostic Info

```bash
# 1. Run diagnostics
docker compose run --rm diagnose > diagnostics.txt

# 2. Get recent build report
cp build/reports/software_report_*.txt latest-report.txt

# 3. Get platform info
docker --version
uname -m  # Should show x86_64
```

### File Structure

```
build/
├── logs/
│   ├── component_20260121_150000/
│   │   ├── redis.log
│   │   ├── postgresql.log
│   │   └── ...
│   └── software_20260121_160012/
│       ├── abilian-sbe.log
│       └── ...
├── reports/
│   ├── component_report_20260121_150000.txt
│   ├── component_report_20260121_150000.json
│   └── ...
├── components/
│   ├── redis/
│   │   ├── buildout.cfg (generated)
│   │   ├── parts/
│   │   └── bin/
│   └── ...
└── software/
    └── ...
```

## Quick Reference

```bash
# Diagnose issues
docker compose run --rm diagnose

# Build with cache + real-time output
SLAPOS_CACHE=1 SLAPOS_SHOW_OUTPUT=1 docker compose run --rm build-component component redis

# Build all with increased timeout
docker compose run --rm build-all software --timeout 72000

# Access logs
ls -la build/logs/
cat build/logs/software_*/abilian-sbe.log

# Check reports
cat build/reports/software_report_*.txt
```
