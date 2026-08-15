{
  lib,
  fetchurl,
  stdenvNoCC,
  buildFHSEnv,
}:
let
  version = "2.1.233";
  src = fetchurl {
    url = "https://github.com/anthropics/claude-code/releases/download/v${version}/claude-linux-x64.tar.gz";
    hash = "sha256-I+7EngRTo6e52TMijLCWOfwLzZYgOSWNjkzecvpbh0E=";
  };
  unwrapped = stdenvNoCC.mkDerivation {
    pname = "claude-code-unwrapped";
    inherit version src;
    sourceRoot = ".";
    installPhase = "install -Dm755 claude $out/bin/claude";
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
