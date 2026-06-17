{
  description = "Custom Nix package set, modelled on nixpkgs - an overlay that adds our packages on top of nixpkgs (anything we don't define falls through to nixpkgs)";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = lib.genAttrs systems;

      # The pkgs/by-name -> overlay mechanism, mirrored from nixpkgs.
      byNameDir = ./pkgs/by-name;
      overlay = import ./pkgs/by-name-overlay.nix byNameDir;

      # Names of every package defined under pkgs/by-name (flattened over shards).
      packageNames = lib.concatMap (
        shard: builtins.attrNames (builtins.readDir (byNameDir + "/${shard}"))
      ) (builtins.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir byNameDir)));

      # nixpkgs with our overlay applied: our packages + everything from nixpkgs.
      pkgsFor = system: nixpkgs.legacyPackages.${system}.extend overlay;
    in
    {
      # Apply in a consumer: nixpkgs.overlays = [ inputs.nix-packages.overlays.default ];
      # -> pkgs.netbird is ours; pkgs.<anything we don't define> stays nixpkgs'.
      overlays.default = overlay;

      # The full package set (ours + nixpkgs fall-through). Use it like nixpkgs:
      #   nix build  nix-packages#netbird       (ours)
      #   nix build  nix-packages#hello         (from nixpkgs)
      legacyPackages = forAllSystems pkgsFor;

      # Just our own packages - for `nix flake show` and as build/check targets.
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        lib.genAttrs packageNames (name: pkgs.${name})
      );

      # `nix flake check` builds every package we define.
      checks = forAllSystems (system: self.packages.${system});

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
