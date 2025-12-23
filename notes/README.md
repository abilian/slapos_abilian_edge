# Notes Index

This directory contains documentation for building SlapOS components and software releases using Docker.

## Quick Start

**New here?** Start with these in order:

1. **[01-slapos-overview.md](01-slapos-overview.md)** - What is SlapOS? Core concepts, architecture, terminology
2. **[02-quick-start.md](02-quick-start.md)** - Get building in 5 minutes
3. **[03-docker-build-reference.md](03-docker-build-reference.md)** - Complete build system reference

## Document Map

| Document | Purpose | Audience |
|----------|---------|----------|
| [01-slapos-overview.md](01-slapos-overview.md) | SlapOS concepts, architecture, cookbook | New users |
| [02-quick-start.md](02-quick-start.md) | Build abilian-sbe and everything else | All users |
| [03-docker-build-reference.md](03-docker-build-reference.md) | Docker services, volumes, commands | Power users |
| [04-network-cache.md](04-network-cache.md) | Shacache configuration and usage | Power users |
| [05-troubleshooting.md](05-troubleshooting.md) | Common issues and solutions | When things break |
| [06-technical-notes.md](06-technical-notes.md) | Deep dive: PEP 503, buildout patches | Maintainers |

## Common Tasks

### Build abilian-sbe
```bash
SLAPOS_CACHE=1 SLAPOS_SHOW_OUTPUT=1 docker-compose run --rm build-component software abilian-sbe
```

### Build all software releases
```bash
SLAPOS_CACHE=1 docker-compose run --rm build-all software
```

### Diagnose issues
```bash
docker-compose run --rm diagnose
```

### Check what's been built
```bash
ls build/software/*/parts/ | head -20
```

## Key Fixes Applied

These fixes are already in the codebase:

| Fix | File | Issue |
|-----|------|-------|
| `slapos.core = 1.20.1` | `stack/slapos.cfg` | 1.19.0 broken on PyPI |
| `FORCE_UNSAFE_CONFIGURE=1` | `docker-compose.yml` | GNU packages reject root |
| PEP 503 name normalization | `Dockerfile` | buildout/pkg_resources mismatch |
| gnu-config URL | `component/gnu-config/buildout.cfg` | Savannah URL broken |

