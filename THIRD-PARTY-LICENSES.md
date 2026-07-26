# Third-party libraries

TomoDamageMeter bundles the libraries below under `Libs/`. They are the work of
their respective authors and are **not** covered by this project's license.
The licence stated for each one is taken from the header of the file actually
shipped in this repository.

---

## LibStub

- **Path:** `Libs/LibStub/LibStub.lua`
- **Credits:** Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel, joshborke
- **Licence:** Public Domain

> LibStub is hereby placed in the Public Domain.

---

## CallbackHandler-1.0

- **Path:** `Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua`
- **Upstream:** part of the Ace3 project — <https://www.wowace.com/projects/ace3>
- **Licence:** the shipped file carries no licence header. Ace3 is distributed
  under a permissive licence; the canonical text lives in `LICENSE.txt` at the
  root of the Ace3 distribution.

> **Action required:** copy the current Ace3 `LICENSE.txt` next to the library
> file, or switch to fetching it via `externals` in `.pkgmeta` so the packager
> pulls the upstream copy including its licence.

---

## LibSharedMedia-3.0

- **Path:** `Libs/LibSharedMedia-3.0/LibSharedMedia-3.0.lua`
- **Author:** Elkano
- **Upstream:** <https://www.wowace.com/projects/libsharedmedia-3-0>
- **Licence:** **LGPL v2.1**, as declared in the file header.

The LGPL requires that the licence notice accompanies redistribution. A copy of
the LGPL v2.1 text should sit alongside the library file.

---

## Note on the project licence

This project is published as *All Rights Reserved*. That statement covers
TomoDamageMeter's own source only. The libraries above keep their own terms, and
LibSharedMedia-3.0 in particular is LGPL v2.1 — a blanket "All Rights Reserved"
over the repository as a whole is inaccurate while it is bundled.
