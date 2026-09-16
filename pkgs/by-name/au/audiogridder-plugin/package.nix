# AudioGridder VST2/VST3 plugins (prebuilt x86-64 binaries in a Makeself
# self-extracting archive). Not in nixpkgs.
#
# Upstream ships a Makeself 2.4.5 installer that is extracted without
# executing the interactive shell script inside:
#   sh <installer> --noexec --keep --target <dir>
#
# The installer's own install script calls sudo and writes into $HOME; it is
# never run. Extraction yields:
#   vst/AudioGridder{,Inst,Midi}.so          - VST2 plugins
#   vst3/AudioGridder.vst3/Contents/x86_64-linux/...  - VST3 bundles
#   bin/AudioGridderPluginTray               - tray helper
#   bin/crashpad_handler                     - CRASH REPORTER ONLY (dropped)
#
# crashpad_handler is deliberately not installed: it links against
# libssl.so.1.1 / libcrypto.so.1.1 (OpenSSL 1.1, end of life) which are not
# in the nixpkgs revision this repo pins. It is a standalone crash reporter
# with no other component depending on it; dropping it is preferable to
# pulling an EOL OpenSSL into the closure.
#
# autoPatchelfHook (not buildFHSEnv): VST plugins are loaded by a host DAW
# process, so they must work as plain .so files with a correct RPATH. An FHS
# wrapper only helps a program launched directly. See cl/claude-code for the
# opposite case.
#
# autoPatchelfHook only adds RPATH for direct NEEDED dependencies.
# alsa-lib + libjack2 are dlopen'd by the audio runtime at load time, so
# they are appended explicitly (same pattern as vi/vital).

{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  alsa-lib,
  curl,
  freetype,
  libX11,
  libjack2,
  libXtst,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "audiogridder-plugin";
  version = "1.2.0";

  src = fetchurl {
    url = "https://audiogridder.com/releases/AudioGridderPlugin_${finalAttrs.version}-Linux.sh";
    hash = "sha256-qiV/tHt6uEPm7O80hbulbk8m5/LnOJcWuy56ZYFsDd8=";
  };

  # Makeself is a self-extracting shell script, not a tarball - the default
  # unpack does not know what to do with it, so skip it and extract manually.
  dontUnpack = true;

  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [
    alsa-lib
    curl
    freetype
    libX11
    libjack2
    libXtst
    (lib.getLib stdenv.cc.cc) # libstdc++.so.6, libgcc_s.so.1 (C++ runtime)
  ];

  # autoPatchelfHook only adds RPATH for direct NEEDED dependencies.
  # alsa-lib + libjack2 are dlopen'd by the audio runtime at load time, so
  # append them explicitly (same pattern as vi/vital).
  appendRunpaths = lib.makeLibraryPath [
    alsa-lib
    libjack2
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Extract the Makeself payload without running the interactive installer.
    mkdir -p $TMP/extract
    sh $src --noexec --keep --target $TMP/extract

    mkdir -p $out/lib/vst $out/lib/vst3 $out/bin

    # VST2 plugins
    cp $TMP/extract/vst/*.so $out/lib/vst/

    # VST3 bundles - Contents/x86_64-linux/ structure is part of the VST3 spec
    cp -r $TMP/extract/vst3/. $out/lib/vst3/

    # Tray helper (crashpad_handler intentionally excluded: see header comment)
    install -m 755 $TMP/extract/bin/AudioGridderPluginTray $out/bin/

    runHook postInstall
  '';

  meta = {
    description = "AudioGridder VST2/VST3 audio routing plugins for Linux (x86-64)";
    homepage = "https://audiogridder.com";
    # Upstream repo (github.com/apohl79/audiogridder) is MIT-licensed per its
    # GitHub repository metadata. No LICENSE file ships inside the binary
    # archive; the license is attributed from the upstream source repo.
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "AudioGridderPluginTray";
    # crashpad_handler is not installed: it requires libssl.so.1.1/libcrypto.so.1.1
    # (OpenSSL 1.1, end of life). It is a crash reporter and nothing else
    # depends on it, so it was dropped rather than pull an EOL OpenSSL into the
    # closure. See the header comment for details.
  };
})
