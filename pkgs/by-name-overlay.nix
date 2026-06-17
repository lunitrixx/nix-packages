# Turns the pkgs/by-name directory into an overlay that adds all defined
# packages. This is the same mechanism nixpkgs uses in
# pkgs/top-level/by-name-overlay.nix.
#
# Each pkgs/by-name/<shard>/<name>/package.nix is loaded with `final.callPackage`,
# so its arguments (stdenv, lib, buildGoModule, … as well as sibling packages
# like `netbird`) resolve from the final, overlaid package set. Because it is a
# plain overlay, anything we do not define falls through to the package set it is
# applied on - i.e. the original nixpkgs.
#
# nixpkgs names the overlay arguments `self`/`super` internally, but since we
# expose this as a flake `overlays.default`, `nix flake check` requires them to
# be named `final`/`prev` - same mechanism, mandated names.
#
# Type: Path -> Overlay
baseDirectory:
final: prev:
let
  inherit (prev.lib.attrsets)
    mapAttrs
    mapAttrsToList
    mergeAttrsList
    ;

  # Package files for a single shard: { <name> = …/<shard>/<name>/package.nix; }
  namesForShard =
    shard: type:
    if type != "directory" then
      { } # ignore non-directories (e.g. a README.md)
    else
      mapAttrs (name: _: baseDirectory + "/${shard}/${name}/package.nix") (
        builtins.readDir (baseDirectory + "/${shard}")
      );

  # name -> package file, flattened across all shards
  packageFiles = mergeAttrsList (mapAttrsToList namesForShard (builtins.readDir baseDirectory));
in
mapAttrs (_name: file: final.callPackage file { }) packageFiles
