# Package your software for amipkg — in 5 minutes

> **Corrections welcome:** every entry the index serves lives in `packages/` — editing an existing file (wrong version, better mirror, missing dep) is just as valid a PR as adding a new package.


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

That covers most drawer-style apps already. Everything else — dependencies,
CPU/Kickstart floors, install recipes — is optional and explained key by key
in the **Reference** section below.

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


---

# Reference — every key explained

A package entry is one JSON file in `packages/`. Machine-checked by
`schema/entry.schema.json` + `amigapkg.py validate`; this section explains
what each key *means* and when to use it.

## Identity

| Key | Required | Meaning |
|---|---|---|
| `id` | yes | Unique, lower-case `[a-z0-9._-]`, starts with a letter/digit. This is what users type: `amipkg install <id>`. Never change it after merging — it keys the receipts on every user's machine. |
| `name` | yes | Display name shown in the GUIs ("YAM", not "yam"). |
| `version` | — | Display version, e.g. `"2.9p1"`. Use `"-"` when upstream has no usable version. Bumping it is what makes `amipkg check` offer the update. |
| `sortVersion` | — | Only when `version` doesn't compare naturally (e.g. `"1.10"` vs `"1.9"` — amipkg compares dotted numbers correctly, but suffixes like `p1`/`beta` may need help). |
| `description` | — | ONE line, plain ASCII (it renders on a 640-pixel Workbench). Say what the program *is*, not marketing. |
| `category` | — | Groups the GUI's category filter. Use an existing one: `Utilities`, `Games`, `Internet`, `Network`, `Audio`, `Graphics`, `Text`, `Development`, `Emulation`, `Libraries`, `System`. |
| `added` | — | `YYYY-MM-DD` repo-added date; drives the "Newest" sort in the GUIs. `amigapkg.py add` stamps it — don't backdate. |
| `tier` | — | `A` = installable on-Amiga by amipkg (the normal case). `B`/`C` = catalog-listed but needs the Amiga Imager build engine (see build-only capabilities below). |

## `archive` — where the bytes come from

| Key | Required | Meaning |
|---|---|---|
| `url` | yes | The canonical download. **Prefer plain-HTTP Aminet** (`http://aminet.net/<path>`) — every Amiga can fetch it without AmiSSL. https-only hosts work but add an AmiSSL requirement in practice. |
| `mirrors` | — | Fallback URLs tried in order when `url` fails (e.g. `http://us.aminet.net/...`, `http://se.aminet.net/...`). Same file, byte-identical. |
| `sha256` | yes* | Hex SHA-256 of the archive. This is the trust anchor: the catalog is signed, so a download that doesn't match is refused. `amigapkg.py add` computes it. |
| `sizeBytes` | yes* | Exact byte size — used for the download progress bar and the disk-space preflight. |

*Technically optional in the schema, but a PR without them will not be
merged — without the pin there is nothing to verify.

The archive may be an `.lha`/`.lzh` (normal) or a raw `.adf` floppy image
(amipkg extracts the disk and wraps it in a `<installdir>/<id>/` drawer).

## `requirements` — refuse machines that can't run it

amipkg checks these BEFORE downloading and refuses with a clear message.

| Key | Values | Meaning |
|---|---|---|
| `minCPU` | `"68000"` … `"68060"` | Lowest CPU that runs it. A 68000 user asking for a 68020-only program gets told exactly that. |
| `minKS` | `"2.04"`, `"2.1"`, `"3.0"`, `"3.1"`, `"3.1.4"`, `"3.2"`, `"3.5"`, `"3.9"` | Minimum Kickstart. |
| `network` | `true` | Program needs a TCP/IP stack at runtime (informational). |
| `amiSSL` | `true` | Program needs AmiSSL at runtime (informational; also implied when your `url` is https-only). |
| `chipRAMKB` | integer | Minimum chip RAM in KB (rarely needed). |

## `deps`, `provides`, `conflicts`

```json
"deps": [ { "id": "mui38" }, { "id": "amissl", "min": "5.20" } ]
```

- `deps` — installed first, automatically, in dependency order. `min` sets a
  minimum version of the dependency.
- `provides` — alternative names this package satisfies (another entry can
  depend on the capability instead of the concrete package).
- `conflicts` — ids that must NOT be installed at the same time; amipkg
  refuses the install and names the conflict.

Common dependency ids already in the catalog: `mui38` (MUI 3.8),
`amissl` (AmiSSL), `xadmaster`, `whdload`, `igame`.

## `recipe` — how to install (optional!)

**No recipe = generic install**, which is right for most software: amipkg
extracts the archive, strips junk (`.info` orphans of removed junk,
`Installer` scripts, readme droppings), and puts the program drawer into the
user's install dir (`SYS:Programs` by default, user-configurable via
`amipkg dir`, per-package overrides included). Only write a recipe when the
generic result is wrong (files must land in `C:`/`Libs:`/`Devs:`, a boot
script needs a line, etc.).

```json
"recipe": {
  "recipeSchema": 2,
  "ops": [ ... ]
}
```

`recipeSchema`: `1` = classic (all dests relative to the boot volume).
`2` = additionally allows **assign-absolute dests** ("AMIPKG:", "MUI:") —
needs client 0.4+; older clients cleanly refuse instead of guessing.

Ops run in order. The vocabulary (each op lists its JSON keys):

### File ops

- **`placeFile`** `{ "op": "placeFile", "src": "<path in archive>",
  "dest": "<drawer>" }` — copy ONE file. `dest` is relative to the boot
  volume (`"C"`, `"Libs"`, `"Devs/Monitors"`) or, with `recipeSchema` 2,
  assign-absolute (`"AMIPKG:"` — trailing colon, no slash). The file keeps
  its name.
- **`copyGlob`** `{ "op": "copyGlob", "src": "YourApp/Libs/*.library",
  "dest": "Libs", "rename": "<optional new name>" }` — copy every file
  matching the wildcard at that path depth. Case-insensitive, matched
  relative to the extract root. With an exact (starless) `src`, `rename`
  gives the file a new name at `dest`.
- **`stripJunk`** `{ "op": "stripJunk" }` — explicit junk pass (the generic
  installer does this implicitly; in a recipe you decide).
- **`mergeNested`** `{ "op": "mergeNested" }` — fold the `Foo/Foo/…` double
  drawer many archives ship into one level.
- **`setExec`** `{ "op": "setExec", "scope": "C", "depth": 1 }` — set the
  execute/script protection bits on files in `scope` (needed for shell
  scripts; binaries are detected automatically).

### System-integration ops

- **`scriptInject`** `{ "op": "scriptInject", "target": "S:User-Startup",
  "overlay": "<file in archive>", "marker": "YourApp", "mode": "append" }` —
  add a marked block to a boot script. The block is recorded in the receipt
  and **stripped again on `amipkg remove`** — this is the ONLY sanctioned way
  to touch User-Startup.
- **`tooltypeEdit`** `{ "op": "tooltypeEdit", "icon": "<path to .info>",
  "key": "SCREENMODE", "value": "..." }` — set one tooltype in an icon.
- **`makeAssign`** `{ "op": "makeAssign", "name": "YOURAPP",
  "path": "<drawer>" }` — create an assign at install time.

### Script ops (reviewed line by line)

```json
{ "op": "postScript", "lines": [
  "If Exists SYS:WBStartup",
  "  Echo \"...\"",
  "EndIf"
] }
```

- **`preScript`** — runs BEFORE the file ops; a non-zero return code
  **aborts the install** (use it as a guard).
- **`postScript`** — runs after; a failure only warns.
- **`removeScript`** — saved into the receipt DB and executed by
  `amipkg remove` before file deletion (undo what postScript did).

Rules: plain AmigaDOS, max ~600 characters per script, no downloads, no
deletes outside the package's own files. Every line is human-reviewed in the
PR — that is the deal that keeps script ops in the catalog.

## `requiredCapabilities` — what a client must support

List the capability id for every op family your recipe uses, so an older
client refuses cleanly instead of half-installing:

| Capability | Needed for |
|---|---|
| `place-file-v1` | `placeFile` |
| `copy-glob-v1` | `copyGlob` |
| `strip-junk-v1` / `merge-nested-v1` / `set-exec-v1` | the matching op |
| `script-inject-v1` | `scriptInject` |
| `tooltype-edit-v1` | `tooltypeEdit` |
| `make-assign-v1` | `makeAssign` |
| `pre-post-script-v1` | `preScript` / `postScript` / `removeScript` |

**Build-only capabilities** — `host-builtin-v1`, `icon-patch-v1`,
`adf-unwrap-v1`, `installer-script-v1` — mark packages that only the Amiga
Imager build engine can install (arbitrary Installer scripts, host-side icon
work). amipkg lists them but refuses the on-Amiga install with a clear
message. Don't use these for community submissions; if your package seems to
need one, open an issue first — usually a recipe can do it portably.

## `install`

Host-catalog block used by the Amiga Imager build engine (dock entries,
image-build routing). Community entries normally omit it entirely.

## Worked example — a library package with a boot line

```json
{
  "id": "examplelib",
  "name": "example.library",
  "version": "47.3",
  "category": "Libraries",
  "description": "Example shared library (47.3)",
  "added": "2026-07-26",
  "archive": {
    "url": "http://aminet.net/util/libs/ExampleLib.lha",
    "mirrors": ["http://us.aminet.net/util/libs/ExampleLib.lha"],
    "sha256": "…64 hex chars…",
    "sizeBytes": 12345
  },
  "requirements": { "minKS": "3.0" },
  "recipe": {
    "recipeSchema": 1,
    "ops": [
      { "op": "placeFile", "src": "ExampleLib/Libs/example.library",
        "dest": "Libs" },
      { "op": "postScript", "lines": [
        "Echo \"example.library installed - reboot to activate\"" ] }
    ]
  },
  "requiredCapabilities": ["place-file-v1", "pre-post-script-v1"],
  "tier": "A"
}
```
