# Vendored from numtide/llm-agents.nix (packages/herdr/package.nix).
# Deltas vs upstream:
#   - Dropped `flake` argument (specific to llm-agents.nix); maintainer metadata removed.
#   - Dropped `versionCheckHomeHook` (not in nixpkgs).
#   - Dropped Darwin binary path (this repo only builds for Linux).
#   - License updated: upstream relicensed to Apache-2.0 as of v0.8.0.
{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  callPackage,
  zig_0_15,
  installShellFiles,
  versionCheckHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData)
    version
    hash
    cargoHash
    ;

  # build.rs shells out to `zig build` to compile vendored libghostty-vt.
  # We vendor the zon2nix-generated build.zig.zon.nix in-tree (kept in sync
  # with upstream by checking against llm-agents.nix) and import that instead
  # of reading it from src, which would require import-from-derivation
  # (disabled repo-wide).
  zigDeps = callPackage ./build.zig.zon.nix {
    name = "herdr-libghostty-vt-zig-deps";
    inherit zig_0_15;
  };
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "herdr";
  inherit version;

  src = fetchFromGitHub {
    owner = "ogulcancelik";
    repo = "herdr";
    tag = "v${version}";
    inherit hash;
  };

  inherit cargoHash;

  nativeBuildInputs = [
    zig_0_15
    installShellFiles
  ];

  # zig's setup hook overrides buildPhase/installPhase with `zig build`,
  # but here zig is only invoked indirectly from build.rs.  Keep cargo's
  # phases.
  dontUseZigBuild = true;
  dontUseZigInstall = true;
  dontUseZigCheck = true;
  dontUseZigConfigure = true;

  # build.rs passes an explicit -Dtarget that zig treats as a cross target,
  # so build-time helper executables (uucode_build_tables) get linked against
  # the FHS dynamic loader path which doesn't exist in the sandbox.  Drop the
  # flag so zig uses the native target and picks up the wrapped libc paths,
  # but keep Zig's CPU baseline explicit to avoid build-host CPU features
  # leaking into the output.
  postPatch = ''
    substituteInPlace build.rs \
      --replace-fail '.arg("build")' '.arg("build")
          .arg("-Dcpu=baseline")' \
      --replace-fail '.arg(format!("-Dtarget={zig_target}"))' ""
  '';

  preBuild = ''
    export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"
    export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-local-cache"
    mkdir -p "$ZIG_GLOBAL_CACHE_DIR" "$ZIG_LOCAL_CACHE_DIR"
    ln -s ${zigDeps} "$ZIG_GLOBAL_CACHE_DIR/p"
  '';

  # Tests spawn PTYs / interact with the terminal and don't work in the
  # sandbox.
  doCheck = false;

  postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    installShellCompletion --cmd herdr \
      --bash <("$out/bin/herdr" completion bash) \
      --fish <("$out/bin/herdr" completion fish) \
      --zsh <("$out/bin/herdr" completion zsh)
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  meta = {
    description = "Terminal workspace manager for AI coding agents";
    homepage = "https://herdr.dev";
    changelog = "https://github.com/herdrdev/herdr/releases/tag/v${version}";
    license = lib.licenses.asl20;
    mainProgram = "herdr";
    platforms = lib.platforms.linux;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
  };
})
