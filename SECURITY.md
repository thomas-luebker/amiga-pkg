# Security model & reporting

## The trust chain

1. **The catalog is signed offline.** `docs/packages.json` is signed with the
   project's Ed25519 key on a maintainer's machine — the private key is never
   in this repository, never in CI, never on a server. Clients (amipkg on the
   Amiga, the Amiga Imager app) verify `packages.json.sig` against a
   **baked-in public key** (`tqZXIleRDYeU69ZsLNdvN790MUYdEKqvHctivyIhLEY=`)
   before trusting a single byte of the catalog.
2. **Every archive is pinned.** Each entry carries the SHA-256 of its archive
   *inside the signed catalog*, so one signature transitively authenticates
   every download. amipkg refuses any download whose hash doesn't match.
3. **The transport is untrusted by design.** Because of 1+2, plain-HTTP
   serving (which classic Amigas without AmiSSL require) is safe: a tampered
   or swapped index/archive simply fails verification, no matter which
   mirror, proxy, or CDN delivered it. TLS (via optional AmiSSL) is used for
   *host compatibility* (https-only hosts), not as the trust root — which is
   also why certificate verification is not relied upon.

## What review gates

Anyone can PR a package, but nothing reaches users unsigned:

- CI validates schema, ids, and that the archive at `archive.url` matches the
  entry's `sha256`.
- A maintainer reviews **licensing/redistributability** and every entry that
  carries native-code capability: `installer-script-v1` (vendor Installer
  scripts) and `pre-post-script-v1` (inline AmigaDOS lines — reviewed
  line-by-line; that's why they must be inline, not shipped in the archive).
- Only then is the entry signed into the published catalog.

## Known limitations (honest list)

- A leaked signing key forges the catalog. Rotation requires shipping a new
  public key in the clients (a release). The key lives offline; there is
  currently a single maintainer (bus factor 1 — a second keyholder is
  planned).
- amipkg does not sandbox installed software. The catalog curates *sources*;
  installed programs run with full AmigaOS privileges like any Amiga
  software (AmigaOS has no memory protection).
- Archives are hosted upstream (Aminet, vendor sites). The SHA-256 pin means
  an upstream compromise yields a refused download, not a compromised
  install — but it can deny availability until the entry is re-pinned.

## Reporting a vulnerability

Open a GitHub issue for non-sensitive problems. For anything sensitive
(signing, verification bypass, catalog integrity), email the maintainer:
**thomas@amiga-imager.com** — please include steps to reproduce. You'll get a
response as fast as a hobby project allows, and credit in the fix notes
unless you prefer otherwise.
