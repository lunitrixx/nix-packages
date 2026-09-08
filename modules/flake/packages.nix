# Just our own packages - for `nix flake show` and as build/check targets.
#
# A package may be a single derivation (e.g. netbird) or an attrset of
# derivations (e.g. zabbix74, which recurseIntoAttrs into .server / .web /
# ...). The flake's packages/checks must be flat derivations, so flatten
# attrset packages into "<name>-<sub>" entries. The overlay still exposes
# the original shape (pkgs.zabbix74.server stays an attrset access).
{
  inputs,
  lib,
  ...
}:
let
  byNameDir = ../../pkgs/by-name;
  overlay = import ../../pkgs/by-name-overlay.nix byNameDir;

  # Names of every package defined under pkgs/by-name (flattened over shards).
  packageNames = lib.concatMap (
    shard: builtins.attrNames (builtins.readDir (byNameDir + "/${shard}"))
  ) (builtins.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir byNameDir)));
in
{
  perSystem =
    { system, ... }:
    let
      pkgs =
        (import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
        }).extend
          overlay;

      # Drop anything not available on this system's platform, so that
      # x86_64-linux-only packages (claude-code/ray/tinkerwell/fontbase)
      # don't break aarch64 checks.
      flatten =
        name: v:
        if lib.isDerivation v then
          (
            if lib.meta.availableOn pkgs.stdenv.hostPlatform v && !(v.meta.broken or false) then
              { ${name} = v; }
            else
              { }
          )
        else
          lib.mapAttrs' (sub: drv: lib.nameValuePair "${name}-${sub}" drv) (
            lib.filterAttrs (
              _: drv:
              lib.isDerivation drv
              && lib.meta.availableOn pkgs.stdenv.hostPlatform drv
              && !(drv.meta.broken or false)
            ) v
          );
    in
    {
      packages = lib.foldl' (acc: name: acc // flatten name pkgs.${name}) { } packageNames;
    };
}
