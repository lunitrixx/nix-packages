# Turns the pkgs/mcp directory into the package set pkgs.mcp: every
# pkgs/mcp/<name>/package.nix becomes pkgs.mcp.<name>, loaded with
# `final.callPackage` like the by-name packages.
#
# MCP servers keep their upstream names. The namespace keeps them from
# shadowing a nixpkgs package of the same name (nixpkgs' `forgejo-mcp` is an
# unrelated Go server).
#
# Type: Path -> Overlay
baseDirectory: final: prev:
let
  inherit (prev.lib) filterAttrs mapAttrs recurseIntoAttrs;
in
{
  mcp = recurseIntoAttrs (
    mapAttrs (name: _: final.callPackage (baseDirectory + "/${name}/package.nix") { }) (
      filterAttrs (_: type: type == "directory") (builtins.readDir baseDirectory)
    )
  );
}
