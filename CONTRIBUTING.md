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

Easiest — scaffold it from the archive (computes the SHA-256 + size for you).
You need the AmigaImager tools checked out; run from its `AmigaBuildKit/`:

```
swift run pkgindex add \
  --archive /path/to/foo.lha \
  --id foo --name "Foo" --category "Utilities" --version "1.2" \
  --url https://aminet.net/.../foo.lha \
  --out /path/to/amiga-pkg/packages/foo.json
```

No toolchain? Copy an existing `packages/*.json`, follow `schema/entry.schema.json`,
and compute the digest yourself: `shasum -a 256 foo.lha`.

**Rules** (CI enforces these — see `scripts/validate.py`):

- `id` is unique and lower-case `[a-z0-9._-]`.
- `name` is set; `category` is a sensible group (e.g. Utilities, Games, Network…).
- `archive.url` points at the real, hosted `.lha`; `archive.sha256` **matches** it
  (64 lower-case hex). CI downloads the archive and checks.
- `requiredCapabilities` only lists known capability tokens (see the schema).
  A package that lists `installer-script-v1` (runs arbitrary AmigaOS Installer
  code) gets extra scrutiny.

## 3. Self-check

```
swift run pkgindex validate --path /path/to/amiga-pkg/packages/foo.json --check-archives
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
