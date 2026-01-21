# Introduction to SlapOS

**SlapOS** is a decentralized "Cloud Operating System" and orchestration engine used to deploy, manage, and configure complex software services across distributed infrastructure. It relies heavily on **Python** and **zc.buildout**.

Here is a breakdown of what SlapOS is and how it functions:

### 1. Core Philosophy: Software vs. Instance

SlapOS strictly separates the installation of code from the execution of services:

*   **Software Releases:** These are definitions (usually in `software.cfg`) that describe how to compile and install a specific version of a software stack.
*   **Instances:** These are live, running services instantiated from a Software Release. A single Software Release can spawn multiple Instances (e.g., one KVM software release can spawn 10 different Virtual Machines).
*   **Partitions:** Instances run inside "Computer Partitions," which are isolated environments (directories with specific permissions and user allocations) on a node.

### 2. Configuration Driven (Recipes and Schemas)

SlapOS uses a "Cookbook" approach. Developers write **Recipes** (Python scripts) to handle specific tasks, such as creating directories, generating configuration files, or managing processes.

*   **Input Parameters:** Instances are configured via JSON schemas (`README.software.rst`). This allows the system to automatically generate user interfaces for configuration and validate user inputs (e.g., defining RAM size for a VM or radio frequencies for a 5G cell).
*   **Publishing Results:** Instances "publish" connection parameters (like URLs, passwords, or IPv6 addresses) back to the user or to other instances.

### 3. Native Resiliency and Backup

A major feature detailed in the `stack/resilient` documentation is the built-in capability for high availability:

*   **Pull-Backup Architecture:** It defines a standard stack where an active instance (**export**) pushes data to a backup instance (**pull-backup**), which is then ready to be restored to a fallback instance (**import**).
*   **Automated Recovery:** If a main instance fails, the system can elect a backup candidate to take over.

### 4. Networking Architecture

SlapOS appears to operate on a specific networking model:

*   **IPv6 Centric:** Internal communication between nodes often relies on IPv6.
*   **Frontend/Backend Separation:** To make services accessible via public IPv4, SlapOS uses **Frontends** (like the `rapid-cdn` software release). A user requests a Frontend instance to proxy traffic to their specific backend service (like an ERP5 site or a KVM).
*   **Zero Knowledge:** There are recipes (`README.zero_knowledge.rst`) designed to handle secrets (like SSL keys) locally within the partition, ensuring the central management node doesn't store sensitive data.

### 5. Versatility of Workloads

SlapOS is not just for web apps; it manages hardware and infrastructure:

*   **Virtualization:** It can deploy **KVM** (Kernel-based Virtual Machines), essentially allowing SlapOS to act as a hypervisor manager.
*   **Telecommunications:** The **SimpleRAN** software release shows SlapOS managing 4G and 5G network infrastructure (eNB, gNB, Core Networks, and SIM card databases).
*   **Enterprise & Big Data:** It powers **ERP5** (ERP system) and **Wendelin** (Big Data/Machine Learning platform).
*   **IoT & Hardware:** It can manage specific hardware interactions, such as GPIO pins for motor control (`tsn-demo`).

### 6. Development Ecosystem

*   **Testing:** It includes a framework for unit testing recipes (`slapos.test.recipe`).
*   **Updates:** Tools like `update-hash` assist developers in managing file integrity (MD5 checksums) for downloads within the buildout profiles.
*   **Supervisord:** It integrates with `supervisord` to manage process life-cycles within a partition.

### 7. Network Cache (Shacache)

SlapOS uses a **network cache** to accelerate builds by storing pre-compiled binaries:

*   **Shacache:** Binary cache at `http://shacache.nxdcdn.com`
*   **Shadir:** Directory service at `http://shadir.nxdcdn.com`
*   **Signature Verification:** Downloads are verified using certificates from trusted uploaders

The cache is keyed by:
- SHA512 of the source URL
- Platform/architecture (e.g., x86_64, aarch64)
- Build options and dependencies

This means components only need to be compiled once per architecture, and subsequent deployments download pre-built binaries.

### 8. Nexedi's Buildout Fork

SlapOS uses a **customized fork of zc.buildout** (`slapos.buildout`) that includes:
*   Network cache integration
*   Shared parts support (`slapos.extension.shared`)
*   Custom egg handling for namespace packages
*   Binary stripping (`slapos.extension.strip`)

This fork is required because standard buildout doesn't support the network cache or shared parts features.

### Summary

**SlapOS is a programmable provisioning system.** It turns a collection of servers into a unified cloud where you can request complex, resilient services (from database clusters to 5G networks) using standardized configuration profiles.
