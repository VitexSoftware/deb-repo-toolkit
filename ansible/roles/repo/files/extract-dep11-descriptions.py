#!/usr/bin/env python3
"""
Extract package short descriptions (Summary) from AppStream DEP-11 metadata.

appstream-generator already parses every .deb's AppStream metainfo to produce
the icons served under /imgdeb/<pkgname>.png (see publish.yml). The same
Components-*.yml.gz files it writes to asgen/export/data/<dist>/<comp>/ carry
a "Summary" field per package, so the package browser popup can reuse this
already-generated data instead of querying aptly per package.

Usage: extract-dep11-descriptions.py <asgen_export_data_dir>

Prints a JSON object {pkgname: summary} to stdout. HTML-escapes summary text
since it originates from third-party package metadata.
"""
import sys
import os
import gzip
import glob
import json
import html

import yaml


def load_components(path):
    opener = gzip.open if path.endswith(".gz") else open
    with opener(path, "rt", encoding="utf-8", errors="replace") as f:
        try:
            for doc in yaml.safe_load_all(f):
                if isinstance(doc, dict):
                    yield doc
        except yaml.YAMLError:
            return


def extract_summary(doc):
    summary = doc.get("Summary")
    if isinstance(summary, dict):
        return summary.get("C") or next(iter(summary.values()), None)
    if isinstance(summary, str):
        return summary
    return None


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <asgen_export_data_dir>", file=sys.stderr)
        sys.exit(1)

    export_dir = sys.argv[1]
    descriptions = {}

    pattern = os.path.join(export_dir, "*", "*", "Components-*.yml.gz")
    for filepath in sorted(glob.glob(pattern)):
        for doc in load_components(filepath):
            pkgname = doc.get("Package")
            if not pkgname or pkgname in descriptions:
                continue
            summary = extract_summary(doc)
            if summary:
                descriptions[pkgname] = html.escape(summary.strip())

    json.dump(descriptions, sys.stdout)


if __name__ == "__main__":
    main()
