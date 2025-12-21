# Observations

This document discusses the implementation details of five distinct software releases managed by SlapOS. These examples demonstrate the diversity of workloads SlapOS handles, ranging from simple FTP servers to complex web applications and legacy document converters.

Here is an analysis of the code and configuration logic for **Abilian SBE**, **Cloudooo**, **Galene**, **Peertube**, and **ProFTPd**.

---

### 1. Cloudooo (Document Conversion Cluster)
**Role:** A wrapper around LibreOffice/OpenOffice to provide a document conversion API (e.g., Doc -> PDF) over XML-RPC.

**Architectural Highlights:**
*   **Load Balancing:** Unlike a standard application, Cloudooo in SlapOS is deployed as a **cluster within a partition**. The `instance-cloudooo.cfg.in` file reveals that it requests a specific number of backends (`backend-count`) and places them behind **HAProxy**.
*   **X11 Virtualization:** Since LibreOffice requires a display server even in headless mode, the instance spawns **Xvfb** (X Virtual Framebuffer).
    ```ini
    [xvfb-instance]
    recipe = slapos.cookbook:wrapper
    command-line =
      {{ parameter_dict["xserver"] }}/bin/Xvfb
        ${:display}
        -screen 0 1024x768x24
    ```
*   **Font Management:** The software explicitly installs and manages fonts (Android, IPA, Liberation, DejaVu) and generates a custom `fonts.conf` using Jinja2 templates to ensure consistent rendering across different nodes.

### 2. Peertube (Video Streaming Platform)
**Role:** An ActivityPub-federated video streaming platform.

**Architectural Highlights:**
*   **Full Stack in a Box:** The `software.cfg` and `instance.cfg` describe a "Macro-service" architecture. A single PeerTube partition contains:
    *   **PostgreSQL** (Database)
    *   **Redis** (Caching/Queue)
    *   **Nginx** (Web Server/Reverse Proxy)
    *   **NodeJS** (The Application)
    *   **FFmpeg** (Video Transcoding)
    *   **Cron** (Backup automation)
*   **Configuration Injection:** PeerTube relies on a massive YAML configuration file. SlapOS handles this by taking the `instance-peertube-input-schema.json` (user inputs like email, hostname, descriptions) and injecting them into a Jinja2 template (`template-peertube.yaml.in`) to generate the config at runtime.
*   **Backup Strategy:** It includes a dedicated `dcron` service and a script (`template-peertube-backup.sh.in`) that dumps the Postgres database to a file.
    ```bash
    # template-peertube-backup.sh.in
    $${postgresql:bin}/pg_dump ... -Fc peertube_prod > $${peertube-backup-script:backup-file}
    ```

### 3. Galene (Video Conferencing)
**Role:** A Go-based media server for video conferencing.

**Architectural Highlights:**
*   **Go Build Process:** The `software.cfg` uses `slapos.recipe.cmmi` (or similar build recipes) to compile the Go binary from source (`lab.nexedi.com/nexedi/galene.git`).
*   **Group Management:** The instance configuration dynamically generates the `groups.json` file. It allows for a specific "PTT" (Push-To-Talk) mode defined in `software-ptt.cfg`, which overrides default parameters to force specific behaviors (like `allow_subgroups`).
*   **Network Binding:** It explicitly binds to a random IPv6 address assigned to the partition:
    ```ini
    [galene-wrapper]
    command-line = ... -http [${:ip}]:${:port} ...
    ip = ${slap-configuration:ipv6-random}
    ```

### 4. ProFTPd (SFTP Server)
**Role:** An FTP server configured specifically for SFTP (SSH File Transfer Protocol) with virtual users.

**Architectural Highlights:**
*   **Mod_Auth_Web:** The configuration uses a clever mechanism to authenticate FTP users against an external API rather than system users.
    ```apache
    # proftpd-config-file.cfg.in
    LoadModule mod_auth_web.c
    AuthWebURL {{ proftpd['authentication-url'] }}
    AuthWebRequireHeader "X-Proftpd-Authentication-Result: Success"
    ```
    This allows SlapOS to integrate ProFTPd with other web services effortlessly.
*   **Virtual User Isolation:** It uses `AuthUserFile` to store users in a local file (`ftpd.passwd`), isolating them from the underlying OS users.
*   **Security:** It implements a `BanEngine` to block hosts after 5 failed login attempts and restricts users to their home directory via `DefaultRoot`.

### 5. Abilian SBE (Python/Flask Application)
**Role:** A business application built on Flask.

**Architectural Highlights:**
*   **Monorepo Handling:** The buildout handles a complex python environment (`sbe-deps`, `sbe-dev`) and installs frontend dependencies via `yarn` and `nodejs` within the build process.
*   **Service Coordination:** It orchestrates `gunicorn` (WSGI server), `celery` (via `dramatiq` for tasks), and `redis` (message broker) within the instance.
*   **Frontend Integration:** It requests a frontend from SlapOS Master (`slapos.cookbook:requestoptional`) to expose the internal IPv6 Gunicorn server to the public IPv4 internet via a standard SlapOS Frontend (Apache/Caddy).

---

### Common Patterns ("The SlapOS Way")
Across all these software releases, several code patterns stand out:

1.  **Promises:** Every service defines "promises" (health checks). For example, `peertube-listen-promise` checks if the URL returns a 200 OK. If a promise fails, the partition is marked as error state.
2.  **Wrappers:** They rarely run binaries directly. Instead, they use `slapos.cookbook:wrapper` to generate shell scripts that set up environment variables (`LD_LIBRARY_PATH`, `PATH`) before executing the binary.
3.  **Template Rendering:** Almost all configuration files (Postgres configs, Nginx configs, YAML files) are generated dynamically using `slapos.recipe.template:jinja2`, allowing the software to adapt to the specific IP addresses and ports assigned to the partition.
4.  **Directory Structure:** They all follow a strict directory hierarchy defined in the instance profile (e.g., `${buildout:directory}/etc`, `${buildout:directory}/srv`, `${buildout:directory}/var`).

---

### Docker Build Observations (January 2026)

When building SlapOS components in a standalone Docker environment, several issues were discovered:

#### Architecture Assumptions
Many components assume **x86_64** architecture:
- `chromedriver`, `chromium`, `consul` - Only x86_64 URLs defined
- Binary downloads lack aarch64 (ARM64) variants
- SlapOS infrastructure runs on x86_64, so cache only has x86_64 binaries

#### Python 2 vs Python 3 Compatibility
Some buildout configs contain Python 2 syntax:
- `bazel` uses `0644` instead of `0o644` for octal literals
- This causes `SyntaxError` in Python 3

#### Running as Root
Docker runs as root by default, but some components reject this:
- `coreutils` configure script requires `FORCE_UNSAFE_CONFIGURE=1`
- SlapOS typically runs as non-root user in production

#### Package Name Normalization (PEP 503)
Modern pip normalizes package names (dots → hyphens), but buildout/pkg_resources expect dotted names:
- `zope.interface` becomes `zope-interface` in wheel metadata
- Causes version conflict errors: "We already have: zope-interface but X requires 'zope.interface'"
- Required extensive patching of buildout and pkg_resources
