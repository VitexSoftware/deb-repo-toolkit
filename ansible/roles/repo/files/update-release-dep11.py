#!/usr/bin/env python3
"""
Add dep11 file hashes to a Debian Release file and re-sign InRelease.

Usage: update-release-dep11.py <dist_dir> <gnupghome> <repo_key> <passphrasefile>

APT only downloads dep11/Components-*.yml.gz and icon archives if they are listed
in the signed Release/InRelease file. This script patches the Release file generated
by aptly (which does not know about dep11 files added afterwards) so that apt clients
can discover and fetch AppStream metadata.
"""
import sys
import os
import hashlib
import subprocess


def compute_hashes(filepath):
    md5 = hashlib.md5()
    sha1 = hashlib.sha1()
    sha256 = hashlib.sha256()
    sha512 = hashlib.sha512()
    size = os.path.getsize(filepath)
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            md5.update(chunk)
            sha1.update(chunk)
            sha256.update(chunk)
            sha512.update(chunk)
    return size, md5.hexdigest(), sha1.hexdigest(), sha256.hexdigest(), sha512.hexdigest()


def update_release(dist_dir, gnupghome, repo_key, passphrasefile):
    release_file = os.path.join(dist_dir, "Release")

    if not os.path.exists(release_file):
        print(f"No Release file found in {dist_dir}, skipping dep11 patching")
        return

    with open(release_file, "r") as f:
        content = f.read()

    dep11_files = []
    for root, _dirs, files in os.walk(dist_dir):
        for fname in sorted(files):
            filepath = os.path.join(root, fname)
            relpath = os.path.relpath(filepath, dist_dir)
            if "dep11" in relpath.replace(os.sep, "/"):
                dep11_files.append(relpath)
    dep11_files.sort()

    if not dep11_files:
        print("No dep11 files found under", dist_dir)
        return

    new_files = [p for p in dep11_files if p not in content]
    if not new_files:
        print("All dep11 files already present in Release — nothing to do")
        return

    hashes = {}
    for relpath in new_files:
        hashes[relpath] = compute_hashes(os.path.join(dist_dir, relpath))

    section_entries = {
        "MD5Sum:": lambda r: (hashes[r][0], hashes[r][1]),
        "SHA1:":   lambda r: (hashes[r][0], hashes[r][2]),
        "SHA256:": lambda r: (hashes[r][0], hashes[r][3]),
        "SHA512:": lambda r: (hashes[r][0], hashes[r][4]),
    }

    lines = content.splitlines()
    new_lines = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if line in section_entries:
            entry_fn = section_entries[line]
            new_lines.append(line)
            i += 1
            while i < len(lines) and lines[i].startswith(" "):
                new_lines.append(lines[i])
                i += 1
            for relpath in new_files:
                size, hashval = entry_fn(relpath)
                new_lines.append(f" {hashval} {size:16d} {relpath}")
        else:
            new_lines.append(line)
            i += 1

    with open(release_file, "w") as f:
        f.write("\n".join(new_lines) + "\n")

    print(f"Patched Release with {len(new_files)} dep11 entries in {dist_dir}")

    inrelease = os.path.join(dist_dir, "InRelease")
    release_gpg = os.path.join(dist_dir, "Release.gpg")
    env = {**os.environ, "GNUPGHOME": gnupghome}

    subprocess.run(
        ["gpg", "--homedir", gnupghome, "-u", repo_key,
         "--batch", "--yes", "--passphrase-file", passphrasefile,
         "--digest-algo", "SHA512", "-abs", "-o", release_gpg, release_file],
        check=True, env=env,
    )
    subprocess.run(
        ["gpg", "--homedir", gnupghome, "-u", repo_key,
         "--batch", "--yes", "--passphrase-file", passphrasefile,
         "--digest-algo", "SHA512", "--clearsign", "-o", inrelease, release_file],
        check=True, env=env,
    )
    print("Re-signed Release.gpg and InRelease")


if __name__ == "__main__":
    if len(sys.argv) != 5:
        print(f"Usage: {sys.argv[0]} <dist_dir> <gnupghome> <repo_key> <passphrasefile>")
        sys.exit(1)
    update_release(*sys.argv[1:])
