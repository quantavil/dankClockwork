#!/usr/bin/env python3
"""
Manifest validation script for Clockwork DankMaterialShell plugin.
Validates plugin.json syntax and schema conformance against DMS plugin-schema.json.
"""

import glob
import json
import os
import sys
from pathlib import Path

try:
    import jsonschema
except ImportError:
    print("Error: 'jsonschema' library is required. Run via 'uv run --with jsonschema python3 tests/validate_manifest.py'")
    sys.exit(1)

def find_schema_path(repo_root):
    env_schema = os.environ.get("DMS_PLUGIN_SCHEMA")
    if env_schema and os.path.isfile(env_schema):
        return env_schema

    candidate_paths = [
        *glob.glob("/run/user/*/danklinux-shell/*/PLUGINS/plugin-schema.json"),
        os.path.expanduser("~/.config/DankMaterialShell/plugin-schema.json"),
        os.path.expanduser("~/.local/share/DankMaterialShell/plugin-schema.json"),
        str(repo_root / "tests" / "plugin-schema.json"),
    ]
    for path in candidate_paths:
        if os.path.isfile(path):
            return path
    return None

def validate_manifest():
    repo_root = Path(__file__).resolve().parent.parent
    manifest_path = repo_root / "plugin.json"

    if not manifest_path.is_file():
        print(f"FAILED: Manifest file not found at {manifest_path}")
        sys.exit(1)

    print(f"Checking manifest: {manifest_path}")
    try:
        with open(manifest_path, "r", encoding="utf-8") as f:
            manifest_data = json.load(f)
    except json.JSONDecodeError as err:
        print(f"FAILED: JSON syntax error in {manifest_path}: {err}")
        sys.exit(1)

    schema_path = find_schema_path(repo_root)
    if not schema_path:
        print("FAILED: DMS plugin-schema.json could not be located on the system.")
        sys.exit(1)

    print(f"Validating against DMS schema: {schema_path}")
    try:
        with open(schema_path, "r", encoding="utf-8") as f:
            schema_data = json.load(f)
    except Exception as err:
        print(f"FAILED: Unable to read schema at {schema_path}: {err}")
        sys.exit(1)

    try:
        validator = jsonschema.Draft7Validator(schema_data)
        errors = list(validator.iter_errors(manifest_data))
        if errors:
            print("FAILED: Schema validation errors found:")
            for e in errors:
                print(f"  - At '{'.'.join(str(p) for p in e.path)}': {e.message}")
            sys.exit(1)
        print("SUCCESS: plugin.json is strictly valid according to DMS plugin-schema.json!")
    except Exception as err:
        print(f"FAILED: Validation execution error: {err}")
        sys.exit(1)

if __name__ == "__main__":
    validate_manifest()
