# AGENTS.md

Instructions for AI coding agents working on this repository.

`CLAUDE.md` is a thin shim that points here; this file is the canonical,
tool-agnostic source of truth.

## What This Is

A custom Nix package set, modelled on nixpkgs. It is an **overlay on top of
nixpkgs**: consumers get our packages where we define them, and anything we
don't define falls through to the original nixpkgs. Two kinds of packages live
here:

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
└── by-name/ne/
    ├── netbird/package.nix          # one source tree → any component via componentName
    ├── netbird-management/package.nix  # { netbird }: netbird.override { componentName = …; }
    ├── netbird-signal/package.nix      #   one tiny file per component, exactly like nixpkgs
    ├── netbird-relay/package.nix
    ├── netbird-proxy/package.nix     #   reverse proxy (not in nixpkgs)
    ├── netbird-ui/package.nix
    ├── netbird-upload/package.nix
    └── netbird-dashboard/package.nix # buildNpmPackage from netbirdio/dashboard
```

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
  `nix flake check` builds every one of them.

## Conventions

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

## Pull Requests

- **NEVER open a PR without asking first.** Creating branches and commits is
  fine; only open a PR when explicitly asked.
- **NEVER merge a PR without explicit confirmation.** A green `nix flake check`
  is not the same as being tested by a consumer on a real target.
