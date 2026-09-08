# The estate-wide flake convention is checked, not just written down.
#
# This repository has no class trees (no modules/nixos, modules/homeManager,
# ...): only modules/flake/. The enforceable rule here is that no .nix file may
# sit under modules/ outside the known root (modules/flake/). A loose file at
# the top of modules/ is the failure mode the convention exists to prevent -
# the path must say what a file is (flake-level or <class>).
#
# When this repository ever gains a class tree, add it to knownRoots and extend
# this check with the duplicate-basename guard from the convention document
# (sections 4.1/4.3).
#
# The file list is built with builtins.readDir (recursive), matching
# import-tree's default filter: skip paths containing "/_", keep only .nix.
{
  lib,
  pkgs,
  ...
}:
let
  modulesDir = ../.; # modules/
  knownRoots = [ "flake" ];

  # Recursively collect all .nix files under a directory, skipping paths
  # that contain "/_" (same rule import-tree applies).
  listNix =
    dir:
    let
      entries = builtins.readDir dir;
    in
    builtins.concatMap (
      name:
      let
        entry = entries.${name};
        p = dir + "/${name}";
        pstr = toString p;
      in
      if entries."${name}" == "directory" then
        if lib.strings.hasInfix "/_" pstr then [ ] else listNix p
      else if lib.strings.hasSuffix ".nix" name && !lib.strings.hasInfix "/_" pstr then
        [ p ]
      else
        [ ]
    ) (builtins.attrNames entries);

  allFiles = listNix modulesDir;

  # A file is "loose" if it is not under any known root.
  looseFiles = lib.filter (
    f:
    lib.all (root: !lib.strings.hasPrefix (toString (modulesDir + "/${root}/")) (toString f)) knownRoots
  ) allFiles;
in
{
  perSystem =
    { pkgs, ... }:
    {
      checks.module-name-uniqueness =
        if looseFiles == [ ] then
          pkgs.runCommand "check-module-convention" { } "touch $out"
        else
          throw "convention: unexpected .nix files under modules/ outside the known roots ${
            lib.concatMapStringsSep ", " (r: "<modules/${r}/>") knownRoots
          }: ${lib.concatMapStringsSep ", " toString looseFiles}";
    };
}
