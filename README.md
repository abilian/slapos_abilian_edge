# SlapOS Developer Documentation

This repository contains the core logic for **SlapOS**, a decentralized Cloud Operating System based on `zc.buildout`.

This documentation is intended for **Software Release Developers** and **Core Contributors**. It covers the architecture of the `slapos.cookbook` (the Python recipes) and the structure of Software Releases (definitions of services like ERP5, Peertube, KVM, etc.).

---

## 1. Core Architecture

SlapOS enforces a strict separation between **building** software and **running** services.

### 1.1. The Vocabulary

*   **Software Release (SR):** defined in a `software.cfg`. It describes how to compile/download source code and build binaries. It runs *once* per computer. The result is read-only for instances.
*   **Software Instance:** The instantiation of an SR. Defined in `instance.cfg` (usually a Jinja2 template). It runs processes, stores data, and generates configuration files.
*   **Computer Partition:** A lightweight, isolated environment (directory + dedicated Unix user) where an Instance runs.
*   **Recipe:** Python code (part of `slapos.cookbook`) that performs specific configuration tasks (e.g., "create a Postgres database", "generate a wrapper script", "request another instance").
*   **Promise:** A health-check script generated inside a partition. If a promise fails, the partition is marked as "Error".

### 1.2. Directory Structure

*   `slapos/`: Source code for `slapos.cookbook` (Python recipes).
    *   `recipe/`: Individual recipes (e.g., `postgres`, `wrapper`, `request`).
    *   `librecipe/`: Shared libraries and base classes (`GenericBaseRecipe`).
*   `software/`: Definitions of specific Software Releases (e.g., `cloudooo`, `peertube`, `galene`).
*   `stack/`: Reusable Buildout profiles shared across multiple softwares (e.g., `stack/monitor`, `stack/resilient`).
*   `component/`: (External) Definitions of standard components (Nginx, Python, GCC) used by Software Releases.

---

## 2. Developing `slapos.cookbook` Recipes

Recipes are the glue that turns binaries into running services. They are located in `slapos/recipe/`.

### 2.1. The Base Class
Most recipes inherit from `slapos.recipe.librecipe.GenericBaseRecipe`. This provides helper methods like:
*   `createWrapper(name, command)`: Generates a shell script that handles environment variables and PID files.
*   `createConfigurationFile(name, content)`: Writes config files safely.
*   `generatePassword()`: Creates or retrieves a persistent password.

### 2.2. Common Recipes
When creating a Software Release, you will frequently use these standard recipes:

*   **`slapos.recipe.wrapper`**: Creates a startup script. Essential for supervisord/slapgrid execution. Supports `wait-for-files` (delay startup until config exists).
*   **`slapos.recipe.template:jinja2`**: Renders configuration files using Jinja2 context (IPs, ports, parameters).
*   **`slapos.recipe.request`**: Requests another instance (Slave or distinct Partition) from the SlapOS Master.
*   **`slapos.recipe.slapconfiguration`**: Fetches input parameters from the SlapOS Master (via JSON or XML).
*   **`slapos.recipe.check_*`**: Creates Promises (monitoring probes). Example: `check_port_listening`.

---

## 3. Creating a Software Release

A Software Release consists of two phases defined in Buildout profiles.

### Phase 1: Software Build (`software.cfg`)
This profile compiles binaries. It should **not** rely on IP addresses or specific user IDs.
```ini
[buildout]
extends = ../../component/nginx/buildout.cfg

[nginx]
# Compiles Nginx
recipe = slapos.recipe.cmmi
...

[template-nginx-conf]
# Downloads a configuration template for Phase 2
recipe = slapos.recipe.build:download
...
```

### Phase 2: Instantiation (`instance.cfg.in`)
This profile (usually a template rendered by `software.cfg`) configures the service inside a partition.
```ini
[buildout]
parts =
  nginx-service
  nginx-promise

[nginx-service]
recipe = slapos.cookbook:wrapper
command-line = ${nginx:location}/sbin/nginx -c ${nginx-conf:output}
wrapper-path = ${directory:services}/nginx

[nginx-promise]
recipe = slapos.cookbook:check_port_listening
port = 8080
```

### 3.1. Handling User Parameters (JSON Schemas)
Modern SlapOS Releases use JSON Schemas to define valid input parameters and return values.
1.  Define `instance-input-schema.json`.
2.  Define `instance-output-schema.json`.
3.  Link them in `software.cfg.json`.
4.  In the recipe, use `slapos.recipe.slapconfiguration` to validate inputs against the schema.

### 3.2. Resilience & Backup
To make a software resilient (backup/restore capabilities), extend `stack/resilient/buildout.cfg`.
This sets up an **Export** partition (dumps data), a **Pull-Backup** partition (stores history), and an **Import** partition (restores data).

---

## 4. Testing

### 4.1. Recipe Unit Tests
Unit tests for Python recipes are located in `slapos/test/recipe`.
Run them using:
```bash
python setup.py test --test-suite slapos.test.test_recipe.additional_tests
```

### 4.2. Software Release Tests
Each software directory (e.g., `software/peertube/test/`) usually contains integration tests. These tests:
1.  Instantiate the software locally (using `slapos.core`).
2.  Verify connection parameters.
3.  Perform HTTP requests or functional checks against the running instance.

---

## 5. Utilities

### `update-hash`
Used to manage `buildout.hash.cfg`. When you change a file referenced in a buildout profile (like a template or a script), run this tool to update the MD5 checksums automatically, ensuring the software rebuilds correctly on update.

```bash
# Inside a software directory
update-hash
```

---

## 6. Networking & Frontend

*   **IPv6:** SlapOS partitions communicate primarily over IPv6.
*   **IPv4:** Use **Frontend** instances (like `software/rapid-cdn`) to expose services to the IPv4 internet.
*   **Ports:** Recipes should generate random ports or look for free ports (`slapos.recipe.free_port`) to avoid collisions, as multiple partitions share the same network interface.
