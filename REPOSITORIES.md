# Known amipkg repositories

Since amipkg 0.7.0 the client installs from **any number of repositories**, not
just this one. This file lists the public ones we know about, so people can find
them — and so developers shipping their own software have somewhere to point at.

**Add yours by pull request.** The rules are at the bottom, and they are short.

---

## The directory

| Name | id | URL | Public key | Maintained by |
|---|---|---|---|---|
| AMIGAworld | `AMIGAworld` | `https://www.amigaworld.de/software/amipkg` | *pending — see note* | djbase |

**AMIGAworld** — the Fallout 1 & 2 ports and the Lumi tools (LumiFTP, LumiPass,
LumiReg, LumiWeather), maintained by their author.
*Listing pending: the published catalog does not verify against the key we were
given, so no key is printed here yet. Publishing a key that fails verification
would hand every user a signature warning.*

---

## What a listing here does and does not mean

**It is a phone book, not an endorsement.** These repositories are not reviewed
by us, their contents are not checked by us, and appearing here says only that
the repository exists and answered when we looked.

**Trust is per repository.** Each one is verified against **its own** key, pinned
when you add it. The official key never vouches for anyone else's catalog, and
no repository can vouch for another. That is deliberate: adding a repository is a
decision to trust that operator, and it should feel like one.

**Order is priority.** The first repository that provides a package id wins, so a
repository you place above another shadows it. `amipkg info <id>` shows which
repository a package came from once you have more than one, and `repo:id`
installs from a specific one.

---

## Adding one

```
amipkg repo add <Name> <URL> <public-key>
amipkg update
```

Leave the key off and amipkg asks you to confirm once, in as many words: an
unsigned catalog can be rewritten in transit, and the SHA-256 pins do not save
you, because they live inside the catalog being rewritten.

---

## Getting listed

Open a pull request adding a row and a short description. Requirements:

1. **It is public** and stays up — no login, no rate-limited host.
2. **It is signed**, and the catalog verifies against the key you submit:
   ```
   amipkg-repo-sign verify <your-public-key> packages.json
   ```
   Run that against the **published** files, not your local copies. The most
   common failure is a catalog updated without re-signing, or a key rotated
   after it was shared.
3. **Say who you are** and what the repository contains, briefly.
4. **You maintain it.** Repositories that stop resolving get removed; that is
   not a judgement, just housekeeping.

We may decline a listing (malware, impersonation, someone else's software
without permission). Everything else goes in — including repositories that
compete with this one.

Hosting a repository is documented in
**[HOSTING.md](https://github.com/thomas-luebker/amipkg/blob/main/HOSTING.md)**,
and `tools/amipkg-repo-sign` in the client repo does the keypair and signing.
