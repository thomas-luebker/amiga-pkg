# AmigaPKG — the package repository for AmigaImager / amipkg

This repo is the **gateway** for the software catalog that
[`amipkg`](https://amiga-imager.com) — the on-Amiga package manager — reads. It
holds the package submissions, validates them, and publishes a single **signed**
index that amipkg and AmigaImager-built systems trust.

- **Get amipkg** (any AmigaOS 3.x system, no Amiga Imager needed):
  [Releases](https://github.com/thomas-luebker/amiga-pkg/releases) —
  download `amipkg.lha`, extract, double-click **Install**.
- **Browse / add packages:** `packages/` — one JSON file per package.
  **Want yours in the catalog? [PACKAGING.md](PACKAGING.md) — 5 minutes, pure
  Python, no Amiga needed.**
- **The published index** (what `amipkg update` fetches):
  <http://amiga-imager.org/packages/packages.json> (+ `packages.json.sig`) —
  plain HTTP, because classic Amigas have no TLS without AmiSSL; the signature
  makes that safe. The same files are also served over HTTPS at
  <https://thomas-luebker.github.io/amiga-pkg/packages.json> (GitHub Pages from
  `docs/`), which is what the AmigaImager app uses and what amiga-imager.org
  mirrors live — push here and both endpoints update together.

## How it works

```
 packages/<id>.json  ──►  pkgindex generate --extra  ──►  docs/packages.json
   (submissions)            (+ built-in base catalog)        + docs/packages.json.sig
                                    │                              │
                                    │ signed offline               │ GitHub Pages (https)
                                    ▼ (project Ed25519 key)        ▼ + amiga-imager.org (http mirror)
                          amipkg (`amipkg update`) and the AmigaImager app
                          verify the Ed25519 signature; amipkg then verifies
                          each downloaded archive by SHA-256 against that
                          trusted index.
```

**The serving host is untrusted.** The app and `amipkg` verify the Ed25519
signature against a baked-in public key — the bytes can come from GitHub Pages,
a mirror, or anywhere, and a tampered or swapped index simply fails verification.
That is why publishing from a plain static host is safe.

## Trust model (why you can't just push a package)

The index is signed **once** by the project's offline key; each entry's
`archive.sha256` transitively authenticates its archive. If anyone could sign,
that guarantee would collapse — so this repo is **curated**: you *submit* a
package (a pull request), a maintainer *reviews and signs it in*. Same model as
Homebrew's `homebrew-core`. Contributors never need a key.

- Project public key: `tqZXIleRDYeU69ZsLNdvN790MUYdEKqvHctivyIhLEY=`
- The private key is **never** in this repo and never in CI. Signing happens
  offline on a maintainer's machine (see `MAINTAINERS.md`).

## Where archives live

Package `.lha` archives are **not** stored here. Link to a stable host — ideally
[Aminet](https://aminet.net) (mirrored, long-lived, and reachable over plain
HTTP, which is what `amipkg` on the Amiga needs). CI verifies that the archive at
`archive.url` matches the `archive.sha256` in the entry.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). In short: scaffold an entry with
`python3 amigapkg.py add …`, drop it in `packages/`, run `amigapkg.py validate`,
open a PR. CI checks it; a maintainer merges, signs, and publishes. The tooling is
**pure Python 3** — no Swift or AmigaImager needed, so anyone on any OS can add a
package.

## Layout

```
amigapkg.py          the standalone Python tool: `add` (scaffold) + `validate`
packages/            submissions — one <id>.json Entry per package
docs/                the PUBLISHED site (GitHub Pages): packages.json + .sig
schema/              entry.schema.json — the Entry shape + rules
.github/workflows/   validate.yml — runs amigapkg.py on every PR
```

## License

Repository content (manifests, tooling, schema) is MIT (see `LICENSE`). Listed
**packages retain their own licenses** and are hosted externally — this repo only
describes and links them.
