---
name: version-update
description: Check all packages in this Nix package set for newer upstream versions and update them with pinned hashes. Auto-discovers every package under pkgs/by-name/ - no manual list needed. Use when the user asks about updates or wants to bump versions.
---

# Version Update

Auto-discover every package under `pkgs/by-name/` and update each one to the latest upstream version. No hardcoded package list - the skill reads the filesystem, extracts version + source pattern, picks the right check method, and applies the bump.

**Important:** Always update version + hash atomically per package. Do NOT batch-unrelated changes into one commit. Prefer one commit per package after verifying the build.

## Step 1: Discover packages and extract metadata

Find all leaf `package.nix` files, then classify each one as a root (defines its own version) or a child (overrides a parent, same version - skip it).

```bash
find pkgs/by-name -name 'package.nix' | sort
```

For each file, extract:

```bash
# Version
grep -Po 'version\s*=\s*"\K[^"]+' <file> | head -1

# Is it a child override? If yes, skip it
grep -q '\.override' <file> && echo "CHILD" || echo "ROOT"

# For GitHub-sourced packages:
grep -Po 'owner\s*=\s*"\K[^"]+' <file>
grep -Po 'repo\s*=\s*"\K[^"]+' <file>

# For URL-sourced packages (fetchurl, AppImage, tarball, GCS):
grep -Po 'url\s*=\s*"\K[^"]+' <file> | head -1
```

Special case: **zabbix74** - the version lives in `versions.nix`, not `package.nix`. Check `pkgs/by-name/za/zabbix74/versions.nix` instead. `package.nix` is an assembly file that uses `zabbixFor "v74"`.

## Step 2: Classify and check for latest version

For each **root** package, pick based on the source fields found:

| If source has... | Check method |
|------------------|--------------|
| `owner` + `repo` (fetchFromGitHub) | `gh api repos/<owner>/<repo>/releases/latest --jq '.tag_name \| ltrimstr("v")'` |
| `url` containing `AppImage` | Read `version` from the electron-updater feed next to the AppImage - see *AppImage: the `latest-linux.yml` feed* below. `web_search` only as fallback. |
| `url` containing `tar.gz` (e.g. zabbix CDN) | `web_search` or check the source download page |
| `url` containing `storage.googleapis.com/claude-code` | Use `web_search` to find latest, or try `npm view @anthropic-ai/claude-code version` |
| `override` or `callPackage ../xxx` (child) | skip - version comes from parent |

### AppImage: the `latest-linux.yml` feed

Every AppImage in this set is an Electron app packaged with electron-builder, and
electron-builder publishes its auto-update feed `latest-linux.yml` **in the same
directory as the AppImage itself**. Strip the file name off the pinned `url`,
append `latest-linux.yml`, and read the `version` key:

```bash
curl -sSf "$(dirname "<pinned-url>")/latest-linux.yml" | grep -Po '^version:\s*\K\S+'
```

The feed also carries `path:` (the artefact file name, which must match the URL
pattern the expression builds) and `sha512:` for that artefact - a second way to
confirm the URL pattern still resolves to the published build.

The three feeds in this package set, verified 2026-09-13 (HTTP 200, no account):

| Package | Feed URL |
|---|---|
| `ray` | `https://ray-app.s3.eu-west-1.amazonaws.com/ray-app-updates-v3/stable/latest-linux.yml` |
| `tinkerwell` | `https://download.tinkerwell.app/tinkerwell/latest-linux.yml` |
| `fontbase` | `https://releases.fontba.se/linux/latest-linux.yml` |

**A 403 on a bucket listing is not a reason to skip a package.** Listing is
disabled on almost every S3 bucket by design, and a 404 on a guessed newer
version URL only says that guess was wrong. Neither tells you anything about the
latest version, and neither is needed: the feed is a single fixed URL and
requires no listing. Only report `SKIPPED` after the feed URL itself has failed.

Fall back to `web_search` only for an AppImage that genuinely has no such feed.

`vital` is the one genuine `SKIPPED` here: its download sits behind an account
login, so there is no unauthenticated feed to read.

## Step 3: Bump each package that has an update

For each package where `latest > current`, bump version and hash. The method depends on the source type.

### GitHub-sourced (fetchFromGitHub)

```bash
# 1. Get new source hash
HASH=$(nix run nixpkgs#nurl -- https://github.com/<owner>/<repo> v<new-version>)

# 2. Update version and hash in package.nix
#    Replace the version string and the hash value.

# 3. Build once to get the real vendorHash / npmDepsHash from the mismatch error
nix build .#<pname> 2>&1 | grep -oP 'got:\s+\K\S+'

# 4. Update vendorHash / npmDepsHash in package.nix
```

### Tarball-sourced (fetchurl, including zabbix)

```bash
# 1. Construct the new URL by replacing the version in the old URL
# 2. Get the new hash
HASH=$(nix store prefetch-file "<new-url>")

# 3. Update version and hash in versions.nix (zabbix) or package.nix
```

### AppImage

```bash
# 1. Construct the new URL by replacing the version in the old URL
# 2. Get the new hash
HASH=$(nix store prefetch-file "<new-url>")

# 3. Update version and hash in package.nix
```

### Prebuilt binary from URL (claude-code, etc.)

```bash
# 1. Construct the new URL by replacing the version in the old URL
# 2. Get the new hash
HASH=$(nix store prefetch-file "<new-url>")

# 3. Update version and hash in package.nix
```

## Step 4: Verify the build

After all bumps are applied, run the full check:

```bash
nix flake check
```

If any package fails, diagnose and fix before committing.

## Step 5: Report

Present a summary table of what was bumped:

```
| Package          | Old      | New      | Status  |
|------------------|----------|----------|---------|
| netbird          | 0.73.2   | 0.74.0   | BUMPED  |
| netbird-dashboard| 2.39.0   | 2.39.0   | current |
| zabbix74         | 7.4.11   | 7.4.12   | BUMPED  |
| fontbase         | 2026.5.17| 2026.5.17| current |
| ray              | 3.2.11   | 3.2.11   | current |
| vital            | 1.6.4    | ?        | SKIPPED |
```

- `BUMPED` = updated to newer version
- `current` = already on latest
- `SKIPPED` = could not determine latest version. State the URL that was tried
  and what it returned. `ray`, `tinkerwell` and `fontbase` are **not** skippable
  - they have feeds (see Step 2).

## Edge cases

- **Child packages** (override, callPackage parent): never bump directly. The parent bump updates them all.
- **buildNpmPackage / buildGoModule**: the source `hash` from `nurl` is separate from `vendorHash` / `npmDepsHash` / `vendorHash`. Update `version` and source `hash` first, then build and capture the real dep-hash from the mismatch error.
- **zabbix74**: version + hash in `versions.nix`, but the assembly is in `package.nix`. Only touch `versions.nix`.
- **Multiple packages with the same update**: bump each independently, verify each builds, then commit together or separately as makes sense.
