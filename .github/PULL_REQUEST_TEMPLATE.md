<!-- Thanks for contributing to AmigaPKG! One package per PR keeps review fast.
     Corrections to existing entries are as welcome as new packages -
     for a correction, just tick the checks that apply. -->

## What kind of PR is this?

- [ ] New package (`packages/<id>.json` added)
- [ ] Correction to an existing entry (version, sha256, mirror, deps, description, ...)

## Checklist (see [PACKAGING.md](../PACKAGING.md) for details)

- [ ] The archive is **freely distributable** (Aminet-style licence, author permission, or own software)
- [ ] Readme/docs say **`Architecture: m68k-amigaos`** - it is NOT a ppc-amigaos/MorphOS/AROS-only build
- [ ] Archive is **`.lha` or `.adf`** (the client cannot extract `.zip`)
- [ ] `sha256` + `sizeBytes` computed from a **fresh download** of the exact `url`
  (`python3 amigapkg.py add <url>` does this for you)
- [ ] `requirements` are honest (`minCPU`/`minKS` from the readme, `network` if the app needs a TCP/IP stack)
- [ ] `deps` list what the app needs at runtime (mui38, amissl, ahi, reqtools, ...)
- [ ] Aminet URLs use `http://aminet.net/...` + `us.`/`se.` mirrors; author sites prefer a plain-HTTP `url` when the host serves it byte-identically
- [ ] `python3 amigapkg.py validate` passes locally
- [ ] (optional, encouraged) Added myself to [CONTRIBUTORS.md](../CONTRIBUTORS.md)

## Why this package / change?

<!-- One or two sentences: what is it, why is it worth catalog space,
     or what was wrong before? -->
