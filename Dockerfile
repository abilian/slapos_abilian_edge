# Dockerfile for building SlapOS components and software releases
# This environment uses Nexedi's forked buildout with pinned dependencies

FROM python:3.11-slim-bookworm

LABEL maintainer="Abilian" \
      description="SlapOS build environment with Nexedi's buildout fork"

# Install system build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf \
    automake \
    bison \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    flex \
    gawk \
    gettext \
    gfortran \
    git \
    groff \
    libasound2-dev \
    libbz2-dev \
    libcap-dev \
    libexpat1-dev \
    libffi-dev \
    libgdbm-dev \
    libgmp-dev \
    libjpeg-dev \
    liblzma-dev \
    libncurses5-dev \
    libpcre3-dev \
    libpng-dev \
    libreadline-dev \
    libsqlite3-dev \
    libssl-dev \
    libtool \
    libxml2-dev \
    libxslt1-dev \
    m4 \
    patch \
    pkg-config \
    rsync \
    texinfo \
    uuid-dev \
    wget \
    xz-utils \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Pin setuptools and pip to versions compatible with Nexedi's buildout fork
RUN pip install --no-cache-dir \
    setuptools==67.8.0 \
    pip==23.2.1 \
    wheel

# Install Nexedi's forked buildout and zc.recipe.egg
# Copy Docker helper scripts early (needed for patching)
COPY docker/ /tmp/docker/

RUN pip install --no-cache-dir \
    --trusted-host www.nexedi.org \
    --find-links=http://www.nexedi.org/static/packages/source/ \
    --find-links=http://www.nexedi.org/static/packages/source/slapos.buildout/ \
    "zc.buildout @ git+https://lab.nexedi.com/nexedi/slapos.buildout.git@master" \
    "zc.recipe.egg==2.0.8.dev0+slapos010"

# Patch buildout's easy_install.py to handle PEP 503 name normalization
# Modern pip normalizes package names (zope.interface -> zope-interface) but buildout
# compares with original dotted names, causing AssertionError and version conflicts
RUN python3 /tmp/docker/patch_buildout.py

# Patch 2: Create sitecustomize.py to monkeypatch pkg_resources for PEP 503 name normalization
# This fixes the "We already have: zope-interface but X requires 'zope.interface'" errors
RUN python3 /tmp/docker/create_sitecustomize.py

# Install build backend and slapos.core (needed by slapos.cookbook)
RUN pip install --no-cache-dir \
    --trusted-host www.nexedi.org \
    --find-links=http://www.nexedi.org/static/packages/source/ \
    hatchling \
    editables \
    slapos.core

# Install common SlapOS recipes and extensions
RUN pip install --no-cache-dir \
    --trusted-host www.nexedi.org \
    --find-links=http://www.nexedi.org/static/packages/source/ \
    slapos.recipe.cmmi \
    slapos.recipe.build \
    slapos.recipe.template \
    slapos.extension.shared \
    slapos.extension.strip \
    slapos.libnetworkcache \
    plone.recipe.command \
    collective.recipe.template

# Set up working directory
WORKDIR /slapos

# Copy the repository
COPY . /slapos

# Install slapos.cookbook in development mode
# Use --no-build-isolation to use already installed dependencies
RUN pip install --no-cache-dir --no-build-isolation -e .

# Workaround for package name normalization issue
# Modern pip normalizes package names (dots -> underscores) in dist-info directory names,
# but pkg_resources uses directory names to find packages. We rename directories to use dots.
RUN python3 /tmp/docker/fix_package_names.py && rm -rf /tmp/docker

# Verify the fixes worked
RUN python -c "import pkg_resources; pkgs=['zc.buildout','zc.recipe.egg','slapos.recipe.build','slapos.recipe.cmmi','slapos.core']; print('\\n'.join([f'{p}: {pkg_resources.get_distribution(p).version}' for p in pkgs]))"

# Create build output directory
RUN mkdir -p /slapos/build

# Default command: show help
CMD ["python", "scripts/build.py", "--help"]
