{
  lib,
  fetchurl,
  appimageTools,
}:
let
  version = "2026.5.17";
  src = fetchurl {
    url = "https://releases.fontba.se/linux/FontBase-${version}.AppImage";
    hash = "sha256-3uC9VSDEN8KjTWVo8S6FrtkhcUMV3zUC3srJ2kQS0E0=";
  };
  appimageContents = appimageTools.extractType2 {
    pname = "fontbase";
    inherit version src;
  };
in
appimageTools.wrapType2 rec {
  pname = "fontbase";
  inherit version src;
  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/fontbase-app.desktop $out/share/applications/${pname}.desktop
    substituteInPlace $out/share/applications/${pname}.desktop --replace-fail 'Exec=AppRun' 'Exec=${meta.mainProgram}'
    install -m 444 -D ${appimageContents}/fontbase-app.png $out/share/icons/hicolor/512x512/apps/${pname}.png
  '';
  meta = {
    mainProgram = "fontbase";
    description = "Font management and productivity tool";
    homepage = "https://fontba.se";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
}
