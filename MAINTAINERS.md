# Maintainer guide — reviewing, signing, publishing

Only maintainers with the offline signing key publish. **The private key never
touches this repo or CI.**

## Reviewing a submission PR

1. Let CI (`.github/workflows/validate.yml`) pass — schema, id, and the archive
   SHA-256 match.
2. Check by hand what CI can't: **license / redistribution** (is the archive
   legitimately redistributable?), that the archive host is stable (Aminet
   preferred), and — if the entry has a `recipe` or `installer-script-v1` — that
   it's sane. `installer-script-v1` runs arbitrary AmigaOS code; treat it like
   reviewing a shell script.
3. Merge to `main`.

## One-shot: refresh every package + re-sign + publish

Most Aminet URLs are unversioned, so when a batch of upstream versions moves you
don't edit entries by hand — run the whole repo through one command:

```
scripts/refresh-and-publish.sh --check-only   # report which upstreams changed
scripts/refresh-and-publish.sh                # refresh entries + re-sign locally
scripts/refresh-and-publish.sh --push         # + git commit & push docs/
```

It re-downloads each archive, updates changed `sha256`/`sizeBytes`/`version`,
validates, regenerates + Ed25519-signs the index, and (with `--push`) publishes.
The private key never leaves disk (only its `privateKey:` line is copied to a
temp file, used, and deleted on exit). Paths default to the standard checkout;
override with `--key` / `--kit` or `AMIPKG_SIGNING_KEY` / `AMIGABUILDKIT_DIR`.

On-Amiga, users then run `amipkg update` (pulls the new signed index),
`amipkg check` (lists what's outdated), and `amipkg upgrade` (reinstalls the
newer versions — removing each old version's files first).

## Publishing manually (offline, after merge)

For a single reviewed submission, sign directly from the AmigaImager checkout's
`AmigaBuildKit/` (which has the base catalog):

```
swift run pkgindex generate \
  --rules ../BundledResources/InputFiles/ListofPackagestoInstall.CSV \
  --extra   <amiga-pkg>/packages/ \
  --archives <local-archives-dir> \
  --sign      @<path-to-private-key.txt> \
  --public-key tqZXIleRDYeU69ZsLNdvN790MUYdEKqvHctivyIhLEY= \
  --out <amiga-pkg>/docs/packages.json
```

This writes `docs/packages.json` **and** `docs/packages.json.sig` (the `--sign`
step also self-verifies against `--public-key`). Then:

```
cd <amiga-pkg>
git add docs/packages.json docs/packages.json.sig packages/
git commit -m "publish: <what changed>"
git push          # updates BOTH endpoints: GitHub Pages + the amiga-imager.org mirror
```

## The published index (two endpoints, one push)

- **Canonical for on-Amiga clients:** **http://amiga-imager.org/packages/**
  (`packages.json` + `.sig`) — plain HTTP, because `amipkg update` runs on
  machines without TLS (AmiSSL optional). The amiga-imager.org WordPress
  host-router plugin PROXIES these two files live from GitHub Pages
  (server-side HTTPS, ~5-minute cache) — no separate deploy step, no secrets.
- **HTTPS endpoint / backend:** `docs/` via **GitHub Pages** (repo Settings →
  Pages → Source: `main` / `/docs`) at
  **https://thomas-luebker.github.io/amiga-pkg/**. The AmigaImager app's
  `PackageRepoSync.defaultBaseURL` fetches from here, Ed25519-verifies, and
  seeds the verified index onto built images.
- So: one `git push` to `main` publishes everywhere. The host is untrusted
  either way — clients verify the signature, not the transport.
- amipkg fetches the index from the .org mirror and **archives** from their
  hosts (Aminet over plain HTTP; https hosts like GitHub only with AmiSSL
  installed).
- Client downloads (`amipkg.lha` tester bundle + `amipkg-client.lha`
  self-update asset) live on **GitHub Releases**:
  https://github.com/thomas-luebker/amiga-pkg/releases — the catalog's
  `amipkg` entry pins the client asset's sha256, so re-pin + re-sign whenever
  the release binaries change (`amipkg/dist/make-bundle.sh` prints the sha).
  **Pin the VERSIONED asset URL** (`releases/download/vX.Y.Z/...`), never
  `releases/latest` - latest floats while the sha pin is fixed, so any client
  with a slightly older catalog gets a guaranteed (safe, but confusing) sha
  refusal the moment a new release lands. Bump version + url tag + sha256 +
  sizeBytes TOGETHER, always after a `make clean` build (the Makefile's
  header deps force relinks, but verify all three `$VER`s anyway).

## Key hygiene

- Private key stays offline (e.g. `~/Desktop/amiga-imager-repo/SIGNING-KEY-KEEP-OFFLINE.txt`).
  Never commit it, never put it in an Actions secret. A leaked key = a forgeable
  index; rotating means baking a new public key into the app (a release).
- The public key (`tqZX…`) is baked into the app and safe to share.

- After a client release: `cp` the new `amipkg.lha` to `docs/amipkg.lha` too — the
  Pages landing page offers it as a direct download.
