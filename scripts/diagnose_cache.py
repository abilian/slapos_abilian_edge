#!/usr/bin/env python3
"""
Diagnostic script for SlapOS network cache (shacache).

Tests connectivity, cache access, and provides detailed diagnostics
about why cache might be failing.
"""

import sys
import subprocess
import urllib.request
import urllib.error
import json
from pathlib import Path

# Cache URLs
SHACACHE_URL = "http://shacache.nxdcdn.com"
SHADIR_URL = "http://shadir.nxdcdn.com"

def print_header(title):
    """Print a section header."""
    print(f"\n{'=' * 70}")
    print(f"{title}")
    print('=' * 70)

def test_connectivity(url, name):
    """Test if a URL is accessible."""
    print(f"\nTesting {name}: {url}")
    try:
        req = urllib.request.Request(url, method='HEAD')
        with urllib.request.urlopen(req, timeout=10) as response:
            status = response.status
            print(f"  ✓ Status: {status}")
            print(f"  ✓ Accessible")
            return True
    except urllib.error.HTTPError as e:
        print(f"  ✗ HTTP Error: {e.code} {e.reason}")
        return False
    except urllib.error.URLError as e:
        print(f"  ✗ URL Error: {e.reason}")
        return False
    except Exception as e:
        print(f"  ✗ Error: {e}")
        return False

def check_slapos_libnetworkcache():
    """Check if slapos.libnetworkcache is installed."""
    print("\nChecking slapos.libnetworkcache installation...")
    try:
        result = subprocess.run(
            [sys.executable, "-m", "pip", "show", "slapos.libnetworkcache"],
            capture_output=True,
            text=True,
            check=False
        )
        if result.returncode == 0:
            # Parse version from output
            for line in result.stdout.split('\n'):
                if line.startswith('Version:'):
                    version = line.split(':')[1].strip()
                    print(f"  ✓ Installed: version {version}")
                    return True
        else:
            print("  ✗ NOT installed")
            print("  ⚠ Run: pip install slapos.libnetworkcache")
            return False
    except Exception as e:
        print(f"  ✗ Error checking: {e}")
        return False

def test_cache_download():
    """Try to download something from the cache."""
    print("\nTesting cache download (this may take a moment)...")

    # Test with a simple URL - try to get directory listing
    test_url = f"{SHADIR_URL}/"
    try:
        req = urllib.request.Request(test_url)
        with urllib.request.urlopen(req, timeout=30) as response:
            content = response.read()
            print(f"  ✓ Can fetch from shadir")
            print(f"  ✓ Response size: {len(content)} bytes")
            return True
    except Exception as e:
        print(f"  ✗ Cannot fetch from shadir: {e}")
        return False

def analyze_build_logs():
    """Analyze recent build logs for cache-related errors."""
    print("\nAnalyzing recent build logs...")

    logs_dir = Path("/slapos/build/logs")
    if not logs_dir.exists():
        print("  ⚠ No logs directory found at /slapos/build/logs")
        return

    # Find most recent log directory
    log_dirs = sorted([d for d in logs_dir.iterdir() if d.is_dir()],
                     key=lambda x: x.stat().st_mtime, reverse=True)

    if not log_dirs:
        print("  ⚠ No log directories found")
        return

    recent_dir = log_dirs[0]
    print(f"  Analyzing: {recent_dir.name}")

    # Look for cache-related errors
    cache_errors = []
    timeout_errors = []
    network_errors = []

    for log_file in recent_dir.glob("*.log"):
        try:
            with open(log_file, 'r') as f:
                content = f.read()

                # Count different types of errors
                if 'networkcache:' in content.lower():
                    lines = content.split('\n')
                    for line in lines:
                        if 'networkcache:' in line.lower() and ('error' in line.lower() or 'trying' in line.lower()):
                            cache_errors.append((log_file.name, line.strip()[:100]))
                            break

                if 'timeout' in content.lower() or 'timed out' in content.lower():
                    timeout_errors.append(log_file.name)

                if 'urlopen error' in content.lower() or 'connection' in content.lower():
                    network_errors.append(log_file.name)

        except Exception as e:
            continue

    # Report findings
    total_logs = len(list(recent_dir.glob("*.log")))
    print(f"\n  Total logs analyzed: {total_logs}")

    if cache_errors:
        print(f"\n  ⚠ Found {len(cache_errors)} logs with cache errors:")
        for name, error in cache_errors[:5]:  # Show first 5
            print(f"    - {name}")
            print(f"      {error}")

    if timeout_errors:
        print(f"\n  ⚠ Found {len(timeout_errors)} logs with timeout errors")

    if network_errors:
        print(f"\n  ⚠ Found {len(network_errors)} logs with network errors")

def check_environment():
    """Check environment variables."""
    import os
    print("\nChecking environment variables...")

    slapos_cache = os.environ.get('SLAPOS_CACHE', '')
    print(f"  SLAPOS_CACHE: {slapos_cache if slapos_cache else '(not set)'}")

    if slapos_cache.lower() in ('1', 'true', 'yes'):
        print("  ✓ Cache is enabled via environment variable")
    else:
        print("  ⚠ Cache is not enabled via environment variable")
        print("    To enable: export SLAPOS_CACHE=1")

def main():
    """Run all diagnostics."""
    print_header("SlapOS Network Cache Diagnostic Tool")

    print("\nThis tool will test:")
    print("  1. Network connectivity to shacache/shadir")
    print("  2. slapos.libnetworkcache installation")
    print("  3. Actual cache downloads")
    print("  4. Recent build log analysis")
    print("  5. Environment configuration")

    # Run tests
    results = {
        'shacache_connectivity': test_connectivity(SHACACHE_URL, "shacache"),
        'shadir_connectivity': test_connectivity(SHADIR_URL, "shadir"),
        'libnetworkcache_installed': check_slapos_libnetworkcache(),
        'cache_download': test_cache_download(),
    }

    check_environment()
    analyze_build_logs()

    # Summary
    print_header("DIAGNOSTIC SUMMARY")

    all_pass = all(results.values())

    if all_pass:
        print("\n✓ All basic tests passed!")
        print("\nThe network cache infrastructure appears to be working.")
        print("\nIf builds are still failing, possible causes:")
        print("  1. Cache misses (packages not in cache) - this is normal")
        print("  2. Build-time errors unrelated to cache")
        print("  3. Architecture mismatch (aarch64 vs x86_64)")
        print("  4. Timeout issues with large downloads")
    else:
        print("\n✗ Some tests failed. Issues detected:")
        for test, passed in results.items():
            status = "✓" if passed else "✗"
            print(f"  {status} {test}")

        print("\nRecommended actions:")
        if not results['libnetworkcache_installed']:
            print("  1. Install slapos.libnetworkcache:")
            print("     pip install slapos.libnetworkcache")

        if not results['shacache_connectivity'] or not results['shadir_connectivity']:
            print("  2. Check network connectivity:")
            print("     - Verify internet access")
            print("     - Check if firewall blocks http://shacache.nxdcdn.com")
            print("     - Try: curl -I http://shacache.nxdcdn.com")

        if not results['cache_download']:
            print("  3. Cache download failed:")
            print("     - Check DNS resolution")
            print("     - Verify proxy settings if behind corporate firewall")

    print("\n" + "=" * 70)

    return 0 if all_pass else 1

if __name__ == "__main__":
    sys.exit(main())
