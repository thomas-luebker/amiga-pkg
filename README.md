# AmigaPKG — the package repository for AmigaImager / amipkg

This repo is the **gateway** for the software catalog that
[`amipkg`](https://github.com/thomas-luebker/amipkg) — the on-Amiga package
manager — reads. It
holds the package submissions, validates them, and publishes a single **signed**
index that amipkg and AmigaImager-built systems trust.

- **Get amipkg** (any AmigaOS 3.x system, no Amiga Imager needed):
  download [`amipkg.lha`](https://thomas-luebker.github.io/amiga-pkg/amipkg.lha)
  and extract it into a drawer of your choice — step-by-step guide:
  [INSTALL.md](https://github.com/thomas-luebker/amipkg/blob/main/INSTALL.md).
  amipkg **lives in that drawer** (binaries, signed catalog, receipt DB —
  like `MUI:`). Then double-click **Install** (self-contained: nothing
  outside the drawer is ever touched; uninstall = delete the drawer) or
  **Install-System** (additionally adds the `AMIPKG:` assign + Shell path
  to `S:User-Startup` as one marked, removable block, so `amipkg` works
  in every Shell after a reboot).
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

## Nightly freshness

A scheduled Action re-scans all upstream archives every night and opens a
review PR when Aminet (or any host) shipped a new version. **CI never
signs**: the maintainer merges, then signs + publishes locally
(`scripts/refresh-and-publish.sh`) - the Ed25519 key stays offline, so a
compromised runner can propose catalog changes but never deliver them to
an Amiga.

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


**Every package we serve is a file in [`packages/`](packages/)** — the
published index is generated 1:1 from these manifests (plus the signing
step). Spotted a wrong version, a better mirror, a missing dependency, or
an outdated description? Open a pull request against that file; corrections
are as welcome as new packages. Everyone who contributes is listed in
[`CONTRIBUTORS.md`](CONTRIBUTORS.md) - add yourself in your PR.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). In short: scaffold an entry with
`python3 amigapkg.py add …`, drop it in `packages/`, run `amigapkg.py validate`,
open a PR. CI checks it; a maintainer merges, signs, and publishes. The tooling is
**pure Python 3** — no Swift or AmigaImager needed, so anyone on any OS can add a
package.

## Or run your own repository

Since amipkg 0.7.0 the client installs from **multiple repositories**, so you do
not have to go through this one. A repository is two static files on any web
server, and signing yours gives your users the same on-Amiga verification the
official catalog gets.

**→ [HOSTING.md](https://github.com/thomas-luebker/amipkg/blob/main/HOSTING.md)**
in the client repo walks through it, including the keypair.

Submitting here is still the way to reach *everyone* by default — packages in
this catalog are human-reviewed, signed offline, and need no setup on the user's
machine.

Repositories other people run are listed in **[REPOSITORIES.md](REPOSITORIES.md)**
— a phone book, not an endorsement: each one is verified against its own key, and
listing yours is a pull request away.

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
