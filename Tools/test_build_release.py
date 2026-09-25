#!/usr/bin/env python3
"""Exercise the release gate with broken packages, not just the real tree.

Each test builds a throwaway repository, stages it exactly as the real
build does, and checks that one specific defect is reported -- and that
the intact fixture reports nothing, so a gate that went silent fails.

Usage:  python3 Tools/test_build_release.py
"""
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import build_release as B  # noqa: E402

PKGMETA = """\
package-as: TomoDamageMeter

ignore:
  - .pkgmeta
  - Tools
  - README.md
  - Assets/Textures/Source_Art.tga   # artwork for the project page
  - "**/*.bak"
"""

TOC = """\
## Interface: 120100
## Version: 9.9.9
## IconTexture: Interface\\AddOns\\TomoDamageMeter\\Assets\\Textures\\Icon_64.tga
Core\\Init.lua
Modules\\Meter.lua
"""


class Fixture(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        base = Path(self._tmp.name)
        self.repo = base / "repo"
        self.staging = base / "stage"
        self.staging.mkdir()
        self.write(".pkgmeta", PKGMETA)
        self.write("TomoDamageMeter.toc", TOC)
        self.write("THIRD-PARTY-LICENSES.md", "licenses\n")
        self.write("README.md", "readme\n")
        self.write("Tools/build.py", "print('dev only')\n")
        self.write("Core/Init.lua", "local ADDON_NAME, ns = ...\n")
        self.write("Modules/Meter.lua",
                   'local TEX = "Interface\\\\AddOns\\\\TomoDamageMeter\\\\Assets\\\\Textures\\\\"\n'
                   'local glow = TEX .. "Frame_Glow"\n')
        self.write("Assets/Textures/Icon_64.tga", "x")
        self.write("Assets/Textures/Frame_Glow.tga", "x")
        self.write("Assets/Textures/Source_Art.tga", "x")

    def write(self, rel, text):
        path = self.repo / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def problems(self):
        meta = B.read_pkgmeta(self.repo / ".pkgmeta")
        addon_root, _ = B.stage(meta, self.staging, repo=self.repo)
        _, problems = B.validate_layout(self.staging)
        problems += B.validate_assets(addon_root, repo=self.repo)
        problems += B.validate_contents(addon_root)
        return problems

    def assertReported(self, needle):
        problems = self.problems()
        self.assertTrue(any(needle in p for p in problems),
                        "expected a problem containing %r, got %r" % (needle, problems))


class IntactPackage(Fixture):
    def test_intact_fixture_is_clean(self):
        self.assertEqual(self.problems(), [])

    def test_ignored_files_are_not_staged(self):
        self.problems()
        root = self.staging / "TomoDamageMeter"
        self.assertFalse((root / "Tools").exists())
        self.assertFalse((root / "README.md").exists())
        self.assertFalse((root / "Assets/Textures/Source_Art.tga").exists())
        self.assertTrue((root / "Assets/Textures/Frame_Glow.tga").exists())


class LoadGraph(Fixture):
    def test_missing_lua(self):
        (self.repo / "Modules/Meter.lua").unlink()
        self.assertReported("Modules/Meter.lua")

    def test_miscased_toc_entry(self):
        self.write("TomoDamageMeter.toc", TOC.replace("Core\\Init.lua", "Core\\init.lua"))
        self.assertReported("miscased")

    def test_toc_file_excluded_by_pkgmeta(self):
        self.write(".pkgmeta", PKGMETA + "  - Modules\n")
        self.assertReported("Modules/Meter.lua")

    def test_escape(self):
        self.write("TomoDamageMeter.toc", TOC + "..\\..\\outside.lua\n")
        self.assertReported("escapes")

    def test_xml_cycle(self):
        self.write("cycle.xml", '<Ui><Include file="cycle.xml"/></Ui>')
        self.write("TomoDamageMeter.toc", TOC + "cycle.xml\n")
        self.assertReported("cyclic")

    def test_malformed_xml(self):
        self.write("bad.xml", "<Ui>")
        self.write("TomoDamageMeter.toc", TOC + "bad.xml\n")
        self.assertReported("invalid XML")

    def test_nested_addon(self):
        self.write("Extra/Extra.toc", "## Interface: 120100\n")
        self.assertReported("nested addon")


class Assets(Fixture):
    def test_literal_path_missing(self):
        (self.repo / "Assets/Textures/Icon_64.tga").unlink()
        self.assertReported("Icon_64.tga")

    def test_literal_path_miscased(self):
        self.write("TomoDamageMeter.toc", TOC.replace("Icon_64.tga", "icon_64.tga"))
        self.assertReported("icon_64.tga")

    def test_literal_path_without_extension(self):
        self.write("Core/Init.lua", 'local t = "Interface\\\\AddOns\\\\TomoDamageMeter\\\\Assets\\\\Textures\\\\Nope"\n')
        self.assertReported("Assets/Textures/Nope")

    def test_prefix_plus_name_excluded_by_pkgmeta(self):
        self.write(".pkgmeta", PKGMETA + "  - Assets/Textures/Frame_Glow.tga\n")
        self.assertReported("Frame_Glow.tga")

    def test_unreferenced_asset_may_be_excluded(self):
        # Source_Art.tga is excluded and referenced nowhere: not a problem.
        self.assertFalse(any("Source_Art" in p for p in self.problems()))


class Contents(Fixture):
    def test_license_file_required(self):
        (self.repo / "THIRD-PARTY-LICENSES.md").unlink()
        self.assertReported("THIRD-PARTY-LICENSES.md")

    def test_python_tooling_must_not_ship(self):
        self.write(".pkgmeta", PKGMETA.replace("  - Tools\n", ""))
        self.assertReported("Tools/build.py")

    def test_dotfiles_must_not_ship(self):
        self.write(".luacheckrc", "std = 'lua51'\n")
        self.assertReported(".luacheckrc")


class Parsing(unittest.TestCase):
    def test_ignore_patterns(self):
        pats = ["Tools", "**/*.bak", "Assets/Textures/Source_Art.tga"]
        self.assertTrue(B.is_ignored("Tools/x.py", pats))
        self.assertTrue(B.is_ignored("a.bak", pats))          # **/ also matches top level
        self.assertTrue(B.is_ignored("Core/a.bak", pats))
        self.assertTrue(B.is_ignored("Assets/Textures/Source_Art.tga", pats))
        self.assertFalse(B.is_ignored("ToolsExtra/x.lua", pats))  # prefix, not a parent dir
        self.assertFalse(B.is_ignored("Core/Init.lua", pats))

    def test_pkgmeta_comments_and_quotes(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / ".pkgmeta"
            path.write_text(PKGMETA, encoding="utf-8")
            meta = B.read_pkgmeta(path)
        self.assertEqual(meta["package-as"], "TomoDamageMeter")
        self.assertIn("**/*.bak", meta["ignore"])
        self.assertIn("Assets/Textures/Source_Art.tga", meta["ignore"])


if __name__ == "__main__":
    unittest.main()
