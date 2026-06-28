# AGENTS.md

Canonical source of truth for AI coding agents working in this repository. This
file is the single authority for project rules, workflow, conventions, and
skills policy. Pi reads it natively; Claude Code and Codex-compatible agents
read it through their respective adapters.

> Keep this file human-authored and concise. It is read by multiple agents
> (Pi, Claude Code, Codex, and any tool that can be pointed at it).

## Architecture

This repo is **Pi-native**. The canonical locations are:

```
AGENTS.md             # canonical project instructions for Pi and compatible agents
CLAUDE.md             # Claude Code adapter, points back to AGENTS.md and .pi/rules/
.pi/settings.json     # Pi project settings
.pi/rules/            # Universal rules (workflow, PRs, writing style) loaded by agents
.pi/skills/           # canonical Pi-native Agent Skills
.claude/skills -> ../.pi/skills  # symlink to canonical skills
.claude/rules -> ../.pi/rules    # symlink to canonical rules
.mcp.json             # shared MCP server config where supported
```

- **Instructions:** `AGENTS.md` is the single source of truth. `CLAUDE.md` is a
  thin adapter that delegates to `AGENTS.md`.
- **Skills:** Pi-native skills live canonically in `.pi/skills/`. Pi auto-discovers
  this directory. External harness skills (`~/.claude/skills`, `~/.codex/skills`)
  are loaded via `.pi/settings.json`. `.claude/skills/` and `.claude/rules/` are
  git-tracked symlinks to the canonical directories - no duplication.
- **MCP servers:** Shared in `.mcp.json`, read by Pi and Claude Code.

## Project

**nix-packages** - A custom Nix package set, modelled on nixpkgs. It is an
**overlay on top of nixpkgs**: consumers get our packages where we define them,
and anything we don't define falls through to the original nixpkgs.

**Tech stack:** Nix (Flake), nixfmt

Two kinds of packages live here:

- packages **pinned ahead of the nixpkgs channel** (vendored from nixpkgs and
  version-pinned, so there's no wait for a channel bump), and
- packages **nixpkgs doesn't ship at all**.

First resident: **NetBird** (client/agent, the self-hosted server components,
and the reverse proxy which isn't in nixpkgs).

## Layout

```
flake.nix                            # overlays.default, legacyPackages, packages, checks, formatter
pkgs/
├── by-name-overlay.nix              # mirrors nixpkgs' pkgs/top-level/by-name-overlay.nix
├── by-name/ne/
│   ├── netbird/package.nix          # one source tree → any component via componentName
│   ├── netbird-management/package.nix  # { netbird }: netbird.override { componentName = …; }
│   ├── netbird-signal/package.nix      #   one tiny file per component, exactly like nixpkgs
│   ├── netbird-relay/package.nix
│   ├── netbird-proxy/package.nix     #   reverse proxy (not in nixpkgs)
│   ├── netbird-ui/package.nix
│   ├── netbird-upload/package.nix
│   └── netbird-dashboard/package.nix # buildNpmPackage from netbirdio/dashboard
├── by-name/za/zabbix74/
│   ├── package.nix                  # assembly: recurseIntoAttrs (zabbixFor "v74") → an attrset
│   ├── versions.nix                 # the single version + hash pin (v74)
│   ├── server.nix agent.nix agent2.nix web.nix proxy.nix  # vendored verbatim from nixpkgs
│   └── …                            # `pkgs.zabbix74.{server-pgsql,web,agent2,…}`
├── by-name/cl/claude-code/package.nix   # prebuilt binary in buildFHSEnv (unfree, x86_64-linux)
├── by-name/pi/pi-coding-agent/package.nix  # buildNpmPackage from earendil-works/pi
├── by-name/ra/ray/package.nix       # AppImage, Spatie debug app (unfree, x86_64-linux)
├── by-name/ti/tinkerwell/package.nix    # AppImage, PHP tinker tool (unfree, x86_64-linux)
└── by-name/fo/fontbase/package.nix  # AppImage, font manager (unfree, x86_64-linux)
```

Unfree and platform-restricted packages: the flake's own `packages`/`checks`
build with `config.allowUnfree = true` (consumers set their own), and `packages`
drops anything not `lib.meta.availableOn` the current system, so the
`x86_64-linux`-only entries above don't break `aarch64-linux` checks.

## How it works

`pkgs/by-name-overlay.nix` is the same mechanism nixpkgs uses
(`pkgs/top-level/by-name-overlay.nix`): it reads every
`pkgs/by-name/<shard>/<name>/package.nix` and loads it with `final.callPackage`.
So each `package.nix` is a normal nixpkgs-style file (its `{ stdenv, lib, … }`
arguments resolve from the overlaid set), and sibling references like
`{ netbird }` resolve to *our* netbird. Being a plain overlay, anything we don't
define stays as nixpkgs provides it.

The flake exposes:

- `overlays.default` — apply in a consumer; `pkgs.netbird` becomes ours, the
  rest stays nixpkgs'.
- `legacyPackages.<system>` — nixpkgs with our overlay applied (ours + nixpkgs
  fall-through).
- `packages.<system>` — just our packages; also wired into `checks` so
  `nix flake check` builds every one of them. A package that is an *attrset* of
  derivations (see zabbix74 below) is flattened here into `<name>-<sub>` entries
  (e.g. `zabbix74-server-pgsql`) so `packages`/`checks` stay flat derivations;
  the overlay still exposes the original attrset shape.

## Conventions

General:

- Follow existing code conventions; check sibling files before creating anything new.
- Prefer the project's own generators/scaffolding over hand-written boilerplate.
- Run the formatter before finalizing changes: `nix fmt` (nixfmt).
- Every change must pass the checks. `nix flake check` builds every package we
  define - run it and make sure it passes.
- Do not change dependencies without approval - this includes bumping the
  `nixpkgs` base in `flake.lock` or any vendored package version.

Nix package set:

- **`pkgs/by-name/<shard>/<name>/package.nix`** — same layout nixpkgs uses
  (`<shard>` = first two letters of the name); file is named `package.nix`, not
  `default.nix`. Auto-discovered by the overlay; no central registration.
- **Vendor faithfully.** Copy a package's `package.nix` from nixpkgs as-is and
  keep deltas minimal: the pinned `version` + hashes, plus anything nixpkgs
  doesn't have. Document each delta in a comment at the top of the file.
- **Multi-component packages** (one source → many binaries, like netbird) keep a
  single parameterised parent (`componentName ? "…"`) and one tiny by-name file
  per component doing `netbird.override { componentName = …; }` — exactly like
  nixpkgs. The overlay's `final.callPackage` makes `{ netbird }` resolve to our
  package, so all components stay version-matched.
- **Attrset-valued packages** (like zabbix74) are the exception to the per-component
  rule above. zabbix74's `package.nix` reproduces nixpkgs' `zabbixFor "v74"` block
  and returns `recurseIntoAttrs (…)` — a single by-name entry whose value is an
  *attrset* of derivations (`.server-pgsql`, `.web`, `.agent2`, …). Use this shape
  (not separate by-name files per variant) **only when a consumer needs the attrset
  access** — `nix-images` wires `pkgs.zabbix74.server-pgsql` etc. directly, so the
  attrset is part of the contract. The flake's `packages`/`checks` flatten it into
  `zabbix74-<sub>` build targets; the consumer-facing `pkgs.zabbix74.<sub>` shape is
  untouched. Keep the vendored component files (`server.nix`, `web.nix`, …) verbatim
  and confine deltas to `versions.nix` + the `package.nix` assembly.
- **The exposed overlay names its arguments `final`/`prev`.** nixpkgs uses
  `self`/`super` internally, but `nix flake check` requires `final`/`prev` for a
  flake `overlays.default`. Same mechanism, mandated names.
- **Always pin a specific version + hash.** Never track a branch or `latest`.

## Adding / bumping packages

| What | How |
|------|-----|
| **New package** | Create `pkgs/by-name/<shard>/<name>/package.nix` (vendor from nixpkgs or write fresh). Auto-discovered — no wiring. |
| **Bump a version** | Edit the package's `version`, refresh the source `hash` (`nurl <url> <tag>`), then build once and copy the real `vendorHash` / `npmDepsHash` from the mismatch error. |

A bump to the netbird parent updates the client **and** every server component
at once — guaranteed version-matched.

For zabbix74, bump the single `version` + `hash` in `versions.nix` (the source is
a `fetchurl` tarball, so get the hash with
`nix store prefetch-file <url>`, not `nurl`). That re-pins every
component at once. Leave the vendored component files untouched.

## Commands

```sh
# Build / test packages (checks = all our packages)
nix build .#netbird .#netbird-management .#netbird-dashboard
nix flake check

# Get a source hash (vendorHash/npmDepsHash come from the build mismatch error)
nix run nixpkgs#nurl -- https://github.com/<owner>/<repo> v<version>

nix fmt              # format (nixfmt)
nix flake update     # update the nixpkgs base
```

## Consumers

Consume it as a flake input and apply the overlay:

```nix
inputs.nix-packages.url = "github:lunitrixx/nix-packages";
# then: nixpkgs.overlays = [ inputs.nix-packages.overlays.default ];
```

After that `pkgs.netbird`, `pkgs.netbird-management`, `pkgs.netbird-proxy`,
`pkgs.netbird-dashboard`, … are ours; everything else stays nixpkgs'. Bumping a
version here means re-locking the input downstream
(`nix flake lock --update-input nix-packages`).

## Skills

Reusable agent skills live in `.pi/skills/`. Pi auto-discovers this directory;
Claude Code accesses them through the `.claude/skills -> ../.pi/skills` symlink.

| Skill | Description |
|---|---|
| `version-check` | Check all packages for newer upstream versions. Auto-discovers every package under `pkgs/by-name/`. |


