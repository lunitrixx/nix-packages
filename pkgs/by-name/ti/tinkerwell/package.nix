{
  lib,
  fetchurl,
  appimageTools,
}:
let
  version = "5.17.1";
  src = fetchurl {
    url = "https://download.tinkerwell.app/tinkerwell/Tinkerwell-${version}.AppImage";
    hash = "sha256-BkZkzq2HoXOXw/AKq6uvf3gKxLBu+f1AyCDgEhWvY6s=";
  };
  appimageContents = appimageTools.extractType2 {
    pname = "tinkerwell";
    inherit version src;
  };
in
appimageTools.wrapType2 rec {
  pname = "tinkerwell";
  inherit version src;
  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/tinkerwell.desktop $out/share/applications/${pname}.desktop
    substituteInPlace $out/share/applications/${pname}.desktop --replace-fail 'Exec=AppRun' 'Exec=${meta.mainProgram}'
    cp -r ${appimageContents}/usr/share/icons $out/share/
  '';
  meta = {
    mainProgram = "tinkerwell";
    description = "The magical PHP tinker tool";
    homepage = "https://tinkerwell.app";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
}
