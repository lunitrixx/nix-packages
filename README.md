# nix-packages

A custom Nix package set, modelled on nixpkgs. It is an **overlay on top of
nixpkgs**: consumers get our packages where we define them, and everything else
falls through to the original nixpkgs. Two kinds of packages live here:

- packages **pinned ahead of the nixpkgs channel** (vendored from nixpkgs and
  version-pinned, so there's no wait for a channel bump), and
- packages **nixpkgs doesn't ship at all**.

First resident: **NetBird**. nixpkgs lagged behind upstream releases, holding
back both the VPN client and the self-hosted server components - and the reverse
proxy isn't in nixpkgs at all. All of it is built here, version-matched.

## How it works (the nixpkgs `by-name` mechanism)

```
pkgs/
├── by-name-overlay.nix             # mirrors nixpkgs' pkgs/top-level/by-name-overlay.nix
└── by-name/ne/
    ├── netbird/package.nix          # one source tree -> any component via componentName
    ├── netbird-management/package.nix  # { netbird }: netbird.override { componentName = …; }
    ├── netbird-signal/package.nix
    ├── netbird-relay/package.nix
    ├── netbird-proxy/package.nix     # reverse proxy (not in nixpkgs)
    ├── netbird-ui/package.nix
    ├── netbird-upload/package.nix
    └── netbird-dashboard/package.nix
```

`by-name-overlay.nix` reads every `pkgs/by-name/<shard>/<name>/package.nix` and
loads it with `final.callPackage` - exactly like nixpkgs. So a `package.nix` is
a normal nixpkgs-style file (its `{ stdenv, lib, … }` arguments resolve from the
overlaid set), and sibling references like `{ netbird }` resolve to *our*
netbird, keeping every component version-matched. Because it's a plain overlay,
anything we don't define stays as nixpkgs provides it.

| Attribute | Binary | Role |
|-----------|--------|------|
| `netbird` | `netbird` | VPN client / agent |
| `netbird-management` | `netbird-mgmt` | control plane + API |
| `netbird-signal` | `netbird-signal` | peer signalling |
| `netbird-relay` | `netbird-relay` | rendezvous relay |
| `netbird-proxy` | `netbird-proxy` | reverse proxy (not in nixpkgs) |
| `netbird-ui` | `netbird-ui` | desktop tray GUI |
| `netbird-upload` | `netbird-upload` | debug-bundle upload-server |
| `netbird-dashboard` | static SPA | web console |

## Packages

Everything this overlay defines today; anything else stays nixpkgs' (see
`pkgs/by-name/`, auto-discovered - a new `package.nix` is a new package):

| Package | What it is |
|---------|------------|
| `netbird`, `netbird-management`, … (8) | NetBird VPN, one source tree, version-matched - see the table above |
| `zabbix74` | Zabbix 7.4, an attrset of derivations (`.server-pgsql`, `.web`, `.agent2`, …); version and hash pinned in `versions.nix` |
| `crowdsec-openresty-bouncer` | CrowdSec's Lua remediation component for OpenResty (not in nixpkgs); ships Lua + config templates, no binary |
| `php85` | PHP 8.5 pinned ahead of the channel, built with nixpkgs' `generic.nix` (see below) |
| `wails3` | Wails v3 CLI, a Go module netbird-ui builds against (not in nixos-26.05) |
| `win-iso-remaster` | Tool that remasters a Windows 11 ISO (see below) |
| `ray`, `tinkerwell`, `fontbase` | Unfree AppImage desktop apps (x86_64-linux) |
| `tabby-terminal` | Tabby terminal, built from the .deb (x86_64-linux); deliberately not `tabby`, which is TabbyML in nixpkgs |

## Usage

Add it as a flake input and apply the overlay:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nix-packages = {
      url = "github:lunitrixx/nix-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

Then pull the overlay in:

```nix
nixpkgs.overlays = [ inputs.nix-packages.overlays.default ];
# pkgs.netbird is ours; pkgs.<anything we don't define> stays nixpkgs'
```

Or use the full set directly (ours + nixpkgs fall-through):

```sh
nix build nix-packages#netbird   # ours
nix build nix-packages#hello     # from nixpkgs
```

## Build / test

```sh
nix build .#netbird .#netbird-management .#netbird-dashboard
nix flake check   # builds every package we define
nix fmt
```

## Bump a version

`netbird` (`pkgs/by-name/ne/netbird/package.nix`) and `netbird-dashboard`
(`pkgs/by-name/ne/netbird-dashboard/package.nix`):

1. set `version`
2. `nurl https://github.com/netbirdio/<repo> v<version>` -> new `hash`
3. build once; copy the real `vendorHash` / `npmDepsHash` from the mismatch error

One netbird bump updates the client and every server component at once.

## PHP 8.5

`php85` (`pkgs/by-name/ph/php85/package.nix`) is pinned ahead of the channel at
8.5.12. It calls nixpkgs' `generic.nix` with our version, hash and `patches`,
so `php85.withExtensions` and the `php85Packages` set work as in nixpkgs.

Add an upstream security fix as one entry in `patches`:

```nix
patches = [
  (fetchpatch {
    url = "https://github.com/php/php-src/commit/<sha>.patch";
    hash = lib.fakeHash; # build once, then copy the `got:` hash from the error
  })
];
```

`lib.fakeHash` needs `lib` in the argument list of `package.nix`. Copy the
`got:` hash from the mismatch error into `hash`.

Take the next release by setting `version` and `hash`. The hash is the SRI
`sha256` of `https://www.php.net/distributions/php-<version>.tar.bz2` (nixpkgs'
`generic.nix` fetches the bz2, not the xz), which `nix store prefetch-file --json
<url>` prints. It must match the `sha256` in the release feed
`https://www.php.net/releases/index.php?json&version=8.5`.
The `smoke-php85` assertion derives the version from the package, so the
smoke test needs no change.

## Windows 11 ISO remaster

`win-iso-remaster` (`pkgs/by-name/wi/win-iso-remaster`) writes a copy of a
Windows 11 ISO that boots UEFI without the "Press any key to boot from CD or
DVD" prompt and installs Pro without an edition list (`sources/ei.cfg`). The
source ISO is never modified; the output lands next to it as
`*_pro_noprompt.iso`.

```sh
win-iso-remaster Windows11.iso                    # rebuild with ei.cfg
win-iso-remaster --noprompt-only Windows11.iso    # patch only the UEFI boot image
```

The rebuild follows the dockur/windows recipe and writes UDF, which the 8 GB
`install.wim` needs. It needs free space of twice the ISO size. `--pid KEY`
writes `sources/PID.txt`; `--no-bios-prompt` removes `boot/bootfix.bin`, which
is not verified on hardware.

## License

The package descriptions (Nix expressions) are [MIT](./LICENSE). This does not
apply to the packaged software, which carries its own upstream licenses.
