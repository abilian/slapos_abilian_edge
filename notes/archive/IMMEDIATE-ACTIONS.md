# Immediate Actions - Diagnostic & Fix Guide

## What's Been Fixed

✅ **Logs are now accessible on host machine** - No more trapped logs in Docker volumes!
✅ **Real-time output streaming** - See what's building in real-time
✅ **Diagnostic tool** - Quickly diagnose cache and network issues
✅ **Better error visibility** - Logs written to `./build/` directory

## Step 1: Diagnose the Current Situation

Run this FIRST to understand what's happening:

```bash
# Test cache connectivity and configuration
docker compose run --rm diagnose
```

This will tell you:
- ✓ Is shacache accessible?
- ✓ Is slapos.libnetworkcache installed?
- ✓ Can downloads from cache work?
- ✓ What errors are in recent logs?

## Step 2: Access Your Build Logs

Logs from your failed run are now accessible:

```bash
# List all build logs
ls -la build/logs/

# Your most recent run
ls -la build/logs/software_20260121_160012/

# View abilian-sbe log (the one that took 9.5 hours)
cat build/logs/software_20260121_160012/abilian-sbe.log

# Search for the actual error
grep -A 5 -B 5 "Error\|error\|failed\|Failed" build/logs/software_20260121_160012/abilian-sbe.log | head -50

# Check what cache was doing
grep -i "networkcache" build/logs/software_20260121_160012/abilian-sbe.log | head -20
```

## Step 3: Test With a Simple Component

Before running full builds, test with something quick:

```bash
# Test a small component WITH cache
SLAPOS_CACHE=1 docker compose run --rm build-component component xz-utils

# You should see:
# - Cache statistics at the end
# - Build completes in under 5 minutes
# - Clear success/failure message
```

## Step 4: Re-run With Visibility

Try again with real-time output to see what's happening:

```bash
# Build ONE software component with full visibility
SLAPOS_CACHE=1 SLAPOS_SHOW_OUTPUT=1 docker compose run --rm \
  build-component software abilian-sbe

# This will:
# - Show real-time build output
# - Show cache hits/misses as they happen
# - Let you see if it's stuck or progressing
# - No timeout (runs until complete or fails)
```

## Step 5: Understand Your Errors

Based on your output, you had errors like:

```
networkcache: Trying to download pypi:flask=3.0.3 from networkcache failed
```

### This Could Mean:

1. **Cache miss (NORMAL)** - Flask 3.0.3 not in cache, building from PyPI instead
   - Not an error, just slower
   - Should continue building

2. **Network issue** - Can't reach shacache or PyPI
   - Run diagnostic: `docker compose run --rm diagnose`
   - Check: `curl -I http://shacache.nxdcdn.com`

3. **Timeout** - Build took too long
   - Default: 36000 seconds (10 hours)
   - You hit this for abilian-sbe

## Step 6: Address Timeouts

Your abilian-sbe build took 9.5 hours and failed. Options:

### Option A: Increase Timeout

```bash
# Give it 20 hours
SLAPOS_CACHE=1 docker compose run --rm build-all software \
  --only abilian-sbe \
  --timeout 72000
```

### Option B: Build Interactively

```bash
# Build without timeout wrapper
docker compose run --rm build-component bash
# Then inside:
cd /slapos
SLAPOS_CACHE=1 python scripts/build.py software abilian-sbe
```

### Option C: Check if it's Actually Building

```bash
# Watch in real-time
SLAPOS_CACHE=1 SLAPOS_SHOW_OUTPUT=1 docker compose run --rm \
  build-component software abilian-sbe
```

## Recommended Immediate Commands

```bash
# 1. Run diagnostics
docker compose run --rm diagnose

# 2. Check what failed in your last run
cat build/reports/software_report_20260121_160012.txt

# 3. Look at first failure in detail
cat build/logs/software_20260121_160012/abilian-sbe.log | grep -i error | head -20

# 4. Test cache with simple component
SLAPOS_CACHE=1 docker compose run --rm build-component component redis

# 5. Re-run ONE failed software with visibility
SLAPOS_CACHE=1 SLAPOS_SHOW_OUTPUT=1 docker compose run --rm \
  build-component software backupserver
```

## Understanding Cache Messages

### Normal (Not an Error):
```
networkcache: Trying to download pypi:flask=3.0.3 from networkcache failed
Downloading from PyPI instead...
```
→ This is a **cache miss**. Build continues from source.

### Actual Problem:
```
networkcache: Cannot connect to http://shacache.nxdcdn.com
Error: Network unreachable
```
→ This is a **connectivity issue**. Run diagnostics.

## Next Steps Decision Tree

```
Run: docker compose run --rm diagnose
│
├─ All tests pass?
│  ├─ YES → Cache is working
│  │        Problem is likely:
│  │        - Build timeouts (increase --timeout)
│  │        - Actual build errors (check logs)
│  │        - Cache misses (normal, just slow)
│  │
│  └─ NO → Fix reported issues first
│           - Install slapos.libnetworkcache?
│           - Fix network connectivity?
│           - Check firewall settings?
│
└─ After diagnostics:
   │
   ├─ Test simple component:
   │  SLAPOS_CACHE=1 docker compose run --rm build-component component redis
   │
   └─ If that works, try failed software with visibility:
      SLAPOS_CACHE=1 SLAPOS_SHOW_OUTPUT=1 docker compose run --rm \
        build-component software abilian-sbe
```

## Key Files & Locations

```
./build/                          ← Build output (ON YOUR HOST NOW!)
  ├── logs/                       ← All build logs
  │   └── software_20260121_160012/  ← Your failed run
  │       ├── abilian-sbe.log
  │       ├── backupserver.log
  │       └── ...
  ├── reports/                    ← Summary reports
  │   ├── software_report_20260121_160012.txt
  │   └── software_report_20260121_160012.json
  └── software/                   ← Built artifacts
      └── abilian-sbe/

./scripts/
  ├── diagnose_cache.py          ← NEW: Diagnostic tool
  ├── build.py                   ← Updated with cache support
  └── build_all.py               ← Updated with streaming

./notes/
  ├── troubleshooting-guide.md   ← Full guide
  ├── shacache-solution.md       ← How cache works
  └── IMMEDIATE-ACTIONS.md       ← This file
```

## TL;DR - Do This Now

```bash
# 1. Diagnose
docker compose run --rm diagnose

# 2. Check your failed run logs
ls -la build/logs/software_20260121_160012/
cat build/logs/software_20260121_160012/abilian-sbe.log | tail -100

# 3. Try one simple build with cache
SLAPOS_CACHE=1 docker compose run --rm build-component component redis

# 4. If that works, re-run with visibility
SLAPOS_CACHE=1 SLAPOS_SHOW_OUTPUT=1 docker compose run --rm \
  build-component software abilian-sbe
```
