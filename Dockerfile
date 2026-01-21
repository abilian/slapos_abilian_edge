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
RUN pip install --no-cache-dir \
    --trusted-host www.nexedi.org \
    --find-links=http://www.nexedi.org/static/packages/source/ \
    --find-links=http://www.nexedi.org/static/packages/source/slapos.buildout/ \
    "zc.buildout @ git+https://lab.nexedi.com/nexedi/slapos.buildout.git@master" \
    "zc.recipe.egg==2.0.8.dev0+slapos010"

# Patch buildout's easy_install.py to handle PEP 503 name normalization
# Modern pip normalizes package names (zope.interface -> zope-interface) but buildout
# compares with original dotted names, causing AssertionError and version conflicts
RUN python3 << 'PATCH_EOF'
import site
import os

def normalize_name(name):
    """PEP 503 normalization: lowercase, dots/underscores become hyphens"""
    return name.lower().replace('.', '-').replace('_', '-')

for sp in site.getsitepackages():
    easy_install_path = os.path.join(sp, 'zc', 'buildout', 'easy_install.py')
    if os.path.exists(easy_install_path):
        print(f"Patching: {easy_install_path}")

        with open(easy_install_path, 'r') as f:
            lines = f.readlines()

        patched = False
        new_lines = []
        i = 0
        while i < len(lines):
            line = lines[i]

            # Patch 1: Fix _get_matching_dist_in_location function
            # Replace the dist_infos line with normalized comparison
            if 'dist_infos = [ (d.project_name.lower()' in line and 'd.parsed_version) for d in dists ]' in line:
                indent = line[:len(line) - len(line.lstrip())]
                new_lines.append(f'{indent}# PEP 503 name normalization patch\n')
                new_lines.append(f'{indent}def _norm(n): return n.lower().replace(".", "-").replace("_", "-")\n')
                new_lines.append(f'{indent}dist_infos = [ (_norm(d.project_name), d.parsed_version) for d in dists ]\n')
                patched = True
                print("  Patched: dist_infos line")
                i += 1
                continue

            # Patch 2: Fix the comparison line
            if 'if dist_infos == [(dist.project_name.lower()' in line:
                indent = line[:len(line) - len(line.lstrip())]
                new_lines.append(f'{indent}if dist_infos == [(_norm(dist.project_name), dist.parsed_version)]:\n')
                patched = True
                print("  Patched: comparison line")
                i += 1
                continue

            new_lines.append(line)
            i += 1

        if patched:
            with open(easy_install_path, 'w') as f:
                f.writelines(new_lines)
            print("Patch 1 (easy_install.py) applied successfully!")
        else:
            print("Warning: Patterns not found in easy_install.py")
        break

print("Buildout patching complete")
PATCH_EOF

# Patch 2: Create sitecustomize.py to monkeypatch pkg_resources for PEP 503 name normalization
# This fixes the "We already have: zope-interface but X requires 'zope.interface'" errors
RUN python3 << 'SITECUSTOMIZE_EOF'
import site
import os

# Get the site-packages directory
sp = site.getsitepackages()[0]
sitecustomize_path = os.path.join(sp, 'sitecustomize.py')

# Check if sitecustomize.py already exists
existing_content = ""
if os.path.exists(sitecustomize_path):
    with open(sitecustomize_path, 'r') as f:
        existing_content = f.read()

patch_code = '''
# PEP 503 name normalization patch for pkg_resources
# Fixes version conflicts between dotted names (zope.interface) and
# normalized names (zope-interface) in wheel metadata

def _apply_pkg_resources_patch():
    try:
        import pkg_resources
    except ImportError:
        return

    def normalize_name(name):
        """Normalize package name per PEP 503"""
        return name.lower().replace('.', '-').replace('_', '-')

    # Store original methods
    _original_init = pkg_resources.Requirement.__init__

    def _patched_requirement_init(self, requirement_string):
        """Patched __init__ that normalizes the project name after parsing"""
        _original_init(self, requirement_string)
        # Store original name for display but use normalized for comparison
        if not hasattr(self, '_original_project_name'):
            self._original_project_name = self.project_name
        # We don't modify project_name here as it would break other things

    # Patch the __eq__ and __hash__ methods to use normalized names
    _original_req_hash = pkg_resources.Requirement.__hash__
    _original_req_eq = getattr(pkg_resources.Requirement, '__eq__', None)

    def _patched_req_hash(self):
        # Use normalized name for hashing
        return hash((normalize_name(self.project_name), self.specs, self.extras))

    # Patch Distribution to normalize names in key comparisons
    _original_dist_key = pkg_resources.Distribution.key.fget if hasattr(pkg_resources.Distribution.key, 'fget') else None

    # More importantly, patch the working set resolution
    _original_resolve = pkg_resources.WorkingSet.resolve

    def _patched_resolve(self, requirements, env=None, installer=None,
                         replace_conflicting=False, extras=None):
        """Patched resolve that handles normalized package names"""
        try:
            return _original_resolve(self, requirements, env, installer,
                                    replace_conflicting, extras)
        except pkg_resources.VersionConflict as e:
            # Check if this is a name normalization issue
            if len(e.args) == 2:
                existing_dist, req = e.args
                existing_norm = normalize_name(existing_dist.project_name)
                req_norm = normalize_name(req.project_name)
                if existing_norm == req_norm:
                    # Same package, different naming - check version
                    if existing_dist.parsed_version in req:
                        # Version satisfies requirement, not a real conflict
                        return list(self)
            raise

    # Apply patches
    pkg_resources.Requirement.__init__ = _patched_requirement_init
    pkg_resources.WorkingSet.resolve = _patched_resolve

    # Also patch Environment to find packages with normalized names
    _original_env_getitem = pkg_resources.Environment.__getitem__

    def _patched_env_getitem(self, project_name):
        """Try both original and normalized names"""
        result = _original_env_getitem(self, project_name)
        if result:  # Found with original name
            return result
        # Try normalized name lookup
        norm_name = normalize_name(project_name)
        for key in list(self._distmap.keys()):
            if normalize_name(key) == norm_name:
                return _original_env_getitem(self, key)
        return result  # Return empty list

    pkg_resources.Environment.__getitem__ = _patched_env_getitem

    # Patch Environment.best_match to handle name normalization
    _original_best_match = pkg_resources.Environment.best_match

    def _patched_best_match(self, req, working_set, installer=None, replace_conflicting=False):
        """Patched best_match that normalizes package names"""
        # First try normal lookup
        result = _original_best_match(self, req, working_set, installer, replace_conflicting)
        if result is not None:
            return result

        # If not found, try with normalized key
        norm_key = normalize_name(req.key)
        for key in list(self._distmap.keys()):
            if normalize_name(key) == norm_key:
                for dist in self[key]:
                    # Check if version matches
                    if dist.parsed_version in req:
                        return dist
        return None

    pkg_resources.Environment.best_match = _patched_best_match

    # Patch WorkingSet.find to handle name normalization
    _original_ws_find = pkg_resources.WorkingSet.find

    def _patched_ws_find(self, req):
        """Patched find that normalizes package names"""
        try:
            return _original_ws_find(self, req)
        except pkg_resources.VersionConflict as e:
            # Check if this is a false conflict due to name normalization
            if len(e.args) == 2:
                dist, req_obj = e.args
                if normalize_name(dist.project_name) == normalize_name(req_obj.project_name):
                    if dist.parsed_version in req_obj:
                        return dist
            raise

    pkg_resources.WorkingSet.find = _patched_ws_find

    # Patch Requirement.__contains__ to normalize names before comparison
    _original_req_contains = pkg_resources.Requirement.__contains__

    def _patched_req_contains(self, item):
        """Patched __contains__ that normalizes package names"""
        if isinstance(item, pkg_resources.Distribution):
            # Use normalized keys for comparison
            if normalize_name(item.key) != normalize_name(self.key):
                return False
            item = item.version
        return self.specifier.contains(item, prereleases=True)

    pkg_resources.Requirement.__contains__ = _patched_req_contains

_apply_pkg_resources_patch()
'''

# Only add if not already present
if '_apply_pkg_resources_patch' not in existing_content:
    with open(sitecustomize_path, 'a') as f:
        f.write(patch_code)
    print(f"Created/updated sitecustomize.py at {sitecustomize_path}")
else:
    print("sitecustomize.py already contains the patch")
SITECUSTOMIZE_EOF

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
RUN python3 << 'EOF'
import os
import shutil
import site

# Packages with underscore directory names that need dotted names: (underscore_prefix, dotted_name)
packages_to_fix = [
    ('zc_buildout', 'zc.buildout'),
    ('slapos_core', 'slapos.core'),
    ('slapos_recipe_build', 'slapos.recipe.build'),
    ('slapos_recipe_template', 'slapos.recipe.template'),
    ('slapos_cookbook', 'slapos.cookbook'),
]

for sp in site.getsitepackages():
    if not os.path.exists(sp):
        continue

    for item in os.listdir(sp):
        if not item.endswith('.dist-info'):
            continue

        for underscore_prefix, dotted in packages_to_fix:
            if item.startswith(underscore_prefix + '-'):
                # Extract version part (e.g., "3.0.1+slapos010.dist-info")
                version_part = item[len(underscore_prefix)+1:]
                new_name = f'{dotted}-{version_part}'

                if item != new_name:
                    old_path = os.path.join(sp, item)
                    new_path = os.path.join(sp, new_name)
                    if not os.path.exists(new_path):
                        shutil.move(old_path, new_path)
                        print(f'Renamed: {item} -> {new_name}')
                break

print('Package name normalization complete')
EOF

# Verify the fixes worked
RUN python -c "import pkg_resources; pkgs=['zc.buildout','zc.recipe.egg','slapos.recipe.build','slapos.recipe.cmmi','slapos.core']; print('\\n'.join([f'{p}: {pkg_resources.get_distribution(p).version}' for p in pkgs]))"

# Create build output directory
RUN mkdir -p /slapos/build

# Default command: show help
CMD ["python", "scripts/build.py", "--help"]
