# The full package set (ours + nixpkgs fall-through), exposed the same way
# nixpkgs itself exposes it:
#   nix build  nix-packages#netbird       (ours)
#   nix build  nix-packages#hello         (from nixpkgs)
#
# allowUnfree is set so this repo's own build targets (legacyPackages/
# packages/checks) can build unfree packages like claude-code/ray/
# tinkerwell/fontbase. The exposed overlays.default is unaffected -
# consumers set their own allowUnfree.
{
  inputs,
  lib,
  config,
  ...
}:
let
  overlay = import ../../pkgs/by-name-overlay.nix ../../pkgs/by-name;
in
{
  flake.legacyPackages = lib.genAttrs config.systems (
    system:
    (import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
    }).extend
      overlay
  );
}
