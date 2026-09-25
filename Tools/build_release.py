#!/usr/bin/env python3
# =====================================================================
# Tools/build_release.py -- reproducible CurseForge zip builder
#
# Adapted from TomoMod's Tools/build_release.py. Copies the repo, drops
# the development-only files listed under `ignore:` in .pkgmeta, checks
# the result and zips it as <package-as>/ so it unzips straight into
# Interface/AddOns.
#
# The checks are the point. A zip is refused when:
#   - the TOC load graph is broken: a listed file missing, miscased
#     (fine on Windows, fatal on macOS and on the CI runner), or excluded
#     by .pkgmeta by mistake;
#   - an asset the code references is not in the package: .pkgmeta
#     already excludes source artwork, and one careless pattern there
#     would ship a meter with blank textures;
#   - a required file is missing (THIRD-PARTY-LICENSES.md: the LGPL of
#     LibSharedMedia requires its license text to travel with it);
#   - development files leak into the package (Python tooling, dotfiles).
#
# Pure standard library: no pip install, no native modules.
#
# Usage:
#     python3 Tools/build_release.py              # build .release/TomoDamageMeter-<ver>.zip
#     python3 Tools/build_release.py --check      # validate only, write nothing
#     python3 Tools/build_release.py --out DIR    # choose the output directory
# =====================================================================

import argparse
import fnmatch
import os
import re
import shutil
import sys
import tempfile
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

# Files the package must contain, relative to the addon folder.
REQUIRED_FILES = ["THIRD-PARTY-LICENSES.md"]

# Never acceptable inside the package, whatever .pkgmeta says.
FORBIDDEN_IN_PACKAGE = ["*.py", "*.pyc", ".*"]

# Extensions the client resolves when a texture path has none.
TEXTURE_EXTENSIONS = [".tga", ".blp", ".png", ".jpg"]

# Never ship the builder's own output or VCS state.
ALWAYS_IGNORE = [".git", ".release", "**/*.zip", "**/__pycache__"]


# ---------------------------------------------------------------------
# .pkgmeta -- only the subset this repo uses
# ---------------------------------------------------------------------
def read_pkgmeta(path):
    """Parse `package-as` and `ignore:` out of .pkgmeta.

    Deliberately not a YAML parser: supporting exactly the keys the repo
    uses keeps this dependency-free and keeps failures obvious.
    """
    meta = {"package-as": None, "ignore": []}
    section = None

    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.split("#", 1)[0].rstrip() if not raw.strip().startswith("#") else ""
        if not line.strip():
            continue

        if not line[0].isspace() and not line.lstrip().startswith("-"):
            key, _, value = line.partition(":")
            key, value = key.strip(), value.strip()
            if key == "package-as":
                meta["package-as"] = _unquote(value)
                section = None
            elif key == "ignore":
                section = key
            elif key == "move-folders":
                sys.exit("ERROR: .pkgmeta uses move-folders, which this builder "
                         "does not implement (TomoMod's does).")
            else:
                section = None
            continue

        stripped = line.strip()
        if section == "ignore" and stripped.startswith("-"):
            meta["ignore"].append(_unquote(stripped[1:].strip()))

    if not meta["package-as"]:
        sys.exit("ERROR: .pkgmeta has no `package-as:` entry.")
    return meta


def _unquote(value):
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1]
    return value


# ---------------------------------------------------------------------
# Ignore matching
# ---------------------------------------------------------------------
def is_ignored(relpath, patterns):
    """True when `relpath` (POSIX, relative to the repo root) is excluded.

    A pattern matches when it equals the path, is a parent directory of it,
    or globs it. `**/x` also matches a top-level `x`, which plain fnmatch
    would miss.
    """
    rel = relpath.replace(os.sep, "/")
    for pat in patterns:
        pat = pat.replace(os.sep, "/").rstrip("/")
        if not pat:
            continue
        if rel == pat or rel.startswith(pat + "/"):
            return True
        if fnmatch.fnmatchcase(rel, pat):
            return True
        if pat.startswith("**/") and fnmatch.fnmatchcase(rel, pat[3:]):
            return True
    return False


# ---------------------------------------------------------------------
# Version
# ---------------------------------------------------------------------
def read_version(toc_path):
    text = toc_path.read_text(encoding="utf-8-sig")
    match = re.search(r"^##\s*Version:\s*(.+?)\s*$", text, re.MULTILINE)
    if not match:
        sys.exit("ERROR: no `## Version:` line in %s" % toc_path.name)
    return match.group(1)


# ---------------------------------------------------------------------
# Staging
# ---------------------------------------------------------------------
def stage(meta, staging, repo=REPO):
    """Copy the repo into `staging/<package-as>/`, minus ignored paths."""
    patterns = list(meta["ignore"]) + ALWAYS_IGNORE
    root = staging / meta["package-as"]
    copied = 0

    for dirpath, dirnames, filenames in os.walk(repo):
        reldir = Path(dirpath).relative_to(repo).as_posix()
        reldir = "" if reldir == "." else reldir

        # Prune ignored directories so we never descend into .git at all.
        dirnames[:] = [
            d for d in sorted(dirnames)
            if not is_ignored(("%s/%s" % (reldir, d)).lstrip("/"), patterns)
        ]

        for name in sorted(filenames):
            rel = ("%s/%s" % (reldir, name)).lstrip("/")
            if is_ignored(rel, patterns):
                continue
            dest = root / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(Path(dirpath) / name, dest)
            copied += 1

    return root, copied


# ---------------------------------------------------------------------
# Validation -- the hard gate
# ---------------------------------------------------------------------
def _exact_case_file(root, relative):
    """The file at root/relative, only if every component matches in case."""
    current = root
    for part in Path(relative).parts:
        if not current.is_dir() or part not in {p.name for p in current.iterdir()}:
            return None
        current = current / part
    return current if current.is_file() else None


def validate_layout(staging):
    """One addon folder at the top, a sound TOC load graph, no nested addon."""
    problems = []
    tops = sorted(p for p in staging.iterdir() if p.is_dir())

    if len(tops) != 1:
        problems.append("expected exactly one addon folder at the zip root, found %d"
                        % len(tops))

    for top in tops:
        if not (top / (top.name + ".toc")).is_file():
            problems.append("%s/ has no %s.toc -- not a loadable addon folder"
                            % (top.name, top.name))
        for sub in sorted(top.rglob("*")):
            if sub.is_dir() and (sub / (sub.name + ".toc")).is_file():
                rel = sub.relative_to(staging).as_posix()
                # Bundled libraries legitimately carry their own .toc.
                if rel.split("/")[1:2] == ["Libs"]:
                    continue
                problems.append("nested addon folder %s -- WoW will not see it" % rel)

    # Walk the load graph from the TOC. Keep the spelling the TOC/XML gives
    # for the case check: Path.resolve() canonicalizes existing names on
    # Windows and would hide a bad `utils.lua` behind the real `Utils.lua`.
    visited, loading = set(), set()
    root = staging.resolve()

    def visit(path):
        lexical = Path(os.path.abspath(path))
        resolved = lexical.resolve()
        if not resolved.is_relative_to(root):
            problems.append("load reference escapes package: %s" % resolved)
            return
        rel = lexical.relative_to(root).as_posix()
        if _exact_case_file(root, lexical.relative_to(root)) is None:
            problems.append("missing, miscased or excluded load file: %s" % rel)
            return
        if resolved in loading:
            problems.append("cyclic load reference: %s" % rel)
            return
        if resolved in visited:
            return
        visited.add(resolved)
        loading.add(resolved)
        refs = []
        if resolved.suffix.lower() == ".toc":
            refs = [line.strip() for line in resolved.read_text(encoding="utf-8-sig").splitlines()
                    if line.strip() and not line.lstrip().startswith("#")]
        elif resolved.suffix.lower() == ".xml":
            try:
                refs = [node.attrib["file"] for node in ET.parse(resolved).iter()
                        if "file" in node.attrib]
            except ET.ParseError as err:
                problems.append("invalid XML %s: %s" % (rel, err))
        for ref in refs:
            visit(resolved.parent / ref.replace("\\", "/"))
        loading.remove(resolved)

    for top in tops:
        toc = top / (top.name + ".toc")
        if toc.is_file():
            visit(toc)
    return tops, problems


def _code_text(addon_root):
    """Lower-cased Lua, XML and TOC text of the staged addon, Libs excluded."""
    chunks = []
    for path in sorted(addon_root.rglob("*")):
        if not path.is_file() or path.suffix.lower() not in (".lua", ".xml", ".toc"):
            continue
        if path.relative_to(addon_root).parts[:1] == ("Libs",):
            continue
        chunks.append(path.read_text(encoding="utf-8-sig", errors="replace"))
    return "\n".join(chunks)


def validate_assets(addon_root, repo=REPO, package=None):
    """Every asset the code references must be in the package.

    Two complementary checks, because the code spells asset paths two ways:
      1. full literal paths, `Interface\\AddOns\\<package>\\...\\name[.ext]`:
         the file must exist in the package, with the exact case;
      2. prefix constants plus a bare name (`TEX .. "TDM_FrameGlow_128"`):
         every file under the repo's Assets/ whose name appears as a token in
         the staged code must have been staged too. This is the check that
         catches an .pkgmeta ignore pattern excluding an asset still in use.
    """
    problems = []
    package = package or addon_root.name
    text = _code_text(addon_root)
    lowered = text.lower()

    # 1. Full literal paths.
    literal = re.compile(r"Interface[\\/]+AddOns[\\/]+" + re.escape(package)
                         + r"[\\/]+([^\"'\]\s]+)", re.IGNORECASE)
    for match in sorted(set(m.group(1) for m in literal.finditer(text))):
        rel = re.sub(r"[\\/]+", "/", match)
        if rel.endswith("/"):
            continue  # a directory prefix; covered by check 2
        candidates = [rel] if Path(rel).suffix else [rel + ext for ext in TEXTURE_EXTENSIONS]
        if not any(_exact_case_file(addon_root, c) for c in candidates):
            problems.append("referenced asset missing or miscased in package: %s" % rel)

    # 2. Bare names against the repo's asset files.
    assets_dir = repo / "Assets"
    if assets_dir.is_dir():
        for path in sorted(assets_dir.rglob("*")):
            if not path.is_file():
                continue
            stem = path.stem.lower()
            token = re.compile(r"(?<![a-z0-9_\-])" + re.escape(stem) + r"(?![a-z0-9_\-])")
            if not token.search(lowered):
                continue
            rel = path.relative_to(repo)
            if _exact_case_file(addon_root, rel) is None:
                problems.append("asset referenced by the code but excluded from the "
                                "package: %s (check the ignore list in .pkgmeta)"
                                % rel.as_posix())
    return problems


def validate_contents(addon_root):
    """Required files present, development files absent."""
    problems = []
    for rel in REQUIRED_FILES:
        if not (addon_root / rel).is_file():
            problems.append("required file missing from package: %s" % rel)
    for path in sorted(addon_root.rglob("*")):
        rel = path.relative_to(addon_root).as_posix()
        if any(fnmatch.fnmatchcase(path.name, pat) for pat in FORBIDDEN_IN_PACKAGE):
            problems.append("development file in package: %s" % rel)
    return problems


def write_zip(staging, out_dir, package, version):
    out_dir.mkdir(parents=True, exist_ok=True)
    zip_path = out_dir / ("%s-%s.zip" % (package, version))
    if zip_path.exists():
        zip_path.unlink()

    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for path in sorted(staging.rglob("*")):
            if path.is_file():
                zf.write(path, path.relative_to(staging).as_posix())
    return zip_path


# ---------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="Build the TomoDamageMeter release zip.")
    parser.add_argument("--check", action="store_true",
                        help="validate the staged package, write no zip")
    parser.add_argument("--out", default=".release",
                        help="output directory (default: .release)")
    args = parser.parse_args()

    meta = read_pkgmeta(REPO / ".pkgmeta")
    package = meta["package-as"]
    version = read_version(REPO / ("%s.toc" % package))

    tmp = Path(tempfile.mkdtemp(prefix="tdm-release-"))
    try:
        staging = tmp / "stage"
        staging.mkdir()

        addon_root, copied = stage(meta, staging)
        tops, problems = validate_layout(staging)
        problems += validate_assets(addon_root, package=package)
        problems += validate_contents(addon_root)

        size = sum(p.stat().st_size for p in addon_root.rglob("*") if p.is_file())
        print("%s %s" % (package, version))
        print("  %d files staged, %.2f MB uncompressed" % (copied, size / (1024 * 1024)))

        if problems:
            print("\nPACKAGE ERRORS:")
            for problem in problems:
                print("  - %s" % problem)
            return 1

        if args.check:
            print("\nOK: package valid (--check, nothing written).")
            return 0

        out_dir = Path(args.out)
        if not out_dir.is_absolute():
            out_dir = REPO / out_dir
        zip_path = write_zip(staging, out_dir, package, version)
        size_mb = zip_path.stat().st_size / (1024 * 1024)
        display_path = zip_path.relative_to(REPO) if zip_path.is_relative_to(REPO) else zip_path
        print("\nOK: %s (%.2f MB)" % (display_path, size_mb))
        return 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
