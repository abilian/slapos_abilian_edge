# About `slapos.cookbook`

`slapos.cookbook`** is a collection of Python-based **recipes** used by **zc.buildout** to configure, deploy, and manage software instances within the SlapOS cloud environment.

Here is an explanation of the architecture and specific components contained in the code.

### 1. Core Architecture (`slapos.recipe.librecipe`)

This package contains the base classes and utilities that simplify writing specific recipes. It abstracts the complexity of interacting with the file system and the SlapOS Master API.

*   **`GenericBaseRecipe`**: The parent class for most recipes. It provides helper methods to:
    *   Create configuration files (`createFile`) with template substitution.
    *   Create executable wrapper scripts (`createWrapper`).
    *   Create directories (`createDirectory`).
    *   Handle options passed from `buildout.cfg`.
*   **`GenericSlapRecipe`**: Inherits from `GenericBaseRecipe`. It adds specific logic to interact with the **SlapOS Master** (Vifib).
    *   It retrieves parameters for the current computer partition (`getInstanceParameterDict`).
    *   It publishes connection information back to the master (`setConnectionDict`).
*   **`execute.py`**: A utility to handle process execution. It includes logic for signal propagation (ensuring `SIGTERM` kills child processes) and `inotify` support to wait for files to appear before starting a service.

### 2. Functional Categories of Recipes

The code provided covers a wide range of infrastructure and application needs.

#### A. SlapOS Internals & Orchestration

These recipes handle the logic of the distributed cloud system.
*   **`slapos.recipe.request`**: This is a critical recipe. It allows a software instance to **request** another instance from the SlapOS Master. For example, a Web App instance uses this to request a Database instance. It handles passing parameters and retrieving connection details (IP, port, passwords).
*   **`slapos.recipe.slapconfiguration`**: Fetches parameters defined by the user (via the SlapOS Master) or the partition resource file and makes them available as buildout options for other recipes to use. It supports JSON schema validation.
*   **`slapos.recipe.publish`**: Publishes connection parameters (URLs, passwords) back to the user via the SlapOS Master.
*   **`slapos.recipe.switch_softwaretype`**: Allows a single `software.cfg` to support multiple variations (e.g., "default", "client", "server") by switching the underlying buildout profile based on a parameter.

#### B. Database Recipes

Scripts to configure and start specific database servers inside a partition.

*   **`slapos.recipe.postgres`**: Sets up a PostgreSQL cluster. It runs `initdb`, creates `postgresql.conf` and `pg_hba.conf` (configuring IP binding and authentication), creates a default database and superuser, and generates a startup wrapper.
*   **`slapos.recipe.redis`**: Configures and starts a Redis server, supporting password authentication, unix sockets, and IPv6.
*   **`slapos.recipe.generic_mysql`**: Seems to handle MySQL upgrades and running initialization scripts.
*   **`slapos.recipe.generic_kumofs` & `generic_memcached`**: For distributed caching systems.

#### C. Networking & Connectivity

*   **`slapos.recipe.6tunnel`**: Sets up a tunnel to allow IPv4-only applications to communicate over IPv6 (or vice versa).
*   **`slapos.recipe.re6stnet`**: Manages a resilient mesh network (Re6st). It handles certificate generation, token management, and registry interactions.
*   **`slapos.recipe.check_port_listening` / `check_url_available`**: These are **Promise** recipes. They generate scripts that run periodically to verify that a service is actually up and running (monitoring).

#### D. Web & Application Servers

*   **`slapos.recipe.apachephp`**: Configures Apache HTTPD with `mod_php`. It generates `httpd.conf` and `php.ini`.
*   **`slapos.recipe.simplehttpserver`**: A lightweight Python-based HTTP server, often used for serving static files or simple testing.
*   **`slapos.recipe.generic_cloudooo`**: specific to the ERP5 ecosystem, this configures "Cloudooo", a document conversion server (wrapping LibreOffice).
*   **`slapos.recipe.squid`**: Configures a Squid proxy cache.

#### E. System Utilities

*   **`slapos.recipe.wrapper`**: A generic recipe to create a startup script for *any* command line. It handles PID files, environment variables, and `wait-for-files` (delaying startup until specific files exist).
*   **`slapos.recipe.dcron`**: Installs and configures a cron daemon specific to the user/partition (allowing per-instance scheduled tasks).
*   **`slapos.recipe.logrotate`**: Configures log rotation for the specific instance to prevent disk saturation.
*   **`slapos.recipe.random`**: Generates random passwords, integers, or MAC addresses and stores them so they remain persistent across updates.

### 3. Testing Infrastructure

The `slapos/test/` directory contains a robust test suite using `unittest` and `zc.buildout.testing`.

*   **`test_postgres.py`**: Installs the Postgres recipe in a temporary directory, starts the server, and verifies connection using `psycopg2`.
*   **`test_request.py`**: Mocks the SlapOS API to verify that the recipe correctly sends requests and processes responses.
*   **`test_json_schema.py`**: Validates that the JSON input schemas for Software Releases conform to the standard meta-schemas.

### Summary

This codebase is the **"glue"** layer of SlapOS. While SlapOS Node manages partitions and the OS, and SlapOS Master manages orchestration, **`slapos.cookbook`** provides the logic that runs *inside* the partition to turn generic binaries (like `postgres` or `apache`) into a configured, running, monitored service connected to the rest of the system.

---

## Standalone Building

### Overview

It is possible to build SlapOS components without the full SlapOS infrastructure using buildout directly. This is useful for:
- Testing component builds
- Development and debugging
- Running on architectures not officially supported

### Requirements

1. **Nexedi's forked buildout** (`zc.buildout 3.0.1+slapos010`)
2. **Pinned dependencies:**
   - `setuptools==67.8.0`
   - `pip==23.2.1`
3. **SlapOS extensions:**
   - `slapos.extension.shared`
   - `slapos.extension.strip`
4. **Common recipes:**
   - `slapos.recipe.cmmi`
   - `slapos.recipe.build`
   - `slapos.recipe.template`

### Challenges

Building standalone bypasses several SlapOS features:
- **Network cache:** No pre-built binaries; must compile from source
- **Infrastructure services:** No SlapOS Master for coordination
- **Partition isolation:** Runs in a single directory without Unix user separation

### Scripts

The `scripts/` directory contains tools for standalone building:
- `build.py` - Build individual components or software releases
- `build_all.py` - Build all components with reporting

See `notes/docker-build.md` for Docker-based building instructions.
