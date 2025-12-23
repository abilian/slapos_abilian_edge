# SlapOS Overview

This document provides an introduction to SlapOS concepts, architecture, and the cookbook system.

## What is SlapOS?

**SlapOS** is a decentralized "Cloud Operating System" and orchestration engine used to deploy, manage, and configure complex software services across distributed infrastructure. It relies heavily on **Python** and **zc.buildout**.

## Core Concepts

### Software vs. Instance

SlapOS strictly separates the installation of code from the execution of services:

| Concept | Description |
|---------|-------------|
| **Software Release** | Definition (in `software.cfg`) describing how to compile and install a software stack |
| **Instance** | A live, running service instantiated from a Software Release |
| **Partition** | Isolated environment (directory with specific permissions) where instances run |

A single Software Release can spawn multiple Instances (e.g., one KVM software release can spawn 10 different Virtual Machines).

### Partitions

A **Partition** (or "Computer Partition" / `slappart`) is the fundamental unit of deployment in SlapOS. Think of it as a lightweight, "unix-native" container.

**Characteristics:**

1. **Filesystem Isolation**
   - Directory on host machine (e.g., `/srv/slapgrid/slappartNN`)
   - Unique Unix user and group per partition
   - Self-contained structure:
     - `etc/` - Configuration files
     - `var/` - Logs, PID files, sockets
     - `srv/` - Persistent data
     - `bin/` - Startup scripts

2. **Network Identity**
   - Dedicated IPv6 address per partition
   - IPv4 typically shared via Frontend proxy

3. **Code/Data Separation**
   - Software Release: shared, read-only binaries
   - Partition: configuration and data only

### Configuration-Driven Deployment

SlapOS uses a "Cookbook" approach with **Recipes** (Python scripts) to handle tasks:

- **Input Parameters:** JSON schemas define configuration options
- **Publishing Results:** Instances publish connection parameters (URLs, passwords, IPs) back to users

## Architecture

### Two-Phase Model

**Phase 1 - Build** (`software.cfg`):
- Downloads/compiles source code
- Runs once per computer
- Result is read-only

**Phase 2 - Instantiation** (`instance.cfg.in` → `instance.cfg`):
- Uses Jinja2 templating
- Generates service scripts and configs
- Runs per instance/partition

### Resiliency (Pull-Backup Architecture)

Built-in high availability using three partitions:
- **Export** - Active instance, pushes data
- **Pull-Backup** - Stores backup history
- **Import** - Ready for failover restoration

### Networking

- **IPv6 Centric:** Internal communication uses IPv6
- **Frontend/Backend Separation:** Public IPv4 access via Frontend proxies (e.g., `rapid-cdn`)
- **Zero Knowledge:** Secrets handled locally within partitions

## The Cookbook (`slapos.cookbook`)

A collection of Python recipes for zc.buildout to configure and deploy services.

### Core Classes (`slapos.recipe.librecipe`)

| Class | Purpose |
|-------|---------|
| `GenericBaseRecipe` | Base class with helpers for files, wrappers, directories |
| `GenericSlapRecipe` | Adds SlapOS Master API integration |

### Recipe Categories

**Orchestration:**
- `slapos.recipe.request` - Request other instances from SlapOS Master
- `slapos.recipe.slapconfiguration` - Fetch user parameters
- `slapos.recipe.publish` - Publish connection parameters
- `slapos.recipe.switch_softwaretype` - Support multiple instance types

**Databases:**
- `slapos.recipe.postgres` - PostgreSQL setup
- `slapos.recipe.redis` - Redis configuration
- `slapos.recipe.generic_mysql` - MySQL management

**Networking:**
- `slapos.recipe.6tunnel` - IPv4/IPv6 tunneling
- `slapos.recipe.re6stnet` - Mesh networking

**Utilities:**
- `slapos.recipe.wrapper` - Generic startup script generator
- `slapos.recipe.dcron` - Per-partition cron
- `slapos.recipe.logrotate` - Log rotation
- `slapos.recipe.random` - Generate persistent passwords

### Common Patterns

1. **Promises:** Health checks that mark partitions as error state on failure
2. **Wrappers:** Shell scripts setting up environment before executing binaries
3. **Template Rendering:** Dynamic config generation via Jinja2
4. **Directory Structure:** Strict hierarchy (`etc/`, `srv/`, `var/`)

## Network Cache (Shacache)

SlapOS uses a network cache to store pre-built binaries:

| Service | URL | Purpose |
|---------|-----|---------|
| Shacache | http://shacache.nxdcdn.com | Binary downloads |
| Shadir | http://shadir.nxdcdn.com | Directory/metadata lookups |

Cache keys are based on:
- SHA512 of source URL
- Platform/architecture (x86_64, aarch64)
- Build options

## Nexedi's Buildout Fork

SlapOS uses a customized `zc.buildout` fork with:
- Network cache integration
- Shared parts support (`slapos.extension.shared`)
- Custom egg handling
- Binary stripping (`slapos.extension.strip`)

Standard buildout doesn't support these features.

## Software Release Examples

### Cloudooo (Document Conversion)
- LibreOffice wrapper with XML-RPC API
- HAProxy load balancing
- Xvfb for headless rendering

### PeerTube (Video Streaming)
- Full stack: PostgreSQL, Redis, Nginx, NodeJS, FFmpeg
- YAML configuration via Jinja2 templates
- Automated backup with dcron

### Galene (Video Conferencing)
- Go binary compiled from source
- Dynamic group management
- IPv6 network binding

### Abilian SBE (Flask Application)
- Complex Python environment
- Gunicorn + Celery + Redis coordination
- Frontend integration for public access

## Workload Versatility

SlapOS manages diverse workloads:
- **Virtualization:** KVM virtual machines
- **Telecommunications:** 4G/5G infrastructure (SimpleRAN)
- **Enterprise:** ERP5, Wendelin (Big Data/ML)
- **IoT:** Hardware GPIO control

## Further Reading

- [02-quick-start.md](02-quick-start.md) - Build your first software release
- [03-docker-build-reference.md](03-docker-build-reference.md) - Docker build system details
- [06-technical-notes.md](06-technical-notes.md) - Deep technical documentation
