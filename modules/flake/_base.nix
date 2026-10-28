# The base package set the flake's own outputs build against: the locked
# nixpkgs input with our overlay on top and allowUnfree, so the flake's
# packages / legacyPackages / checks can build the unfree entries (ray,
# tinkerwell, fontbase). The exposed overlays.default is a plain overlay and
# is unaffected - consumers compose their own base and set their own
# allowUnfree.
#
# The leading underscore keeps import-tree (and the module-convention check,
# which mirrors its filter) from loading this as a flake-parts module: it is
# a helper function, not a module.
{
  inputs,
  system,
}:
let
  overlay = import ../../pkgs/by-name-overlay.nix ../../pkgs/by-name;
in
(import inputs.nixpkgs {
  inherit system;
  config.allowUnfree = true;
}).extend
  overlay
