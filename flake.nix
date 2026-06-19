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
      # allowUnfree is set so this repo's own build targets (legacyPackages/
      # packages/checks) can build unfree packages like claude-code/ray/
      # tinkerwell/fontbase. The exposed overlays.default is unaffected -
      # consumers set their own allowUnfree.
      pkgsFor =
        system:
        (import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        }).extend
          overlay;
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
      # A package may be a single derivation (e.g. netbird) or an attrset of
      # derivations (e.g. zabbix74, which recurseIntoAttrs into .server / .web /
      # ...). The flake's packages/checks must be flat derivations, so flatten
      # attrset packages into "<name>-<sub>" entries. The overlay still exposes
      # the original shape (pkgs.zabbix74.server stays an attrset access).
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          # Drop anything not available on this system's platform, so that
          # x86_64-linux-only packages (claude-code/ray/tinkerwell/fontbase)
          # don't break aarch64 checks.
          flatten =
            name: v:
            if lib.isDerivation v then
              (if lib.meta.availableOn pkgs.stdenv.hostPlatform v then { ${name} = v; } else { })
            else
              lib.mapAttrs' (sub: drv: lib.nameValuePair "${name}-${sub}" drv) (
                lib.filterAttrs (
                  _: drv: lib.isDerivation drv && lib.meta.availableOn pkgs.stdenv.hostPlatform drv
                ) v
              );
        in
        lib.foldl' (acc: name: acc // flatten name pkgs.${name}) { } packageNames
      );

      # `nix flake check` builds every package we define.
      checks = forAllSystems (system: self.packages.${system});

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
