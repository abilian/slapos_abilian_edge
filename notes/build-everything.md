# Building All Components and Software Releases

This guide documents how to build all SlapOS components and software releases using Docker.

## Prerequisites

- Docker image built: `docker-compose build`
- Fixes applied (already done):
  - `slapos.core = 1.20.1` in `stack/slapos.cfg`
  - `FORCE_UNSAFE_CONFIGURE=1` in `docker-compose.yml`

## Commands

### Build All Components

```bash
SLAPOS_CACHE=1 docker-compose run --rm build-all components
```

### Build All Software Releases

```bash
SLAPOS_CACHE=1 docker-compose run --rm build-all software
```

### Build Everything (Components + Software)

```bash
SLAPOS_CACHE=1 docker-compose run --rm build-all all
```

## Options

| Option | Description | Example |
|--------|-------------|---------|
| `--timeout <seconds>` | Timeout per item (default: 1800s) | `--timeout 7200` |
| `--only <items>` | Build only specific items (comma-separated) | `--only gitlab,erp5` |
| `--resume-from <item>` | Skip items before this one | `--resume-from redis` |

### Examples

```bash
# Longer timeout for complex software (2 hours per item)
SLAPOS_CACHE=1 docker-compose run --rm build-all software --timeout 7200

# Build only specific software releases
SLAPOS_CACHE=1 docker-compose run --rm build-all software --only gitlab,erp5,nextcloud

# Resume a failed batch from a specific component
SLAPOS_CACHE=1 docker-compose run --rm build-all components --resume-from redis

# Real-time verbose output
SLAPOS_CACHE=1 SLAPOS_SHOW_OUTPUT=1 docker-compose run --rm build-all components
```

## Output Structure

```
build/
├── components/                 # Built components
│   └── <name>/
│       └── parts/              # Compiled artifacts
├── software/                   # Built software releases
│   └── <name>/
│       └── parts/              # Compiled artifacts
├── logs/                       # Build logs
│   ├── component_<timestamp>/
│   │   └── <name>.log
│   └── software_<timestamp>/
│       └── <name>.log
└── reports/                    # Summary reports
    ├── component_report_<timestamp>.txt
    ├── component_report_<timestamp>.json
    ├── software_report_<timestamp>.txt
    └── software_report_<timestamp>.json
```

## Checking Progress

### During Build

```bash
# Count built items
ls build/components/ 2>/dev/null | wc -l
ls build/software/ 2>/dev/null | wc -l

# Watch logs directory for new completions
watch -n 5 'ls -lt build/logs/*/  | head -10'
```

### After Build

```bash
# View latest text report
cat $(ls -t build/reports/*.txt 2>/dev/null | head -1)

# List failed builds from JSON report
cat $(ls -t build/reports/*.json 2>/dev/null | head -1) | python -m json.tool | grep -A2 '"status": "failed"'
```

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `SLAPOS_CACHE` | `0` | Enable network cache (`1` = enabled) |
| `SLAPOS_SHOW_OUTPUT` | `0` | Real-time build output (`1` = enabled) |

## Expected Build Times

With network cache enabled on x86_64:

| Type | Count | Estimated Time |
|------|-------|----------------|
| Components | ~420 | Several hours |
| Software releases | ~70 | Many hours (varies greatly) |

Cache hit rates of 80-95% significantly reduce build times compared to building from source.

## Troubleshooting

### Build hangs or times out

Increase the timeout:
```bash
SLAPOS_CACHE=1 docker-compose run --rm build-all software --timeout 14400  # 4 hours
```

### Resume after failure

Find the last successful item in the report, then resume:
```bash
SLAPOS_CACHE=1 docker-compose run --rm build-all software --resume-from <last-successful-item>
```

### Check specific failure

```bash
# Find the log for a failed item
cat build/logs/software_<timestamp>/<failed-item>.log | tail -100
```

### Clean and retry a specific item

```bash
rm -rf build/software/<name>
SLAPOS_CACHE=1 docker-compose run --rm build-component software <name>
```
