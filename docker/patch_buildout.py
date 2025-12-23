#!/usr/bin/env python3
"""Patch buildout's easy_install.py to handle PEP 503 name normalization."""
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
