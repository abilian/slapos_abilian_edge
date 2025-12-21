# SlapOS' Partitions

In SlapOS, a **Partition** (often referred to as a "Computer Partition" or `slappart`) is a strictly isolated environment on a hosting node dedicated to running a single **Instance** of a software.

You can think of it as a lightweight, "unix-native" container. It is the fundamental unit of deployment in SlapOS.

Here are the specific characteristics of a partition:

### 1. Physical Isolation (Filesystem & User)
*   **Directory:** A partition is essentially a directory on the host machine (e.g., `/srv/slapgrid/slappartNN`).
*   **User:** Each partition is assigned a unique Unix user and group. This ensures that an instance in one partition cannot access or modify the files of an instance in another partition.
*   **Self-Containment:** As seen in the `instance-peertube.cfg.in` and `instance-sbe.cfg.in` files, a partition contains everything needed for the running service, creating its own internal hierarchy:
    *   `etc/`: Configuration files (created by templates).
    *   `var/`: Log files, PID files, and run sockets.
    *   `srv/`: Persistent data (databases, repositories).
    *   `bin/`: Startup scripts and wrappers.

### 2. Network Identity
*   **IPv6:** A partition is typically assigned a dedicated **IPv6 address** (referenced as `ipv6-random` or `ipv6` in configuration files like `instance-galene.cfg.in`). This allows every service to listen on standard ports (like 80 or 443) without conflict, provided they use IPv6.
*   **IPv4:** Partitions often share the host's IPv4 address. Consequently, to be accessible via IPv4, they must either use unique high-number ports (e.g., the `postgresql-address` recipe in PeerTube looks for a free port between 5432 and 5452) or rely on a Frontend partition to proxy traffic.

### 3. Separation of Code and Data
The documents highlight a strict separation between Software and Partition:
*   **Software Release:** The source code and binaries are installed once on the node in a shared directory (read-only for partitions).
*   **Partition (Instance):** Contains only the **configuration** and **data**.
    *   *Example:* In `software/cloudooo`, the software binary `soffice.bin` lives in a shared component folder, but the `cloudooo.cfg` configuration file and the temporary conversion data live inside the Partition's `etc` and `srv` directories.

### 4. Cluster Building Blocks
Complex applications are built by connecting multiple partitions, potentially across different computers.
*   **Rapid.CDN Example:** The `software/rapid-cdn/README.rst` explains that a CDN deployment results in a cluster of partitions: one "master" partition (controller), one "kedifa" partition (keys), and multiple "frontend-node-N" partitions (HAProxy/Apache).
*   **ERP5 Example:** An ERP5 instance is actually a graph of partitions including Zope partitions, Memcached partitions, and MariaDB partitions, all communicating with each other.

### 5. Resiliency
As described in `stack/resilient/README.rst`, partitions are the units used for backups. An **Export Partition** dumps data from its `srv/` directory, which is transmitted to an **Import Partition** on a different machine to ensure redundancy.
