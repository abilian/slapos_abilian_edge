# Abilian SBE Software Release

This is a SlapOS software release for deploying **Abilian SBE** (Social Business Engine), a Flask-based enterprise collaboration platform.

## File Structure

| File | Purpose |
|------|---------|
| `software.cfg` | **Phase 1**: Build/compile all dependencies |
| `instance.cfg.in` | **Phase 2 Entry**: Routes to the actual instance template |
| `instance-sbe.cfg.in` | **Phase 2 Main**: The actual service configuration |
| `versions.cfg` | Pinned Python package versions |
| `buildout.hash.cfg` | MD5 checksums for change detection |
| `clamd.conf.j2`, `freshclam.conf.j2` | ClamAV config templates (antivirus) |

## Phase 1: Build (`software.cfg`)

The build phase extends 30+ component profiles to include all dependencies:

- **Database**: PostgreSQL, Redis
- **Document processing**: ImageMagick, Poppler, LibreOffice
- **X11/fonts**: Multiple X libraries, fontconfig, fonts
- **Build tools**: Node.js, Yarn, CMake, pkg-config
- **Python**: psycopg2, bcrypt, lxml

### Application Source

Clones and builds Abilian SBE from GitHub:

```ini
[sbe-git]
repository = https://github.com/abilian/abilian-sbe-monorepo.git
branch = main

[sbe-dev]
recipe = zc.recipe.egg:develop    # Install SBE as editable package

[sbe-yarn]
recipe = slapos.recipe.cmmi       # Run yarn install for frontend assets
```

### Dependencies

Declares 80+ Python dependencies including Flask, SQLAlchemy, Dramatiq, Gunicorn, and more. All versions are pinned in `versions.cfg`.

## Phase 2: Instantiation

### Entry Point (`instance.cfg.in`)

The first Jinja2 template rendered at instantiation time:

1. **Software Type Switch**: Routes to the correct instance template based on requested software type
2. **SlapOS Configuration**: Fetches partition info (IPs, parameters) from SlapOS master
3. **Parameter Passthrough**: All build paths from Phase 1 are passed to the final template

### Main Configuration (`instance-sbe.cfg.in`)

Creates all runtime services:

#### Directory Structure

```ini
[directory]
recipe = slapos.cookbook:mkdirectory
etc = ${buildout:directory}/etc
srv = ${buildout:directory}/srv
var = ${buildout:directory}/var
log = ${:var}/log
services = ${:etc}/service    # Supervisor-managed processes
```

#### PostgreSQL Database

```ini
[postgresql-password]
recipe = slapos.cookbook:generate.password    # Auto-generates password

[postgresql]
recipe = slapos.cookbook:postgres
dbname = sbe
superuser = sbe
port = ${postgresql-address:port}    # Dynamic port allocation
```

Creates a PostgreSQL instance with auto-generated credentials.

#### Redis Cache

```ini
[service-redis]
recipe = slapos.cookbook:redis.server
unixsocket = ${:server-dir}/redis.socket
port = 0    # Unix socket only, no TCP
```

Redis listens only on Unix socket for security.

#### Frontend Request

```ini
[request-sbe-frontend]
recipe = slapos.cookbook:requestoptional
software-url = http://git.erp5.org/.../apache-frontend/software.cfg
config-url = http://[${sbe-parameters:ipv6}]:${sbe-parameters:port}
return = secure_access domain
```

Requests an Apache frontend from another SlapOS software release to provide HTTPS termination.

#### Dummy Mail Server

```ini
[dummy-mail]
command-line = python3 -u -m smtpd -n -c DebuggingServer ${:host}:${:port}
```

A debug SMTP server that logs all outgoing emails instead of sending them.

#### Flask/Gunicorn Application

```ini
[sbe-wrapper]
recipe = slapos.cookbook:wrapper
environment =
  FLASK_SQLALCHEMY_DATABASE_URI=${postgres-uri:uri}
  FLASK_REDIS_URI=${redis-uri:unix}
  FLASK_DRAMATIQ_BROKER_URL=${redis-uri:unix}
  LD_LIBRARY_PATH = ... (shared library paths for LibreOffice)
```

Sets up environment variables for the Flask app:
- Database connection (PostgreSQL)
- Cache/queue (Redis)
- LibreOffice for document conversion
- Font configuration

**Service wrappers created:**
- `sbe_assets` - Build frontend assets (`flask assets build`)
- `sbe_initdb` - Initialize database (`flask initdb`)
- `sbe_create_admin` - Create admin user
- `sbe_start_gunicorn` - Main application server

#### Health Checks (Promises)

```ini
[sbe-listen-promise]
promise = check_socket_listening
config-host = ${sbe-parameters:ipv6}
config-port = ${sbe-parameters:port}
```

Monitors that Gunicorn is listening on port 8005.

#### Published Connection Info

```ini
[publish-connection-information]
recipe = slapos.cookbook:publish
url = ${request-sbe-frontend:connection-secure_access}
```

Exposes the frontend URL back to SlapOS master for user access.

## Runtime Architecture

```
                    ┌─────────────────────────────────────────┐
                    │          SlapOS Partition               │
                    │                                         │
Internet ──HTTPS──▶ │  Apache Frontend (separate partition)   │
                    │           │                             │
                    │           ▼ HTTP                        │
                    │  ┌─────────────────┐                    │
                    │  │    Gunicorn     │◀──▶ PostgreSQL     │
                    │  │  (Flask/SBE)    │◀──▶ Redis (socket) │
                    │  │    port 8005    │                    │
                    │  └─────────────────┘                    │
                    │           │                             │
                    │           ▼                             │
                    │     LibreOffice (doc conversion)        │
                    │     Dummy SMTP (mail logging)           │
                    └─────────────────────────────────────────┘
```

## Key Patterns

1. **Two-phase model**: Build once, instantiate many
2. **Password generation**: `slapos.cookbook:generate.password` creates persistent secrets
3. **Dynamic port allocation**: `slapos.cookbook:free_port` avoids conflicts
4. **Service composition**: Requests external frontend via `slapos.cookbook:requestoptional`
5. **Promise monitoring**: Health checks ensure services are running
6. **Environment isolation**: `LD_LIBRARY_PATH` ensures LibreOffice finds all dependencies
