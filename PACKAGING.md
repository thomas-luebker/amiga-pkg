# Package your software for amipkg — in 5 minutes

You wrote (or love) an Amiga program and want every amipkg user to be able to
`amipkg install` it? This is the whole process. You need: **Python 3** on any
OS (Windows/Linux/macOS — no Amiga, no Mac, no Swift) and a GitHub account.

## 1. Host the archive somewhere stable

Upload your `.lha` to **Aminet** (preferred — mirrored, permanent, and
reachable over plain HTTP, which Amigas without AmiSSL need). An https-only
host (GitHub releases, your own site) also works, but users then need AmiSSL
installed to download it.

## 2. Generate the entry (one command)

```
git clone https://github.com/thomas-luebker/amiga-pkg
cd amiga-pkg
python3 amigapkg.py add --archive /path/to/YourApp.lha \
    --id yourapp --name "YourApp" --category Utilities \
    --version 1.2 --desc "One-line description" \
    --url http://aminet.net/util/misc/YourApp.lha \
    --out packages/yourapp.json
```

That computes the SHA-256 + size, stamps the added date, and writes a
complete entry. Rules: the id is lower-case `[a-z0-9._-]`; the archive at
`--url` must be byte-identical to the file you hashed.

Optional fields you can add by editing the JSON (see
`schema/entry.schema.json`):

- `"deps": [{"id": "mui38"}]` — needs MUI? amipkg installs it first.
- `"requirements": {"minCPU": "68020", "minKS": "3.0", "network": true}` —
  amipkg refuses machines that can't run it, with a clear message.
- A `recipe` with install ops (`copyGlob`, `placeFile`, `preScript`/
  `postScript`/`removeScript` inline AmigaDOS tidy-up lines). Without one,
  amipkg does a generic install into the user's install drawer — right for
  most drawer-style apps.

## 3. Validate + open a pull request

```
python3 amigapkg.py validate packages/yourapp.json
git checkout -b add-yourapp
git add packages/yourapp.json
git commit -m "add yourapp 1.2"
git push  # then open the PR on GitHub
```

CI re-runs validation and re-downloads your archive to check the hash. A
maintainer reviews licensing (is it freely redistributable?) and any script
lines, then signs the entry into the published catalog. From that moment,
every Amiga that runs `amipkg update` can install your software — and when
you release an update, the same one-file PR ships it to everyone.

## Updating your package later

New upstream version? If the URL is unversioned (typical Aminet), just open a
PR bumping `version`, `sha256`, `sizeBytes` — or ask a maintainer to run the
repo-wide refresh (`scripts/refresh-and-publish.sh`), which re-pins changed
archives automatically.

Questions → open an issue. Trust model → `SECURITY.md`.
