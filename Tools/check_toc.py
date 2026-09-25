#!/usr/bin/env python3
# =====================================================================
# Tools/check_toc.py -- the TOC and the repository must agree
#
#   1. Every file the TOC lists exists, with the exact case (the
#      filesystem is case-sensitive on the CI runner and on macOS).
#   2. Every addon .lua under Core/ Modules/ Config/ Locales/ is listed.
#      An unlisted file never loads but still ships: that is how
#      Core/CombatTimerV3.lua and Modules/MinimapPositionV2.lua stayed
#      in the repository after 2.7.x retired them.
#
# Usage:   python3 Tools/check_toc.py
# Exit:    0 clean, 1 mismatch
# =====================================================================

import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TOC = REPO / "TomoDamageMeter.toc"
ROOTS = ["Core", "Modules", "Config", "Locales"]


def main():
    listed = []
    for raw in TOC.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        listed.append(line.replace("\\", "/"))

    problems = []
    for rel in listed:
        if not (REPO / rel).is_file():
            problems.append("listed in the TOC but missing: %s" % rel)

    listed_set = set(listed)
    for root in ROOTS:
        for path in sorted((REPO / root).rglob("*.lua")):
            rel = path.relative_to(REPO).as_posix()
            if rel not in listed_set:
                problems.append("never loaded (not in the TOC): %s" % rel)

    for p in problems:
        print(p)
    print("%d TOC entr%s checked, %d problem%s." % (
        len(listed), "y" if len(listed) == 1 else "ies",
        len(problems), "" if len(problems) == 1 else "s"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
