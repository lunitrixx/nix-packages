---
name: version-check
description: Check all packages in this Nix package set for newer upstream versions. Auto-discovers every package under pkgs/by-name/ - no manual list needed. Use when the user asks about updates.
---

# Version Check

Auto-discover every package under `pkgs/by-name/` and check each one for a newer upstream version. No hardcoded package list - the skill reads the filesystem, extracts version + source pattern, picks the right check method, and reports.

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
grep -Po 'url\s*=\s*"\K[^"]+' <file>
```

Special case: **zabbix74** - the version lives in `versions.nix`, not `package.nix`. Check `pkgs/by-name/za/zabbix74/versions.nix` instead. `package.nix` is an assembly file that uses `zabbixFor "v74"`.

## Step 2: Classify and pick a check method

For each **root** package, pick based on the source fields found:

| If source has... | Check method |
|------------------|--------------|
| `owner` + `repo` (fetchFromGitHub) | `gh api repos/<owner>/<repo>/releases/latest --jq '.tag_name \| ltrimstr("v")'` |
| `url` containing `AppImage` | `web_search({ query: "<pname> latest version" })` |
| `url` containing `tar.gz` (e.g. zabbix CDN) | `web_search` or check the source download page |
| `url` containing `storage.googleapis.com/claude-code` | Use `web_search` to find latest, or try `npm view @anthropic-ai/claude-code version` |
| `override` or `callPackage ../xxx` (child) | skip - version comes from parent |

## Step 3: Run all checks

**GitHub repos** - batch all `gh api` calls in parallel. Construct each command from the `owner`/`repo` extracted in Step 1:

```bash
# Example for each GitHub-sourced package found:
gh api repos/<owner>/<repo>/releases/latest --jq '.tag_name | ltrimstr("v")' &
# ... repeat for each ...
wait
```

**Everything else** - batch into a single `web_search` with one query per package:

```
web_search({ queries: [
  "<pname1> latest version release",
  "<pname2> latest version release",
  ...
]})
```

For claude-code specifically, also try the fast path first (may or may not work):
```bash
npm view @anthropic-ai/claude-code version 2>/dev/null
```

## Step 4: Compare and report

Normalise versions: strip leading `v`, trim whitespace. Compare current vs latest. Present a summary table:

```
| Package          | Current   | Latest    | Status  |
|------------------|-----------|-----------|---------|
| netbird          | 0.73.2    | 0.74.0    | UPDATE  |
| netbird-dashboard| 2.39.0    | 2.39.0    | current |
| pi-coding-agent  | 0.79.9    | 0.80.0    | UPDATE  |
| zabbix74         | 7.4.11    | 7.4.12    | UPDATE  |
| claude-code      | 2.1.185   | 2.1.190   | UPDATE  |
| fontbase         | 2026.5.17 | 2026.5.17 | current |
| ray              | 3.2.7     | ?         | UNKNOWN |
| tinkerwell       | 5.16.0    | 5.18.0    | UPDATE  |
```

- `UPDATE` = newer version exists upstream
- `current` = already on latest
- `UNKNOWN` = could not determine (web_search failed or no results)

Do NOT modify any files - this is read-only.
