{
  lib,
  fetchurl,
  stdenvNoCC,
  buildFHSEnv,
}:
let
  version = "2.1.186";
  gcs = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases";
  src = fetchurl {
    url = "${gcs}/${version}/linux-x64/claude";
    hash = "sha256-am1dI0hll8kxOJQcm2jKoPvNLc7b9J4pqcjYPjocsyk=";
    name = "claude-${version}";
  };
  unwrapped = stdenvNoCC.mkDerivation {
    pname = "claude-code-unwrapped";
    inherit version;
    dontUnpack = true;
    installPhase = "install -Dm755 ${src} $out/bin/claude";
  };
in
buildFHSEnv {
  name = "claude";
  inherit version;
  targetPkgs = _: [ unwrapped ];
  runScript = "claude";
  meta = {
    mainProgram = "claude";
    description = "Anthropic's CLI for Claude - agentic coding assistant";
    homepage = "https://claude.ai/code";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
}
