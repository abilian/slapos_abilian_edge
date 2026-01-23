#!/usr/bin/env python3
"""Fix package directory names for packages with underscores vs dots."""
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
