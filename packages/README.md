# packages/ — submissions

One JSON file per package, named `<id>.json`, each a package **Entry** (see
`../schema/entry.schema.json`). This is where community submissions live; a
maintainer merges + signs them into the published `docs/packages.json`.

Add one with `pkgindex add` (computes the archive SHA-256), or copy an existing
entry and follow the schema. Then `pkgindex validate --path packages/foo.json
--check-archives` (or `python3 ../scripts/validate.py packages/foo.json
--check-archives`) before opening a PR. See `../CONTRIBUTING.md`.

Minimal fetch-only example:

```json
{
  "id": "foo",
  "name": "Foo",
  "category": "Utilities",
  "version": "1.2",
  "description": "Does a useful thing.",
  "archive": {
    "url": "https://aminet.net/util/misc/foo.lha",
    "sha256": "0000000000000000000000000000000000000000000000000000000000000000",
    "sizeBytes": 12345
  },
  "requiredCapabilities": []
}
```
