# Contributing a package

Thanks for helping grow the Amiga software catalog! Adding a package is a pull
request that adds **one JSON file** to `packages/`. You do **not** need any
signing key — a maintainer signs approved packages into the index.

## 1. Make sure the package is redistributable

Only submit software you may legally redistribute:

- Freeware / public-domain / open-source, **or**
- software whose author permits redistribution.

Prefer archives already on **[Aminet](https://aminet.net)** — they're stable,
mirrored, and reachable over plain HTTP (which `amipkg` needs on the Amiga).
Don't link personal/temporary URLs; they rot and can be swapped.

## 2. Create the entry

Scaffold it from the archive with the bundled tool — **`amigapkg.py`** needs only
**Python 3** (no Swift, no AmigaImager, any OS). It computes the SHA-256 + size for
you:

```
python3 amigapkg.py add \
  --archive /path/to/foo.lha \
  --id foo --name "Foo" --category "Utilities" --version "1.2" \
  --url https://aminet.net/.../foo.lha \
  --out packages/foo.json
```

Then open `packages/foo.json` and add anything extra (deps, requirements, a longer
description). Copying an existing `packages/*.json` and editing by hand works too —
just follow `schema/entry.schema.json`.

> Maintainers with the AmigaImager checkout can use the equivalent Swift tool,
> `swift run pkgindex add …` — same entry format.

**Rules** (CI enforces these — run `amigapkg.py validate`):

- `id` is unique and lower-case `[a-z0-9._-]`.
- `name` is set; `category` is a sensible group (e.g. Utilities, Games, Network…).
- `archive.url` points at the real, hosted `.lha`; `archive.sha256` **matches** it
  (64 lower-case hex). CI downloads the archive and checks.
- `requiredCapabilities` only lists known capability tokens (see the schema).
  A package that lists `installer-script-v1` (runs arbitrary AmigaOS Installer
  code) gets extra scrutiny.

## 3. Self-check

```
python3 amigapkg.py validate packages/foo.json --check-archives
```

Fix anything it reports.

## 4. Open the pull request

One package per PR when you can. CI runs the validator; a maintainer reviews the
metadata + license, then merges and publishes the signed index. Once published,
`amipkg` can `fetch`/verify your package on any AmigaImager image.

## Fetch vs install

An entry with an `archive` is **fetch-able** immediately (download + verify). For
`amipkg` to also **install** it on the Amiga, add a portable `recipe` (Tier-A ops
— copy/rename/strip/script-inject, see the schema). Fetch-only entries are welcome;
recipes can be added later.
