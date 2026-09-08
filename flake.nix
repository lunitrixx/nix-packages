{
  description = "Custom Nix package set, modelled on nixpkgs - an overlay that adds our packages on top of nixpkgs (anything we don't define falls through to nixpkgs)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
  };

  outputs =
    inputs:
    let
      it = inputs.import-tree;
    in
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ (it ./modules/flake) ];
    };
}
