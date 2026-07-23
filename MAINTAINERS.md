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

## Publishing (offline, after merge)

From the AmigaImager checkout's `AmigaBuildKit/` (which has the base catalog):

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
git push          # GitHub Pages serves docs/ at packages.amiga-imager.com
```

## The published index

- Served from `docs/` via **GitHub Pages** (repo Settings → Pages → Source:
  `main` / `/docs`), behind the custom domain **packages.amiga-imager.com**
  (`docs/CNAME`; add the DNS `CNAME packages → <user>.github.io`, enable
  “Enforce HTTPS”).
- The AmigaImager app's `PackageRepoSync.defaultBaseURL` points at
  `https://packages.amiga-imager.com`, fetches `packages.json` + `.sig` over
  HTTPS, Ed25519-verifies, and seeds the verified index onto images.
- amipkg on the Amiga never fetches the index (it reads the seeded copy); it only
  fetches **archives** over plain HTTP — which is why archives live on Aminet, not
  here.

## Key hygiene

- Private key stays offline (e.g. `~/Desktop/amiga-imager-repo/SIGNING-KEY-KEEP-OFFLINE.txt`).
  Never commit it, never put it in an Actions secret. A leaked key = a forgeable
  index; rotating means baking a new public key into the app (a release).
- The public key (`tqZX…`) is baked into the app and safe to share.
