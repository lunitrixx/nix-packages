{
  lib,
  stdenvNoCC,
  fetchurl,
  glibc,
  patchelf,
}:
stdenvNoCC.mkDerivation rec {
  pname = "omp";
  version = "16.1.18";

  src = fetchurl {
    url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-linux-x64";
    hash = "sha256-LFJSfYbCfR4R1JO3RMVGdJQsvxbhEdSSBnD2orZZCi4=";
  };

  dontUnpack = true;

  # Only patch the ELF interpreter so the binary runs on NixOS where
  # /lib64/ld-linux-x86-64.so.2 does not exist.  Do NOT use autoPatchelfHook
  # — any broader ELF rewriting (RPATH adjustment, etc.) breaks the Bun
  # compiled binary's argv[0] self-detection, causing it to fall back to the
  # stock bun CLI instead of the omp agent.
  nativeBuildInputs = [
    glibc
    patchelf
  ];
  installPhase = ''
    runHook preInstall
    install -Dm755 ${src} $out/bin/omp
    patchelf --set-interpreter ${glibc}/lib/ld-linux-x86-64.so.2 $out/bin/omp
    runHook postInstall
  '';

  meta = {
    mainProgram = "omp";
    description = "Coding agent CLI - fork of Pi with IDE wired in, 40+ providers, 32 built-in tools, LSP/DAP support";
    longDescription = ''
      oh-my-pi (omp) is a coding agent with the IDE wired in. A fork of Pi by
      Mario Zechner, it adds code execution with tool-calling, LSP wired into
      every write, a real debugger driver, time-traveling stream rules,
      first-class subagents, and a reviewer model watching every turn.

      40+ providers, 32 built-in tools, 14 LSP ops, 28 DAP ops.
    '';
    homepage = "https://omp.sh";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
}
