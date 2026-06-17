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

## License

The package descriptions (Nix expressions) are [MIT](./LICENSE). This does not
apply to the packaged software, which carries its own upstream licenses.
