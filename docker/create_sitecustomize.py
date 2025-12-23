#!/usr/bin/env python3
"""Create sitecustomize.py to monkeypatch pkg_resources for PEP 503 name normalization."""
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
