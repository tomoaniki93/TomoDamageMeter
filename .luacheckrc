-- .luacheckrc — TomoDamageMeter static analysis config (Lua 5.1 / WoW Midnight
-- and Forever). Same policy as TomoMod's .luacheckrc.
--
-- Run locally:   luacheck .
-- CI runs the same on every push (see .github/workflows/ci.yml).
--
--  * std = "lua51" enforces the Lua 5.1 surface (no table.unpack, goto,
--    bitwise operators, ...).
--  * 113 ("accessing an undefined global") is off: the WoW API surface is not
--    enumerated. Its blind spot -- a file-scope local used before its
--    declaration -- is covered by Tools/lint_forward_refs.py instead.
--  * 111/112 ("setting/mutating an undefined global") stay ON, so a forgotten
--    `local` is caught. Add any new intentional global to `globals` below.
--  * Shadowing / redefinition (411/421/431/432), trailing whitespace
--    (611/612/614) and unused arguments are off: event handlers routinely
--    ignore trailing args, and those patterns are intentional style here.

std = "lua51"
codes = true
max_line_length = false

exclude_files = {
    "Libs/",
}

ignore = {
    "113",  -- accessing an undefined global (see header)
    "411",  -- redefining a local
    "421",  -- shadowing a local
    "431",  -- shadowing an upvalue
    "432",  -- shadowing an upvalue argument
    "611",  -- line contains trailing whitespace
    "612",  -- trailing whitespace in a comment
    "614",  -- trailing whitespace in a string
}

unused_args = false

-- Globals TomoDamageMeter writes: its SavedVariable and slash registration.
-- The AddonCompartment callbacks are assigned through _G explicitly.
globals = {
    "TomoDamageMeterDB",
    "SLASH_TDM1", "SLASH_TDM2", "SlashCmdList",
}
