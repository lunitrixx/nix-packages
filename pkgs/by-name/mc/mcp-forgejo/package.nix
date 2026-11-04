# Not in nixpkgs. Named with the mcp- prefix nixpkgs uses for MCP servers; not
# `forgejo-mcp`, which is an unrelated Go server (b4mad) this overlay must not
# shadow. Upstream: SquareCows/forgejo-mcp, npm @ric_/forgejo-mcp. Built from the
# npm tarball: it ships the compiled dist/ but no lock file, so the runtime-only
# package-lock.json next to this file pins every dependency. postPatch drops
# devDependencies and scripts so package.json matches that lock.
{
  lib,
  buildNpmPackage,
  fetchurl,
  jq,
}:

buildNpmPackage rec {
  pname = "mcp-forgejo";
  version = "0.3.1";

  src = fetchurl {
    url = "https://registry.npmjs.org/@ric_/forgejo-mcp/-/forgejo-mcp-${version}.tgz";
    hash = "sha512-cH+70mJp1tvqTfZHtYgtBuGN4BndUprcgsU+Ht51ownAb5x22rl6QGiEe9OxpsU1NDRxu7Spq5fGGBsitLw21Q==";
  };

  postPatch = ''
    ${lib.getExe jq} 'del(.devDependencies, .scripts)' package.json > package.json.tmp
    mv package.json.tmp package.json
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-YDYVrHFvA1pur0l6jSfSGzFlmFRriPK0OqiIQUlL5Rg=";

  dontNpmBuild = true;

  meta = {
    description = "MCP server for Forgejo (npm @ric_/forgejo-mcp)";
    homepage = "https://code.squarecows.com/SquareCows/forgejo-mcp";
    license = lib.licenses.mit;
    mainProgram = "forgejo-mcp";
    maintainers = [ ];
  };
}
