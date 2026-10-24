{
  lib,
  writeShellApplication,
  cdrkit,
  coreutils,
  gawk,
  gnused,
  p7zip,
  xorriso,
}:

writeShellApplication {
  name = "win-iso-remaster";

  runtimeInputs = [
    cdrkit
    coreutils
    gawk
    gnused
    p7zip
    xorriso
  ];

  text = builtins.readFile ./win-iso-remaster.sh;

  meta = {
    description = "Remaster a Windows 11 ISO: no 'Press any key' prompt, installs Pro";
    mainProgram = "win-iso-remaster";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
