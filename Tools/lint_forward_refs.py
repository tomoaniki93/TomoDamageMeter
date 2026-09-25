#!/usr/bin/env python3
# =====================================================================
# Tools/lint_forward_refs.py -- file-scope locals used before declared
#
# In Lua a name resolves at compile time: a function that mentions
# `Foo` before the line `local Foo = ...` gets the GLOBAL Foo, forever,
# even if the local exists by the time the function runs. Nothing fails
# at load; the function silently reads nil, or throws "attempt to call a
# nil value" on the day that branch is reached.
#
# That is how `/tdm diag` was dead since it was written (the combat
# handler read a global `diagArmed` and would have called a global
# `ProbeSession`), and the same class of bug hid in TomoMod
# (LevelingBar, AstralForge). luacheck cannot flag it here because
# .luacheckrc ignores 113 (the WoW API surface is not enumerated).
#
# This check asks luacheck for 113 with no config, then keeps only the
# names that the SAME file declares later as a file-scope local
# (column 0). Nested locals are ignored on purpose: a same-named local
# inside another function is a different variable, and reporting it
# would only be noise.
#
# Usage:   python3 Tools/lint_forward_refs.py        (needs luacheck)
# Exit:    0 clean, 1 findings, 2 luacheck unavailable
# =====================================================================

import re
import shutil
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
ROOTS = ["Core", "Modules", "Config", "Locales"]

DECL = re.compile(r"^local\s+(?:function\s+([A-Za-z_]\w*)|([A-Za-z_][\w\s,]*?)\s*(?:=|$|--))")
HIT = re.compile(r"^(.+?):(\d+):\d+: (?:\(W113\) )?accessing undefined variable '([^']+)'")


def file_scope_locals(path):
    decl = {}
    text = path.read_text(encoding="utf-8-sig", errors="replace")
    for lineno, line in enumerate(text.splitlines(), 1):
        m = DECL.match(line)
        if not m:
            continue
        names = [m.group(1)] if m.group(1) else re.split(r"\s*,\s*", m.group(2).strip())
        for n in names:
            if n:
                decl.setdefault(n, lineno)
    return decl


def main():
    luacheck = shutil.which("luacheck")
    if not luacheck:
        sys.stderr.write("luacheck not found\n")
        return 2
    files = sorted(str(p.relative_to(REPO)) for r in ROOTS for p in (REPO / r).rglob("*.lua"))
    out = subprocess.run(
        [luacheck, "--no-config", "--std", "lua51", "--only", "113",
         "--formatter", "plain", *files],
        cwd=REPO, capture_output=True, text=True).stdout

    cache, findings = {}, []
    for line in out.splitlines():
        m = HIT.match(line)
        if not m:
            continue
        rel, lineno, name = m.group(1), int(m.group(2)), m.group(3)
        if rel not in cache:
            cache[rel] = file_scope_locals(REPO / rel)
        declared = cache[rel].get(name)
        if declared and declared > lineno:
            findings.append((rel, lineno, name, declared))

    for rel, lineno, name, declared in findings:
        print("%s:%d: '%s' resolves to a global here; the file-scope local "
              "is only declared at line %d" % (rel, lineno, name, declared))
    print("%d finding%s." % (len(findings), "" if len(findings) == 1 else "s"))
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
